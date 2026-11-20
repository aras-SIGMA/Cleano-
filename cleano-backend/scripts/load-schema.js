// muat database_schema.sql ke Aiven lewat koneksi TLS yang sama dengan aplikasi.
// file schema memakai direktif CLI "delimiter $$" yang tidak dipahami driver,
// jadi statement dipecah manual di sini.
require('dotenv').config({ quiet: true });
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

// pecah file menjadi statement, menghormati perubahan delimiter ($$ untuk trigger)
function splitStatements(sql) {
  const out = [];
  let delimiter = ';';
  let buffer = '';

  for (const rawLine of sql.split(/\r?\n/)) {
    const line = rawLine.trim();
    const delimMatch = line.match(/^delimiter\s+(\S+)$/i);
    if (delimMatch) {
      delimiter = delimMatch[1];
      continue;
    }
    if (line.startsWith('--') || line === '') continue;

    buffer += rawLine + '\n';
    if (buffer.trimEnd().endsWith(delimiter)) {
      const stmt = buffer.trimEnd().slice(0, -delimiter.length).trim();
      if (stmt) out.push(stmt);
      buffer = '';
    }
  }
  if (buffer.trim()) out.push(buffer.trim());
  return out;
}

(async () => {
  // Baca CA sama seperti src/config/database.js — bukan cek ada/tidak
  function buildSsl() {
    if (process.env.DB_SSL !== 'true') return undefined;

    const caSetting = process.env.DB_SSL_CA || '';
    const wajibVerifikasi = process.env.DB_SSL_VERIFY === 'true';

    let caContent = '';
    if (caSetting.trim().startsWith('-----BEGIN')) {
      caContent = caSetting.trim();
    } else if (caSetting) {
      const caPath = path.resolve(__dirname, '..', caSetting);
      if (fs.existsSync(caPath)) {
        caContent = fs.readFileSync(caPath, 'utf8').trim();
      }
    }

    if (caContent) {
      if (!caContent.includes('-----BEGIN CERTIFICATE-----')) {
        caContent = `-----BEGIN CERTIFICATE-----\n${caContent}\n-----END CERTIFICATE-----\n`;
      }
      return { ca: caContent, rejectUnauthorized: true };
    }

    if (wajibVerifikasi) {
      throw new Error(
        `DB_SSL_VERIFY=true tetapi CA tidak ditemukan di "${caSetting || '(DB_SSL_CA kosong)'}". `
        + 'Unduh ca.pem dari dashboard Aiven lalu simpan sebagai cleano-backend/certs/ca.pem.',
      );
    }

    console.warn('[warn] CA tidak ditemukan, TLS tanpa verifikasi sertifikat');
    return { rejectUnauthorized: false };
  }

  const ssl = buildSsl();

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    multipleStatements: false,
    ssl,
  });

  const sql = fs.readFileSync(path.resolve(__dirname, '..', 'database_schema.sql'), 'utf8');
  const statements = splitStatements(sql);
  console.log(`menjalankan ${statements.length} statement...`);

  for (let i = 0; i < statements.length; i++) {
    try {
      await conn.query(statements[i]);
    } catch (err) {
      console.error(`\nGAGAL pada statement #${i + 1}: ${err.code}\n${err.message}\n`);
      console.error(statements[i].slice(0, 300));
      await conn.end();
      process.exit(1);
    }
  }
  console.log('schema dimuat tanpa error');

  const db = process.env.DB_NAME || 'cleano_db';
  const [rows] = await conn.query(
    `select
       (select count(*) from information_schema.tables
          where table_schema = ? and table_type = 'BASE TABLE') as tables,
       (select count(*) from information_schema.views where table_schema = ?) as views,
       (select count(*) from information_schema.triggers where trigger_schema = ?) as triggers`,
    [db, db, db]
  );
  console.log(`objek di ${db}:`, JSON.stringify(rows[0]));

  const [seed] = await conn.query(`select name, points from ${db}.users`);
  console.log('seeder:', seed.map((u) => `${u.name}=${u.points}`).join(', '));

  await conn.end();
})().catch((e) => {
  console.error('GAGAL:', e.code || e.message);
  process.exit(1);
});