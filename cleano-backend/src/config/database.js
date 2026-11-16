'use strict';

const path = require('path');
const fs = require('fs');
const mysql = require('mysql2/promise');

// Aiven wajib SSL. CA bisa dikirim sebagai path file atau isi PEM langsung.
function buildSsl() {
  if (process.env.DB_SSL !== 'true') return undefined;

  const caSetting = process.env.DB_SSL_CA || '';
  if (caSetting.trim().startsWith('-----BEGIN')) {
    return { ca: caSetting, rejectUnauthorized: true };
  }

  const caPath = path.resolve(__dirname, '..', '..', caSetting);
  if (caSetting && fs.existsSync(caPath)) {
    return { ca: fs.readFileSync(caPath, 'utf8'), rejectUnauthorized: true };
  }

  // tanpa CA: tetap terenkripsi, tapi sertifikat tidak diverifikasi
  console.warn('[db] DB_SSL_CA tidak ditemukan, koneksi TLS tanpa verifikasi sertifikat.');
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

// Aiven berjalan UTC. Opsi `timezone` mysql2 di atas TIDAK mengubah
// @@session.time_zone di server, sehingga now()/curdate()/DATE(paid_at) tetap UTC
// dan transaksi setelah 17:00 WIB tercatat di tanggal berikutnya.
// Solusinya men-set timezone sesi pada setiap koneksi baru.
const TZ_OFFSET = process.env.DB_TIMEZONE || '+07:00';
pool.on('connection', (conn) => {
  conn.query(`set time_zone = '${TZ_OFFSET}'`, (err) => {
    if (err) console.error(`[db] gagal set time_zone ${TZ_OFFSET}: ${err.code || err.message}`);
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