'use strict';

const path = require('path');
const fs = require('fs');
const mysql = require('mysql2/promise');
const { createLogger } = require('../utils/logger');

const log = createLogger('db');

// Koneksi Aiven wajib SSL; tolak mode longgar saat DB_SSL_VERIFY=true.
function buildSsl() {
  if (process.env.DB_SSL !== 'true') return undefined;

  const caSetting = process.env.DB_SSL_CA || '';
  const wajibVerifikasi = process.env.DB_SSL_VERIFY === 'true'
    || (process.env.NODE_ENV === 'production' && process.env.DB_SSL_VERIFY !== 'false');

  let caContent = '';
  if (caSetting.trim().startsWith('-----BEGIN')) {
    caContent = caSetting.trim();
  } else if (caSetting) {
    const caPath = path.resolve(__dirname, '..', '..', caSetting);
    if (fs.existsSync(caPath)) {
      caContent = fs.readFileSync(caPath, 'utf8').trim();
    }
  }

  if (caContent) {
    // Normalisasi: jika isi hanya base64 tanpa header PEM, bungkus otomatis
    if (!caContent.includes('-----BEGIN CERTIFICATE-----')) {
      caContent = `-----BEGIN CERTIFICATE-----\n${caContent}\n-----END CERTIFICATE-----\n`;
    }
    return { ca: caContent, rejectUnauthorized: true };
  }

  if (wajibVerifikasi) {
    throw new Error(
      `DB_SSL_VERIFY=true tetapi CA tidak ditemukan di "${caSetting || '(DB_SSL_CA kosong)'}". `
      + 'Unduh ca.pem dari dashboard Aiven (service > Overview > CA Certificate) '
      + 'lalu simpan sebagai cleano-backend/certs/ca.pem.',
    );
  }

  log.warn('DB_SSL_CA tidak ditemukan, koneksi TLS tanpa verifikasi sertifikat', {
    hint: 'set DB_SSL_VERIFY=true untuk menolak mode ini di produksi',
  });
  return { rejectUnauthorized: false };
}

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'cleano_db',
  waitForConnections: true,
  connectionLimit: Number(process.env.DB_CONNECTION_LIMIT) || 10,
  queueLimit: 0,
  // driver hanya memakai ini untuk parsing tanggal; not needed since dateStrings diaktifkan
  timezone: '+07:00',
  dateStrings: ['DATE', 'DATETIME'],
  ssl: buildSsl(),
});

// Setel timezone sesi +07:00 tiap koneksi baru agar curdate() sesuai WIB.
const RAW_TZ = (process.env.DB_TIMEZONE || '+07:00').trim();
const TZ_OFFSET = /^[+-](?:0\d|1[0-4]):[0-5]\d$/.test(RAW_TZ) ? RAW_TZ : '+07:00';
pool.on('connection', (conn) => {
  conn.query('set time_zone = ?', [TZ_OFFSET], (err) => {
    if (err) log.error('gagal set time_zone', { offset: TZ_OFFSET, code: err.code, message: err.message });
  });
});

async function ping() {
  const conn = await pool.getConnection();
  try {
    await conn.ping();
    return true;
  } finally {
    conn.release();
  }
}

module.exports = { pool, ping };