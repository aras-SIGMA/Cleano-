'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const { ok, created, badRequest, unauthorized, conflict } = require('../utils/response');

const BCRYPT_ROUNDS = 10;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^[0-9]{8,20}$/;

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

function str(value) {
  return typeof value === 'string' ? value.trim() : '';
}

// POST /api/auth/register — public
async function register(req, res) {
  const name = str(req.body?.name);
  const email = str(req.body?.email).toLowerCase();
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  const phone = str(req.body?.phone).replace(/[\s-]/g, '');

  if (!name) throw badRequest('Nama wajib diisi.');
  if (name.length > 100) throw badRequest('Nama maksimal 100 karakter.');
  if (!EMAIL_RE.test(email)) throw badRequest('Format email tidak valid.');
  if (email.length > 100) throw badRequest('Email maksimal 100 karakter.');
  if (password.length < 8) throw badRequest('Password minimal 8 karakter.');
  if (!PHONE_RE.test(phone)) throw badRequest('Nomor HP harus 8-20 digit angka.');

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
      await conn.commit();

      const [created_] = await pool.query('select * from users where id = ?', [result.insertId]);
      const user = created_[0];
      return created(res, { token: signToken(user), user: publicUser(user) }, 'Registrasi berhasil.');
    } catch (err) {
      await conn.rollback().catch(() => {});
      if (err.code === 'ER_DUP_ENTRY') {
        const msg = String(err.message || '');
        if (msg.includes('member_code') || msg.includes('uk_users_member')) {
          if (attempt < 2) continue; // member_code bentrok, coba nomor berikutnya
        }
        if (msg.includes('email')) throw conflict('Email sudah terdaftar.');
        if (msg.includes('phone')) throw conflict('Nomor HP sudah terdaftar.');
        throw conflict('Email atau nomor HP sudah terdaftar.');
      }
      throw err;
    } finally {
      conn.release();
    }
  }

  throw conflict('Gagal membuat kode member, coba lagi.');
}

// POST /api/auth/login — public
async function login(req, res) {
  const email = str(req.body?.email).toLowerCase();
  const password = typeof req.body?.password === 'string' ? req.body.password : '';

  if (!email || !password) throw badRequest('Email dan password wajib diisi.');

  const [rows] = await pool.query('select * from users where email = ? limit 1', [email]);
  if (!rows.length) throw unauthorized('Email atau password salah.');

  const user = rows[0];
  const match = await bcrypt.compare(password, user.password);
  if (!match) throw unauthorized('Email atau password salah.');

  return ok(res, { token: signToken(user), user: publicUser(user) }, 'Login berhasil.');
}

module.exports = { register, login, tierOf, publicUser };