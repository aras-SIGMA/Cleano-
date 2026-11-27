'use strict';

const { pool } = require('../config/database');
const { ok, created, notFound } = require('../utils/response');
const { parse, parseId } = require('../utils/validate');
const { rewardCreateBody, rewardPutBody, rewardRedeemBody } = require('../validators/masterValidator');
const { attemptRedeem, fetchMyVouchers } = require('../services/rewardRedeem');
const { runTx } = require('../services/orderStatus');

const COLS = 'id, title, description, points_required, discount_amount, is_active, created_at';

// GET /api/rewards: pelanggan lihat promo aktif, kasir lihat semua.
async function list(req, res) {
  const onlyActive = req.user.role === 'pelanggan';
  const [rows] = await pool.query(
    `select ${COLS} from rewards ${onlyActive ? 'where is_active = 1' : ''} order by points_required asc, id asc`,
  );
  return ok(res, rows, 'Daftar reward.');
}

// POST /api/rewards — kasir
async function create(req, res) {
  const b = parse(rewardCreateBody, req.body);
  const [result] = await pool.query(
    'insert into rewards (title, description, points_required, discount_amount, is_active) values (?, ?, ?, ?, ?)',
    [b.title, b.description, b.points_required, b.discount_amount, b.is_active],
  );
  const [rows] = await pool.query(`select ${COLS} from rewards where id = ?`, [result.insertId]);
  return created(res, rows[0], 'Reward dibuat.');
}

// PUT /api/rewards/:id: status is_active hanya diubah lewat endpoint toggle.
async function update(req, res) {
  const id = parseId(req.params.id);
  const b = parse(rewardPutBody, req.body);
  const [result] = await pool.query(
    'update rewards set title = ?, description = ?, points_required = ?, discount_amount = ? where id = ?',
    [b.title, b.description, b.points_required, b.discount_amount, id],
  );
  if (!result.affectedRows) throw notFound('Reward tidak ditemukan.');
  const [rows] = await pool.query(`select ${COLS} from rewards where id = ?`, [id]);
  return ok(res, rows[0], 'Reward diperbarui.');
}

// PATCH /api/rewards/:id/toggle — kasir
async function toggle(req, res) {
  const id = parseId(req.params.id);
  // Satu pernyataan: baca dan tulis nilai lama tidak bisa disela request lain.
  const [result] = await pool.query(
    'update rewards set is_active = 1 - is_active where id = ?',
    [id],
  );
  if (!result.affectedRows) throw notFound('Reward tidak ditemukan.');
  const [rows] = await pool.query(`select ${COLS} from rewards where id = ?`, [id]);
  return ok(res, rows[0], rows[0].is_active ? 'Reward diaktifkan.' : 'Reward dinonaktifkan.');
}

// POST /api/rewards/redeem — pelanggan
async function redeem(req, res) {
  const b = parse(rewardRedeemBody, req.body);
  // Ambil user_id dari token agar pelanggan tidak memakai poin akun lain.
  const result = await runTx((conn) => attemptRedeem(conn, { userId: req.user.id, rewardId: b.reward_id }));

  return created(res, {
    ...result.voucher,
    points_before: result.pointsBefore,
    points_after: result.pointsAfter,
  }, `Voucher ${result.voucher.voucher_code} berhasil diklaim.`);
}

// GET /api/rewards/my-vouchers: user_id dari token demi privasi voucher pelanggan.
async function myVouchers(req, res) {
  const data = await fetchMyVouchers(pool, req.user.id);
  return ok(res, data, 'Voucher saya.');
}

module.exports = {
  list, create, update, toggle, redeem, myVouchers,
};