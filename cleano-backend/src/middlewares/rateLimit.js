'use strict';

const rateLimit = require('express-rate-limit');

// Batas percobaan tebak sandi. Tanpa ini, satu skrip bisa mencoba ribuan
// kombinasi terhadap /login dan /register — bcrypt memperlambat setiap tebakan,
// tapi tidak membatasinya.
//
// Dihitung per IP, di memori proses. Cukup untuk satu instance; kalau nanti
// dijalankan lebih dari satu, ganti store ke Redis supaya batasnya tidak
// terbagi per proses.
function limiter(windowMinutes, max, message) {
  return rateLimit({
    windowMs: windowMinutes * 60 * 1000,
    limit: max,
    // express-rate-limit v8 memakai `limit`; `max` masih diterima tapi usang.
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    // Hanya permintaan yang benar-benar sampai ke handler yang dihitung,
    // supaya 400 dari validasi tetap memakan kuota (tebakan tetap tebakan).
    handler: (req, res) => {
      res.status(429).json({ success: false, message });
    },
  });
}

const num = (v, fallback) => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

// Batasnya bisa dinaikkan lewat env karena skrip uji memanggil login/register
// puluhan kali dari IP yang sama. Tanpa jalan keluar itu, suite uji akan
// bertabrakan dengan proteksi yang justru sedang diuji.
//
// 10 percobaan per 15 menit per IP: cukup longgar untuk salah ketik manusia,
// terlalu ketat untuk menebak sandi.
const loginLimiter = limiter(
  15,
  num(process.env.AUTH_LOGIN_LIMIT, 10),
  'Terlalu banyak percobaan masuk. Coba lagi dalam 15 menit.',
);

// Registrasi lebih ketat: 5 akun per jam per IP. Satu orang tidak perlu lebih.
const registerLimiter = limiter(
  60,
  num(process.env.AUTH_REGISTER_LIMIT, 5),
  'Terlalu banyak pendaftaran dari alamat ini. Coba lagi nanti.',
);

module.exports = { loginLimiter, registerLimiter };
