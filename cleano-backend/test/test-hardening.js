// Uji B10 pengerasan: header keamanan, batas body, rate limit, dan logger.
process.env.AUTH_LOGIN_LIMIT = '2';
process.env.AUTH_REGISTER_LIMIT = '2';
process.env.JSON_BODY_LIMIT = '2kb';
// Gunakan 1 hop proxy agar pemisahan rate limit per IP teruji.
process.env.TRUST_PROXY_HOPS = '1';

require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');
const { createLogger, describe } = require('../src/utils/logger');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

// Awalan email uji di luar try agar selalu dibersihkan di finally.
let awalanUji = null;

async function call(path, { method = 'GET', body, token, raw, ip } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (ip) headers['X-Forwarded-For'] = ip;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json, headers: res.headers };
}

(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    // ---- header keamanan ----
    const health = await call('/api/health');
    ok('health 200', health.status === 200, `status ${health.status}`);
    ok('x-content-type-options: nosniff',
      health.headers.get('x-content-type-options') === 'nosniff',
      health.headers.get('x-content-type-options'));
    ok('tidak membocorkan x-powered-by',
      health.headers.get('x-powered-by') === null,
      health.headers.get('x-powered-by'));
    ok('x-frame-options terpasang',
      Boolean(health.headers.get('x-frame-options')),
      health.headers.get('x-frame-options'));

    // Uji batas ukuran JSON body (2 KB) menolak payload 8 KB (413).
    const besar = JSON.stringify({ email: 'a@b.c', password: 'x'.repeat(8000) });
    const tooBig = await call('/api/auth/login', { method: 'POST', raw: besar });
    ok('body melebihi batas ditolak 413', tooBig.status === 413, `status ${tooBig.status}`);
    ok('pesan 413 menyebut batas ukuran',
      /ukuran body/i.test(tooBig.json?.message ?? ''), tooBig.json?.message);
    ok('pesan 413 tidak membocorkan stack',
      !/at |node_modules|\.js:/.test(tooBig.json?.message ?? ''), tooBig.json?.message);

    // Uji rate limit login menolak permintaan ke-3 dengan status 429.
    const sandiSalah = { email: 'kasir@cleano.id', password: 'salah-sekali' };
    const IP_A = '10.1.1.1';
    const r1 = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_A });
    const r2 = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_A });
    const r3 = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_A });
    ok('dua percobaan pertama tidak dibatasi',
      r1.status !== 429 && r2.status !== 429, `${r1.status} ${r2.status}`);
    ok('percobaan ketiga dibatasi 429', r3.status === 429, `status ${r3.status}`);
    ok('respons 429 berbahasa Indonesia',
      /percobaan masuk/i.test(r3.json?.message ?? ''), r3.json?.message);
    ok('respons 429 memakai amplop success:false', r3.json?.success === false);
    // Pesan menyebut durasi yang sama dengan jendela limiter (15 menit).
    ok('pesan 429 menyebut durasi jendela', /15 menit/.test(r3.json?.message ?? ''),
      r3.json?.message);

    // Pastikan ember rate limit terpisah antar alamat IP berbeda.
    const IP_B = '10.2.2.2';
    const lain1 = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_B });
    const lain2 = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_B });
    ok('IP lain tidak terpengaruh batas IP pertama',
      lain1.status !== 429 && lain2.status !== 429, `${lain1.status} ${lain2.status}`);
    const lain3 = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_B });
    ok('IP lain punya kuota sendiri', lain3.status === 429, `status ${lain3.status}`);
    // IP pertama sudah habis; masih harus 429 (bukan ter-reset oleh IP kedua).
    const ulangA = await call('/api/auth/login', { method: 'POST', body: sandiSalah, ip: IP_A });
    ok('kuota IP pertama tidak ter-reset oleh IP lain', ulangA.status === 429,
      `status ${ulangA.status}`);

    // Pastikan endpoint non-auth tidak ikut terkena pembatasan rate limit login.
    const sehat = [];
    for (let i = 0; i < 8; i += 1) sehat.push((await call('/api/health', { ip: IP_A })).status);
    ok('health tetap 200 walau kuota login habis', sehat.every((s) => s === 200),
      sehat.join(' '));

    // Pastikan X-Forwarded-For berantai tetap memakai IP hop paling kanan yang tepercaya.
    const IP_PROXY = '10.9.9.9';
    const spoof = [];
    for (let i = 0; i < 4; i += 1) {
      spoof.push((await call('/api/auth/login', {
        method: 'POST', body: sandiSalah, ip: `192.168.${i}.${i}, ${IP_PROXY}`,
      })).status);
    }
    ok('X-Forwarded-For berantai tidak memberi ember baru',
      spoof.includes(429) && spoof[spoof.length - 1] === 429, spoof.join(' '));

    // ---- login benar tetap diblokir setelah kuota habis ----
    const benar = await call('/api/auth/login', {
      method: 'POST', body: { email: 'kasir@cleano.id', password: 'password123' }, ip: IP_A,
    });
    ok('login benar tetap diblokir selama jendela limiter', benar.status === 429,
      `status ${benar.status}`);

    // Uji rate limit register dan bersihkan semua user uji berbasis awalan email.
    const cap = `${Date.now()}`;
    const AWALAN = `b10-${cap}-`;
    awalanUji = AWALAN;
    const daftar = (i) => ({
      name: `Uji B10 ${i}`, email: `${AWALAN}${i}@uji.id`,
      password: 'password123', phone: `0812${cap.slice(-4)}${i}`,
    });
    const IP_C = '10.3.3.3';
    const g1 = await call('/api/auth/register', { method: 'POST', body: daftar(1), ip: IP_C });
    const g2 = await call('/api/auth/register', { method: 'POST', body: daftar(2), ip: IP_C });
    const g3 = await call('/api/auth/register', { method: 'POST', body: daftar(3), ip: IP_C });
    ok('registrasi kedua masih dilayani', g1.status !== 429 && g2.status !== 429,
      `${g1.status} ${g2.status}`);
    ok('registrasi ketiga dibatasi 429', g3.status === 429, `status ${g3.status}`);

    // Hapus semua user uji berbasis awalan email demi keamanan uji mutasi.
    const [del] = await pool.query('delete from users where email like ?', [`${AWALAN}%`]);
    ok('user uji registrasi dibersihkan', del.affectedRows === 2, `${del.affectedRows} baris`);

    // Pastikan logger tidak pernah mencatat sandi maupun token ke log.
    const lines = [];
    const asli = { out: process.stdout.write, err: process.stderr.write };
    const tangkap = (buf) => { lines.push(String(buf)); return true; };
    process.stdout.write = tangkap;
    process.stderr.write = tangkap;
    try {
      const log = createLogger('uji');
      log.error('permintaan gagal', { code: 'ER_NO_SUCH_TABLE', status: 500 });
    } finally {
      process.stdout.write = asli.out;
      process.stderr.write = asli.err;
    }
    const isiLog = lines.join('');
    ok('log berbentuk satu baris JSON', lines.length === 1 && isiLog.trim().startsWith('{'),
      `${lines.length} baris`);
    const parsed = JSON.parse(isiLog.trim());
    ok('log membawa level dan waktu',
      parsed.level === 'error' && Boolean(parsed.time), `${parsed.level} ${parsed.time}`);
    ok('log membawa scope', parsed.meta?.scope === 'uji', parsed.meta?.scope);
    ok('log tanpa baris baru di tengah', isiLog.trim().split('\n').length === 1);

    // describe() dipakai error handler; pastikan tidak meneruskan kolom password.
    const contohErr = Object.assign(new Error('gagal'), { password: 'rahasia', token: 'abc' });
    const desc = describe(contohErr);
    ok('describe tidak menyalin field password/token',
      !('password' in desc) && !('token' in desc),
      Object.keys(desc).join(','));
  } finally {
    // Jaring pengaman pembersihan user uji jika terjadi kegagalan di tengah tes.
    if (awalanUji) {
      await pool.query('delete from users where email like ?', [`${awalanUji}%`]).catch(() => {});
    }
    const pass = rows.filter((r) => r.pass).length;
    for (const r of rows) {
      console.log(`${r.pass ? 'OK  ' : 'GAGAL'} ${r.name}${r.detail ? `  (${r.detail})` : ''}`);
    }
    console.log(`\n${pass}/${rows.length} lulus`);
    server.close();
    await pool.end().catch(() => {});
    if (pass !== rows.length) process.exitCode = 1;
  }
})();