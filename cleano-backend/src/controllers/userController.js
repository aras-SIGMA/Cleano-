'use strict';

const { pool } = require('../config/database');
const { ok, badRequest, notFound } = require('../utils/response');
const { normalizePhone } = require('../utils/phone');
const { tierOf, publicUser } = require('./authController');

// GET /api/users/me — semua login
// Token hanya membawa id, member_code, role (PRD-02 §3.1). Poin dan tier tidak
// ikut di dalamnya karena keduanya berubah tanpa login ulang — pelanggan yang
// baru menyelesaikan order akan melihat saldo lama sampai token kedaluwarsa.
// Portal pelanggan (PRD-04 §3.1, §3.3) butuh angka terbaru, jadi dibaca di sini.
async function me(req, res) {
  const [rows] = await pool.query(
    'select id, name, email, phone, role, member_code, points from users where id = ? limit 1',
    [req.user.id],
  );
  if (!rows.length) throw notFound('Pengguna tidak ditemukan.');

  return ok(res, publicUser(rows[0]), 'Profil pengguna.');
}

// GET /api/users/lookup?query=MBR-0001 | 081234567890 — kasir saja
// Dipakai layar POS untuk mencari pelanggan lewat QR member atau nomor HP (TC-11).
async function lookup(req, res) {
  const query = typeof req.query.query === 'string' ? req.query.query.trim() : '';
  if (!query) throw badRequest('Parameter query wajib diisi.');
  // Kode member 8 karakter, nomor HP maksimal 20 digit. Batas ini mencegah
  // query string sepanjang megabyte ikut dinormalisasi dan dikirim ke MySQL.
  if (query.length > 30) throw badRequest('Kata kunci pencarian maksimal 30 karakter.');

  // Kasir mengetik nomor dari WhatsApp (+62...) atau dari kartu (0812...).
  // Keduanya harus menemukan orang yang sama; tanpa normalisasi, +62812… → 404.
  const phone = normalizePhone(query);

  const [rows] = await pool.query(
    `select id, name, phone, member_code, points
       from users
      where role = 'pelanggan'
        and (member_code = ? or phone = ?)
      limit 1`,
    [query.toUpperCase(), phone],
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

module.exports = { me, lookup };