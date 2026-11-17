'use strict';

const { pool } = require('../config/database');
const { ok, created, notFound } = require('../utils/response');
const { parse, parseId } = require('../utils/validate');
const { rewardCreateBody, rewardPutBody } = require('../validators/masterValidator');

const COLS = 'id, title, description, points_required, discount_amount, is_active, created_at';

// GET /api/rewards — semua login
// Pelanggan hanya melihat reward aktif; kasir melihat semuanya untuk kelola.
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

// PUT /api/rewards/:id — kasir
// is_active sengaja tidak ditulis di sini; status aktif diatur lewat toggle.
// Kalau PUT menulis is_active, reward yang sudah dinonaktifkan akan aktif lagi
// hanya karena judulnya diubah.
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

module.exports = { list, create, update, toggle };