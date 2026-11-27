'use strict';

require('dotenv').config({ quiet: true });

const path = require('path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const { createLogger, describe } = require('./src/utils/logger');
const { pool, ping } = require('./src/config/database');
const { apiLimiter } = require('./src/middlewares/rateLimit');

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

// Konfigurasi jumlah hop proxy agar rate limit memisahkan IP asli klien.
app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS) || 0);

// Header keamanan Helmet: nonaktifkan CSP JSON dan izinkan akses lintas-origin.
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

// Izinkan request tanpa Origin untuk mobile; batasi origin browser di produksi.
const origins = (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
const isProd = process.env.NODE_ENV === 'production';
app.use(cors(
  origins.length
    ? {
        origin: (origin, cb) => {
          if (!origin || origins.includes(origin)) return cb(null, true);
          return cb(null, false);
        },
      }
    : isProd
      ? { origin: false }
      : {},
));

// Batasi ukuran body JSON (default 1 MB) untuk mencegah banjir memori.
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '1mb' }));

// foto bukti drop-off disajikan statis (PRD-02 §5 non-goals)
app.use('/uploads', express.static(path.resolve(__dirname, process.env.UPLOAD_DIR || 'uploads'), {
  setHeaders: (res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
  },
}));

app.get('/api/health', async (req, res) => {
  const db = await ping().then(() => 'ok').catch((err) => `down: ${err.code || err.message}`);
  res.status(db === 'ok' ? 200 : 503).json({
    success: db === 'ok',
    message: db === 'ok' ? 'Cleano API sehat.' : 'Database tidak dapat dihubungi.',
    data: { uptime_seconds: Math.round(process.uptime()), db },
  });
});

app.use('/api', apiLimiter);
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
  // SQLSTATE '45000' dari trigger dipetakan ke HTTP 400 dengan pesan bisnis.
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
    return res.status(status).json({ success: false, message: 'Terjadi kesalahan pada server.' });
  }
  if (fromTrigger) {
    // Catat penolakan aturan bisnis sebagai info tanpa memenuhi log error.
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

// Bind port dan pasang handler shutdown hanya saat dijalankan langsung.
if (require.main === module) {
  const secret = process.env.JWT_SECRET || '';
  if (isProd && secret.length < 32) {
    log.error('JWT_SECRET harus minimal 32 karakter di produksi');
    process.exit(1);
  }
  if (!isProd && secret.length < 32) {
    log.warn('JWT_SECRET kurang dari 32 karakter; gunakan secret kuat untuk produksi');
  }
  server = app.listen(PORT, () => {
    log.info('cleano api siap', { port: PORT });
  });
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

module.exports = app;