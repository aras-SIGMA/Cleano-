'use strict';

const { z } = require('zod');

// Batas panjang mengikuti kolom database_schema.sql v1.4.
const name = z
  .string({ error: 'Nama wajib diisi.' })
  .trim()
  .min(1, 'Nama wajib diisi.')
  .max(100, 'Nama maksimal 100 karakter.');

const email = z
  .string({ error: 'Format email tidak valid.' })
  .trim()
  .toLowerCase()
  .max(100, 'Email maksimal 100 karakter.')
  .regex(/^[^\s@]+@[^\s@]+\.[^\s@]+$/, 'Format email tidak valid.');

// Spasi dan tanda hubung dibuang supaya 0812-3456-7890 == 081234567890.
const phone = z
  .string({ error: 'Nomor HP harus 8-20 digit angka.' })
  .transform((v) => v.trim().replace(/[\s-]/g, ''))
  .refine((v) => /^[0-9]{8,20}$/.test(v), 'Nomor HP harus 8-20 digit angka.');

// bcrypt memotong di 72 byte, jadi batas atas mencegah CPU terbuang sia-sia.
const password = z
  .string({ error: 'Password minimal 8 karakter.' })
  .min(8, 'Password minimal 8 karakter.')
  .max(128, 'Password maksimal 128 karakter.');

const registerBody = z.object({ name, email, password, phone });

// Login hanya membedakan "kosong" vs "ada": aturan panjang password milik
// registrasi. Password salah tetap 401, bukan 400, supaya tidak membocorkan
// kebijakan password lewat endpoint login.
const loginBody = z.object({
  email: z
    .string({ error: 'Email dan password wajib diisi.' })
    .trim()
    .toLowerCase()
    .min(1, 'Email dan password wajib diisi.'),
  password: z
    .string({ error: 'Email dan password wajib diisi.' })
    .min(1, 'Email dan password wajib diisi.'),
});

module.exports = { registerBody, loginBody };