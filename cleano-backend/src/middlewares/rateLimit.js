'use strict';

const rateLimit = require('express-rate-limit');

// Batasi percobaan login/register per IP di memori proses.
function limiter(windowMinutes, max, pesan) {
  // Sertakan durasi tunggu di pesan error sesuai parameter rate limit.
  const message = typeof pesan === 'function' ? pesan(windowMinutes) : pesan;
  return rateLimit({
    windowMs: windowMinutes * 60 * 1000,
    limit: max,
    // express-rate-limit v8 memakai `limit`; `max` masih diterima tapi usang.
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    // Hitung juga request gagal validasi ke kuota rate limit.
    handler: (req, res) => {
      res.status(429).json({ success: false, message });
    },
  });
}

const num = (v, fallback) => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

// Izinkan override batas lewat env untuk kebutuhan suite uji otomatis.
const loginLimiter = limiter(
  15,
  num(process.env.AUTH_LOGIN_LIMIT, 10),
  (m) => `Terlalu banyak percobaan masuk. Coba lagi dalam ${m} menit.`,
);

// Registrasi dibatasi lebih ketat: maksimal 5 akun per jam per IP.
const registerLimiter = limiter(
  60,
  num(process.env.AUTH_REGISTER_LIMIT, 5),
  (m) => `Terlalu banyak pendaftaran dari alamat ini. Coba lagi dalam ${m} menit.`,
);

// Batas lookup pelanggan untuk mencegah enumerasi nomor HP / member code.
const lookupLimiter = limiter(
  1,
  num(process.env.LOOKUP_LIMIT, 60),
  () => 'Terlalu banyak pencarian pelanggan. Coba lagi dalam 1 menit.',
);

// Batas umum API per IP untuk mencegah penyalahgunaan/DoS ringan.
const apiLimiter = limiter(
  15,
  num(process.env.API_LIMIT, 300),
  (m) => `Terlalu banyak permintaan ke server. Coba lagi dalam ${m} menit.`,
);

module.exports = { loginLimiter, registerLimiter, lookupLimiter, apiLimiter };
