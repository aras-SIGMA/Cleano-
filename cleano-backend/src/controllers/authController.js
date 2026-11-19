'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const { ok, created, unauthorized, conflict } = require('../utils/response');
const { parse } = require('../utils/validate');
const { registerBody, loginBody } = require('../validators/authValidator');

const BCRYPT_ROUNDS = 10;
const USER_COLS = 'id, name, email, phone, role, member_code, points';

// Tier diturunkan dari poin, sama dengan logika trigger & view (v1.4).
function tierOf(points) {
  if (points >= 300) return 'Platinum';
  if (points >= 100) return 'Gold';
  return 'Silver';
}

function publicUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone,
    role: row.role,
    member_code: row.member_code,
    points: row.points,
    tier: tierOf(row.points),
  };
}

function signToken(row) {
  return jwt.sign(
    { id: row.id, member_code: row.member_code, role: row.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '24h' },
  );
}

// POST /api/auth/register — public
async function register(req, res) {
  const { name, email, password, phone } = parse(registerBody, req.body);

  const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  // member_code berurutan: ambil nomor tertinggi lalu +1. Balapan antar request
  // diselesaikan unique constraint; ulangi maksimal 3 kali.
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [rows] = await conn.query(
        "select member_code from users where member_code like 'MBR-%' order by member_code desc limit 1",
      );
      const next = rows.length ? Number(rows[0].member_code.slice(4)) + 1 : 1;
      const memberCode = `MBR-${String(next).padStart(4, '0')}`;

      const [result] = await conn.query(
        "insert into users (name, email, password, role, phone, member_code, points) values (?, ?, ?, 'pelanggan', ?, ?, 0)",
        [name, email, hash, phone, memberCode],
      );
      // baris dibaca di dalam transaksi: setelah commit koneksi bisa dipakai
      // request lain, dan kegagalan baca tidak boleh membuat user "hilang".
      const [fresh] = await conn.query(`select ${USER_COLS} from users where id = ?`, [result.insertId]);
      const user = fresh[0];
      // token dibuat sebelum commit: setelah commit tidak ada lagi yang boleh
      // gagal sampai respons terkirim (kalau gagal, user tercipta tapi klien 500).
      const body = { token: signToken(user), user: publicUser(user) };
      await conn.commit();
      return created(res, body, 'Registrasi berhasil.');
    } catch (err) {
      await conn.rollback().catch(() => {});
      if (err.code === 'ER_DUP_ENTRY') {
        // Kolom yang bentrok dibaca dari tabel, bukan ditebak dari err.message.
        // Pesan driver berbentuk "Duplicate entry '<nilai>' for key 'users.email'"
        // — memuat *nilai* yang didaftarkan, bukan hanya nama kolom. Jadi alamat
        // seperti member_code@gmail.com membuat `msg.includes('member_code')`
        // bernilai benar, dan pendaftaran yang jelas bentrok email dijawab
        // "Gagal membuat kode member, coba lagi." sambil mengulang tiga kali.
        // Bentuk pesan juga bergantung versi driver, jadi tebakan teks akan
        // retak lagi di pembaruan berikutnya.
        const [dup] = await conn.query(
          'select email from users where email = ? or phone = ?',
          [email, phone],
        );
        // `some`, bukan baris pertama: kalau email dan phone masing-masing
        // dipakai dua user berbeda, urutan baris tidak dijamin.
        if (dup.length) {
          const emailTaken = dup.some((r) => r.email.toLowerCase() === email);
          throw conflict(emailTaken
            ? 'Email sudah terdaftar.'
            : 'Nomor HP sudah terdaftar.');
        }
        // Bukan email/phone berarti member_code: satu-satunya kolom unik lain.
        if (attempt < 2) continue;
        throw conflict('Gagal membuat kode member, coba lagi.');
      }
      throw err;
    } finally {
      conn.release();
    }
  }
}

// POST /api/auth/login — public
async function login(req, res) {
  const { email, password } = parse(loginBody, req.body);

  const [rows] = await pool.query(`select ${USER_COLS}, password from users where email = ? limit 1`, [email]);
  if (!rows.length) throw unauthorized('Email atau password salah.');

  const user = rows[0];
  const match = await bcrypt.compare(password, user.password);
  if (!match) throw unauthorized('Email atau password salah.');

  return ok(res, { token: signToken(user), user: publicUser(user) }, 'Login berhasil.');
}

module.exports = { register, login, tierOf, publicUser };