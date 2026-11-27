'use strict';

const fs = require('fs');
const { pool } = require('../config/database');
const { ok, badRequest, notFound } = require('../utils/response');
const { normalizePhone } = require('../utils/phone');
const { tierOf, publicUser } = require('./authController');
const { verifyImageMagicBytes } = require('../middlewares/uploadMiddleware');
const cloudinary = require('../config/cloudinary');

const AVATAR_FOLDER = process.env.CLOUDINARY_AVATAR_FOLDER || 'cleano/avatars';

// GET /api/users/me: ambil poin dan tier terbaru langsung dari database.
async function me(req, res) {
  const [rows] = await pool.query(
    'select id, name, email, phone, role, member_code, points, avatar_url from users where id = ? limit 1',
    [req.user.id],
  );
  if (!rows.length) throw notFound('Pengguna tidak ditemukan.');

  return ok(res, publicUser(rows[0]), 'Profil pengguna.');
}

// PATCH /api/users/me/avatar — semua login (kasir & pelanggan)
async function updateAvatar(req, res) {
  let uploaded = null;
  let validFile = false;
  try {
    if (!req.file) {
      throw badRequest('Foto profil wajib diunggah pada field "image".');
    }
    if (!verifyImageMagicBytes(req.file.path)) {
      throw badRequest('Format foto harus JPG, PNG, atau WEBP yang valid.');
    }
    validFile = true;

    uploaded = cloudinary.enabled
      ? await cloudinary.uploadImage(req.file.path, { folder: AVATAR_FOLDER, maxDim: 512 })
      : { url: `/uploads/${req.file.filename}`, publicId: null };

    const [result] = await pool.query(
      'update users set avatar_url = ? where id = ?',
      [uploaded.url, req.user.id],
    );
    if (!result.affectedRows) throw notFound('Pengguna tidak ditemukan.');

    const [rows] = await pool.query(
      'select id, name, email, phone, role, member_code, points, avatar_url from users where id = ? limit 1',
      [req.user.id],
    );
    return ok(res, publicUser(rows[0]), 'Foto profil diperbarui.');
  } catch (err) {
    if (uploaded?.publicId) await cloudinary.destroyImage(uploaded.publicId);
    if (req.file && (!cloudinary.enabled || !validFile)) fs.unlink(req.file.path, () => {});
    throw err;
  } finally {
    if (cloudinary.enabled && req.file) fs.unlink(req.file.path, () => {});
  }
}

// GET /api/users/lookup: cari pelanggan via kode member atau nomor HP.
async function lookup(req, res) {
  const query = typeof req.query.query === 'string' ? req.query.query.trim() : '';
  if (!query) throw badRequest('Parameter query wajib diisi.');
  // Batasi panjang query lookup untuk mencegah normalisasi string raksasa.
  if (query.length > 30) throw badRequest('Kata kunci pencarian maksimal 30 karakter.');

  // Normalisasi nomor HP (+62/62/08) agar pencarian kasir selalu cocok.
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

module.exports = { me, updateAvatar, lookup };