'use strict';

const crypto = require('crypto');
const { notFound } = require('../utils/response');

const MAX_ATTEMPTS = 3;

// 4 karakter alfanumerik, sesuai format PRD-02 §4.4 (CLN-VCR-XXXX).
// Tanpa karakter mirip (0/O, 1/I/L) karena kode ini dibaca dan diketik manual
// dari kartu voucher pelanggan.
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

function newVoucherCode() {
  let out = '';
  for (let i = 0; i < 4; i += 1) {
    out += ALPHABET[crypto.randomInt(ALPHABET.length)];
  }
  return `CLN-VCR-${out}`;
}

// Klaim voucher, di atas koneksi yang sudah membuka transaksi (pola B4/B6/B7)
// supaya skrip uji bisa ROLLBACK — poin yang sudah terpotong tidak bisa
// dikembalikan sendiri, dan trigger L-02 melarang voucher diaktifkan ulang.
//
// Poin TIDAK diperiksa dan TIDAK dipotong di sini. trg_before_insert_user_voucher
// yang memutuskan: ia membaca is_active dan saldo poin, menolak dengan SQLSTATE
// 45000, lalu memotong poinnya. Memeriksa ulang di backend berarti dua tempat
// memutuskan hal yang sama, dan yang kedua bisa berbeda pendapat dengan trigger.
async function attemptRedeem(conn, { userId, rewardId, generateCode = newVoucherCode }) {
  // Saldo dibaca hanya untuk melaporkan points_before. Tidak perlu FOR UPDATE:
  // INSERT di bawah menjalankan trg_before_insert_user_voucher, yang melakukan
  // `update users set points = points - ...` — UPDATE itu sendiri mengambil kunci
  // baris user, jadi klaim kedua menunggu sampai transaksi pertama selesai.
  // Kunci eksplisit di sini hanya menambah satu pernyataan tanpa menambah jaminan.
  const [[user]] = await conn.query('select points from users where id = ?', [userId]);
  if (!user) throw notFound('Pelanggan tidak ditemukan.');

  // Hanya memastikan reward-nya ada, supaya reward_id asing dijawab 404 dan bukan
  // 400 dari SIGNAL. Status aktif dan kecukupan poin tetap diputuskan trigger.
  const [[reward]] = await conn.query('select title from rewards where id = ?', [rewardId]);
  if (!reward) throw notFound('Katalog reward tidak ditemukan.');

  // Kode bentrok diulang. ER_DUP_ENTRY di sini hanya mungkin berasal dari
  // voucher_code: satu-satunya unique key lain di tabel ini adalah primary key
  // yang dibuat otomatis. INSERT yang gagal tidak membatalkan transaksi MySQL,
  // jadi percobaan berikutnya tetap berjalan di transaksi yang sama.
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
      // Saldo setelah trigger memotong — dibaca, bukan dihitung sendiri, supaya
      // angka yang dilaporkan selalu sama dengan isi tabel.
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

// Daftar voucher milik satu pelanggan. Diterima `db` (pool atau conn) supaya
// skrip uji bisa menjalankannya di dalam transaksi yang punya voucher terpakai
// buatan — seeder tidak punya satu pun, dan voucher terpakai tidak bisa
// dikembalikan ke is_used = 0 (trigger L-02).
//
// Aktif dan riwayat dipisah di sini, sesuai PRD-04 §3.3 yang menampilkan dua
// sub-bagian berbeda, supaya klien tidak perlu memfilter sendiri.
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
