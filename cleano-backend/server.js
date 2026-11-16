'use strict';

require('dotenv').config({ quiet: true });

const path = require('path');
const express = require('express');
const cors = require('cors');

const { pool, ping } = require('./src/config/database');

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

const server = app.listen(PORT, () => {
  console.log(`Cleano API listening on http://localhost:${PORT}`);
});

function shutdown(signal) {
  console.log(`${signal} diterima, menutup server...`);
  server.close(async () => {
    await pool.end().catch(() => {});
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

module.exports = app;