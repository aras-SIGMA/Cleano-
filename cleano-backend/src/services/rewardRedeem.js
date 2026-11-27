'use strict';

const crypto = require('crypto');
const { notFound } = require('../utils/response');

const MAX_ATTEMPTS = 3;

// Buat 4 karakter acak tanpa huruf mirip untuk kode voucher.
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

function newVoucherCode() {
  let out = '';
  for (let i = 0; i < 4; i += 1) {
    out += ALPHABET[crypto.randomInt(ALPHABET.length)];
  }
  return `CLN-VCR-${out}`;
}

// Klaim voucher dalam transaksi; validasi aktif dan potong poin oleh trigger.
async function attemptRedeem(conn, { userId, rewardId, generateCode = newVoucherCode }) {
  // Baca saldo awal untuk laporan; kunci baris diambil otomatis oleh trigger.
  const [[user]] = await conn.query('select points from users where id = ?', [userId]);
  if (!user) throw notFound('Pelanggan tidak ditemukan.');

  // Pastikan reward ada agar ID asing membalas 404 sebelum trigger berjalan.
  const [[reward]] = await conn.query('select title from rewards where id = ?', [rewardId]);
  if (!reward) throw notFound('Katalog reward tidak ditemukan.');

  // Ulangi klaim bila voucher_code acak bentrok; transaksi MySQL tetap aman.
  for (let attempt = 1; ; attempt += 1) {
    const voucherCode = generateCode();
    try {
      const [ins] = await conn.query(
        'insert into user_vouchers (voucher_code, user_id, reward_id, is_used) values (?, ?, ?, 0)',
        [voucherCode, userId, rewardId],
      );
      const [[row]] = await conn.query(
        `select uv.id, uv.voucher_code, uv.user_id, uv.reward_id, uv.is_used, uv.used_at,
                uv.created_at, r.title, r.description, r.discount_amount, r.points_required
           from user_vouchers uv
           join rewards r on uv.reward_id = r.id
          where uv.id = ?`,
        [ins.insertId],
      );
      // Baca ulang saldo poin setelah trigger memotongnya agar selalu akurat.
      const [[after]] = await conn.query('select points from users where id = ?', [userId]);
      return {
        voucher: row,
        pointsBefore: Number(user.points),
        pointsAfter: Number(after.points),
        rewardTitle: reward.title,
      };
    } catch (err) {
      if (err.code !== 'ER_DUP_ENTRY' || attempt >= MAX_ATTEMPTS) throw err;
    }
  }
}

// Ambil daftar voucher aktif dan riwayat terpakai milik satu pelanggan.
async function fetchMyVouchers(db, userId) {
  const [rows] = await db.query(
    `select uv.id, uv.voucher_code, uv.reward_id, uv.is_used, uv.used_at, uv.created_at,
            r.title, r.description, r.discount_amount, r.points_required
       from user_vouchers uv
       join rewards r on uv.reward_id = r.id
      where uv.user_id = ?
      order by uv.is_used asc, uv.created_at desc, uv.id desc`,
    [userId],
  );

  return {
    active: rows.filter((v) => v.is_used === 0),
    history: rows.filter((v) => v.is_used === 1),
    total: rows.length,
  };
}

module.exports = { attemptRedeem, newVoucherCode, fetchMyVouchers };
