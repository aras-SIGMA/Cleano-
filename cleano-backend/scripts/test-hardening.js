// Uji B10: pengerasan. Header keamanan, batas body, rate limit, dan kebocoran
// informasi di log.
//
// Limiter diuji dengan batas kecil (2) lalu dipulihkan. Server dijalankan di
// dalam proses ini, jadi `require('../server')` cukup dipanggil sekali setelah
// env di bawah diset.
// Jalankan: npm run test:hardening
process.env.AUTH_LOGIN_LIMIT = '2';
process.env.AUTH_REGISTER_LIMIT = '2';
process.env.JSON_BODY_LIMIT = '2kb';

require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');
const { createLogger } = require('../src/utils/logger');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

// Awalan email user uji. Dideklarasikan di luar try supaya finally bisa
// menyapunya walau tes gagal sebelum baris registrasi dijalankan.
let awalanUji = null;

async function call(path, { method = 'GET', body, token, raw } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
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

    // ---- batas ukuran body ----
    // JSON_BODY_LIMIT=2kb; body 8kb harus ditolak 413, bukan diterima lalu
    // menghabiskan memori.
    const besar = JSON.stringify({ email: 'a@b.c', password: 'x'.repeat(8000) });
    const tooBig = await call('/api/auth/login', { method: 'POST', raw: besar });
    ok('body melebihi batas ditolak 413', tooBig.status === 413, `status ${tooBig.status}`);
    ok('pesan 413 menyebut batas ukuran',
      /ukuran body/i.test(tooBig.json?.message ?? ''), tooBig.json?.message);
    ok('pesan 413 tidak membocorkan stack',
      !/at |node_modules|\.js:/.test(tooBig.json?.message ?? ''), tooBig.json?.message);

    // ---- rate limit login ----
    // Batas diset 2. Permintaan ke-3 harus 429.
    const sandiSalah = { email: 'kasir@cleano.id', password: 'salah-sekali' };
    const r1 = await call('/api/auth/login', { method: 'POST', body: sandiSalah });
    const r2 = await call('/api/auth/login', { method: 'POST', body: sandiSalah });
    const r3 = await call('/api/auth/login', { method: 'POST', body: sandiSalah });
    ok('dua percobaan pertama tidak dibatasi',
      r1.status !== 429 && r2.status !== 429, `${r1.status} ${r2.status}`);
    ok('percobaan ketiga dibatasi 429', r3.status === 429, `status ${r3.status}`);
    ok('respons 429 berbahasa Indonesia',
      /percobaan masuk/i.test(r3.json?.message ?? ''), r3.json?.message);
    ok('respons 429 memakai amplop success:false', r3.json?.success === false);

    // Kredensial yang benar pun tetap ditolak selama jendela aktif.
    const benar = await call('/api/auth/login', {
      method: 'POST', body: { email: 'kasir@cleano.id', password: 'password123' },
    });
    ok('login benar tetap diblokir selama jendela limiter', benar.status === 429,
      `status ${benar.status}`);

    // ---- rate limit register ----
    // Email dibekukan sekali: kalau daftar() memanggil Date.now() setiap kali,
    // email yang dihapus di akhir tidak sama dengan yang tersimpan.
    //
    // Saat limiter sengaja dimatikan (uji mutasi), ketiga registrasi lolos dan
    // ketiganya harus dibersihkan — karena itu penghapusan memakai awalan email,
    // bukan daftar email yang "seharusnya" dibuat.
    const cap = `${Date.now()}`;
    const AWALAN = `b10-${cap}-`;
    awalanUji = AWALAN;
    const daftar = (i) => ({
      name: `Uji B10 ${i}`, email: `${AWALAN}${i}@uji.id`,
      password: 'password123', phone: `0812${cap.slice(-4)}${i}`,
    });
    const g1 = await call('/api/auth/register', { method: 'POST', body: daftar(1) });
    const g2 = await call('/api/auth/register', { method: 'POST', body: daftar(2) });
    const g3 = await call('/api/auth/register', { method: 'POST', body: daftar(3) });
    ok('registrasi kedua masih dilayani', g1.status !== 429 && g2.status !== 429,
      `${g1.status} ${g2.status}`);
    ok('registrasi ketiga dibatasi 429', g3.status === 429, `status ${g3.status}`);

    // Bersihkan seluruh user uji dari run ini, berapa pun yang lolos dibuat.
    // Penghapusan per-id tidak aman: saat limiter sengaja dimatikan, jumlah yang
    // lolos berubah dan sisanya akan tertinggal di DB.
    const [del] = await pool.query('delete from users where email like ?', [`${AWALAN}%`]);
    ok('user uji registrasi dibersihkan', del.affectedRows === 2, `${del.affectedRows} baris`);

    // ---- log tidak membocorkan rahasia ----
    // Logger diuji langsung: objek yang dilog tidak boleh memuat sandi atau
    // token, karena log sering dikirim ke layanan pihak ketiga.
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
    const { describe } = createLogger('uji');
    const contohErr = Object.assign(new Error('gagal'), { password: 'rahasia', token: 'abc' });
    const desc = describe(contohErr);
    ok('describe tidak menyalin field password/token',
      !('password' in desc) && !('token' in desc),
      Object.keys(desc).join(','));
  } finally {
    // Jaring pengaman: kalau tes gagal sebelum baris pembersihan tercapai,
    // user uji tetap tidak boleh tertinggal.
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