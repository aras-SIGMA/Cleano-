'use strict';

const { pool } = require('../config/database');
const { ok, badRequest, notFound } = require('../utils/response');
const { tierOf } = require('./authController');

// GET /api/users/lookup?query=MBR-0001 | 081234567890 — kasir saja
// Dipakai layar POS untuk mencari pelanggan lewat QR member atau nomor HP (TC-11).
async function lookup(req, res) {
  const query = typeof req.query.query === 'string' ? req.query.query.trim() : '';
  if (!query) throw badRequest('Parameter query wajib diisi.');

  const digits = query.replace(/[\s-]/g, '');

  const [rows] = await pool.query(
    `select id, name, phone, member_code, points
       from users
      where role = 'pelanggan'
        and (member_code = ? or phone = ?)
      limit 1`,
    [query.toUpperCase(), digits],
  );

  if (!rows.length) throw notFound('Pelanggan tidak ditemukan.');

  const user = rows[0];

  // voucher aktif saja; riwayat terpakai ada di /api/rewards/my-vouchers
  const [vouchers] = await pool.query(
    `select uv.id, uv.voucher_code, uv.created_at,
            r.id as reward_id, r.title, r.discount_amount
       from user_vouchers uv
       join rewards r on r.id = uv.reward_id
      where uv.user_id = ? and uv.is_used = 0
      order by uv.created_at asc, uv.id asc`,
    [user.id],
  );

  return ok(res, {
    ...user,
    tier: tierOf(user.points),
    vouchers,
  }, 'Pelanggan ditemukan.');
}

module.exports = { lookup };