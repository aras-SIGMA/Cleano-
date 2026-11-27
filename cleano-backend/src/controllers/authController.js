'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const { ok, created, unauthorized, conflict } = require('../utils/response');
const { parse } = require('../utils/validate');
const { registerBody, loginBody, changePasswordBody } = require('../validators/authValidator');

const BCRYPT_ROUNDS = 12;
const USER_COLS = 'id, name, email, phone, role, member_code, points, avatar_url';

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
    avatar_url: row.avatar_url ?? null,
    tier: tierOf(row.points),
  };
}

/** Ambil profil publik pengguna berdasarkan id dari pool atau transaksi. */
async function findUserById(db, id) {
  const [rows] = await db.query(`select ${USER_COLS} from users where id = ? limit 1`, [id]);
  return rows.length ? publicUser(rows[0]) : null;
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

  // Buat member_code berurutan dari nilai maksimum, ulangi maksimal 3 kali.
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
      // Baca user di dalam transaksi sebelum commit agar koneksi tetap konsisten.
      const user = await findUserById(conn, result.insertId);
      // Buat token sebelum commit agar tidak ada kegagalan setelah user tersimpan.
      const body = { token: signToken(user), user };
      await conn.commit();
      return created(res, body, 'Registrasi berhasil.');
    } catch (err) {
      await conn.rollback().catch(() => {});
      if (err.code === 'ER_DUP_ENTRY') {
        // Deteksi kolom duplikat langsung dari tabel, bukan menebak teks err.message.
        const [dup] = await conn.query(
          'select email from users where email = ? or phone = ?',
          [email, phone],
        );
        // Pakai some() agar bentrok email dan phone tetap terdeteksi tepat.
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

// PATCH /api/auth/change-password — semua login
async function changePassword(req, res) {
  const { old_password: oldPassword, new_password: newPassword } = parse(changePasswordBody, req.body);

  const [rows] = await pool.query('select password from users where id = ? limit 1', [req.user.id]);
  if (!rows.length) throw unauthorized('Pengguna tidak ditemukan.');

  const match = await bcrypt.compare(oldPassword, rows[0].password);
  if (!match) throw unauthorized('Kata sandi saat ini salah.');

  const hash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
  await pool.query('update users set password = ? where id = ?', [hash, req.user.id]);

  return ok(res, null, 'Kata sandi berhasil diperbarui.');
}

module.exports = { register, login, changePassword, tierOf, publicUser, findUserById };