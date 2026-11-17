'use strict';

require('dotenv').config({ quiet: true });

const path = require('path');
const express = require('express');
const cors = require('cors');

const { pool, ping } = require('./src/config/database');
const authRoutes = require('./src/routes/authRoutes');
const userRoutes = require('./src/routes/userRoutes');
const serviceRoutes = require('./src/routes/serviceRoutes');
const machineRoutes = require('./src/routes/machineRoutes');
const rewardRoutes = require('./src/routes/rewardRoutes');
const orderRoutes = require('./src/routes/orderRoutes');

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json());

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

app.use((req, res) => {
  res.status(404).json({ success: false, message: `Rute ${req.method} ${req.originalUrl} tidak ditemukan.` });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  const status = err.status || (err.code === 'LIMIT_FILE_SIZE' ? 400 : 500);
  const message = err.code === 'LIMIT_FILE_SIZE'
    ? `Ukuran foto melebihi ${process.env.MAX_IMAGE_MB || 2} MB.`
    : err.message || 'Terjadi kesalahan pada server.';
  if (status >= 500) console.error(err);
  res.status(status).json({ success: false, message });
});

let server = null;

function shutdown(signal) {
  console.log(`${signal} diterima, menutup server...`);
  if (!server) process.exit(0);
  server.close(async () => {
    await pool.end().catch(() => {});
    process.exit(0);
  });
}

// hanya bind port & pasang handler shutdown kalau dijalankan langsung (bukan dipakai tes)
if (require.main === module) {
  server = app.listen(PORT, () => {
    console.log(`Cleano API listening on http://localhost:${PORT}`);
  });
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

module.exports = app;