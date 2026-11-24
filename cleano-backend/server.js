'use strict';

require('dotenv').config({ quiet: true });

const path = require('path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const { createLogger, describe } = require('./src/utils/logger');
const { pool, ping } = require('./src/config/database');

const log = createLogger('server');
const authRoutes = require('./src/routes/authRoutes');
const userRoutes = require('./src/routes/userRoutes');
const serviceRoutes = require('./src/routes/serviceRoutes');
const machineRoutes = require('./src/routes/machineRoutes');
const rewardRoutes = require('./src/routes/rewardRoutes');
const orderRoutes = require('./src/routes/orderRoutes');
const dashboardRoutes = require('./src/routes/dashboardRoutes');

const app = express();
const PORT = Number(process.env.PORT) || 3000;

// Di belakang reverse proxy (Railway, Render, nginx, Cloudflare), IP asli ada di
// X-Forwarded-For dan req.ip berisi IP proxy. Tanpa ini SEMUA pengguna berbagi
// satu ember rate limit: setelah 10 percobaan login dari siapa pun, seluruh
// pengguna terkunci 15 menit.
//
// Nilainya jumlah hop proxy yang boleh dipercaya, bukan `true`. `true` berarti
// mempercayai X-Forwarded-For apa adanya, sehingga klien bisa memalsukan IP dan
// melewati batas. Bawaan 0 = tidak ada proxy (pengembangan langsung).
app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS) || 0);

// Header keamanan. CSP dimatikan karena API ini tidak menyajikan HTML —
// halaman yang dilindungi CSP adalah aplikasi Flutter/web, bukan respons JSON.
// crossOriginResourcePolicy dibuat cross-origin agar Flutter Web (Chrome) bisa mengakses API.
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

// Flutter mobile tidak mengirim Origin, jadi `cors()` terbuka aman untuk API
// yang dijaga token. Batas origin dari env dipakai saat web dilayani terpisah.
const origins = (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
app.use(cors(origins.length ? { origin: origins } : {}));

// Batas ukuran body. Tanpa ini satu permintaan 100 MB menghabiskan memori
// proses sebelum validasi sempat menolaknya. 1 MB jauh di atas body terbesar
// yang sah (order + voucher_code), dan upload foto punya jalur multipart sendiri.
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '1mb' }));

// foto bukti drop-off disajikan statis (PRD-02 §5 non-goals)
app.use('/uploads', express.static(path.resolve(__dirname, process.env.UPLOAD_DIR || 'uploads')));

app.get('/api/health', async (req, res) => {
  const db = await ping().then(() => 'ok').catch((err) => `down: ${err.code || err.message}`);
  res.status(db === 'ok' ? 200 : 503).json({
    success: db === 'ok',
    message: db === 'ok' ? 'Cleano API sehat.' : 'Database tidak dapat dihubungi.',
    data: { uptime_seconds: Math.round(process.uptime()), db },
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/services', serviceRoutes);
app.use('/api/machines', machineRoutes);
app.use('/api/rewards', rewardRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/dashboard', dashboardRoutes);

app.use((req, res) => {
  res.status(404).json({ success: false, message: `Rute ${req.method} ${req.originalUrl} tidak ditemukan.` });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // SIGNAL SQLSTATE '45000' dari trigger = penolakan aturan bisnis, bukan
  // kerusakan server. Tanpa ini pelanggan melihat 500 untuk hal yang sebenarnya
  // salah input (poin kurang, promo nonaktif). err.sqlMessage adalah pesan yang
  // ditulis trigger, jadi sudah berbahasa Indonesia dan layak ditampilkan.
  const fromTrigger = err.sqlState === '45000' || err.errno === 1644
    || err.code === 'ER_SIGNAL_EXCEPTION';

  const status = err.status
    || (fromTrigger ? 400 : null)
    || (err.code === 'LIMIT_FILE_SIZE' ? 400 : null)
    || (err.code === 'LIMIT_FIELD_VALUE' ? 400 : 500);
  const tooLarge = err.type === 'entity.too.large';

  const message = err.code === 'LIMIT_FILE_SIZE'
    ? `Ukuran foto melebihi ${process.env.MAX_IMAGE_MB || 2} MB.`
    : err.code === 'LIMIT_FIELD_VALUE'
      ? 'Isi kolom teks terlalu panjang.'
      : tooLarge
      ? `Ukuran body permintaan melebihi ${process.env.JSON_BODY_LIMIT || '1mb'}.`
      : (fromTrigger ? err.sqlMessage || err.message : err.message) || 'Terjadi kesalahan pada server.';

  if (status >= 500) {
    log.error('permintaan gagal', { ...describe(err), method: req.method, path: req.originalUrl });
  } else if (fromTrigger) {
    // Penolakan aturan bisnis: berguna untuk melihat pelanggan mana yang
    // kehabisan poin, tanpa membanjiri log error.
    log.warn('aturan bisnis menolak', {
      method: req.method, path: req.originalUrl, message, userId: req.user?.id,
    });
  }

  res.status(status).json({ success: false, message });
});

let server = null;

function shutdown(signal) {
  log.info('menutup server', { signal });
  if (!server) process.exit(0);
  server.close(async () => {
    await pool.end().catch(() => {});
    process.exit(0);
  });
}

// hanya bind port & pasang handler shutdown kalau dijalankan langsung (bukan dipakai tes)
if (require.main === module) {
  server = app.listen(PORT, () => {
    log.info('cleano api siap', { port: PORT });
  });
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

module.exports = app;