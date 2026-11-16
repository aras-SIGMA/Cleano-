// Uji endpoint auth terhadap Aiven. Membuat user uji lalu menghapusnya lagi.
// Jalankan: npm run test:auth
require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

async function call(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* respons tanpa body */
  }
  return { status: res.status, json };
}

(async () => {
  const stamp = Date.now().toString().slice(-8);
  const email = `uji.${stamp}@cleano.test`;
  const phone = `0812${stamp}`;
  let userId = null;

  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    // ---- register: validasi input ----
    for (const [label, body] of [
      ['register tanpa nama', { email, password: 'UjiRahasia123', phone }],
      ['register email salah', { name: 'Uji', email: 'bukan-email', password: 'UjiRahasia123', phone }],
      ['register password pendek', { name: 'Uji', email, password: 'pendek', phone }],
      ['register phone bukan angka', { name: 'Uji', email, password: 'UjiRahasia123', phone: 'abcd12345' }],
    ]) {
      const r = await call('/api/auth/register', { method: 'POST', body }); // eslint-disable-line no-await-in-loop
      ok(label, r.status === 400 && r.json?.success === false, `status ${r.status}`);
    }

    // ---- register: sukses ----
    const reg = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email, password: 'UjiRahasia123', phone },
    });
    ok('register sukses 201', reg.status === 201, `status ${reg.status}`);
    ok('register beri token', typeof reg.json?.data?.token === 'string' && reg.json.data.token.length > 20);
    ok('register role pelanggan', reg.json?.data?.user?.role === 'pelanggan', reg.json?.data?.user?.role);
    ok('register tier Silver', reg.json?.data?.user?.tier === 'Silver', reg.json?.data?.user?.tier);
    ok('register member_code MBR-', /^MBR-\d{4,}$/.test(reg.json?.data?.user?.member_code || ''), reg.json?.data?.user?.member_code);
    ok('register tidak bocorkan password', !JSON.stringify(reg.json).includes('UjiRahasia123') && reg.json?.data?.user?.password === undefined);

    userId = reg.json?.data?.user?.id ?? null;

    // ---- register: duplikat ----
    const dupEmail = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email, password: 'UjiRahasia123', phone: `0899${stamp}` },
    });
    ok('register email duplikat 409', dupEmail.status === 409, `status ${dupEmail.status}`);

    const dupPhone = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email: `lain.${stamp}@cleano.test`, password: 'UjiRahasia123', phone },
    });
    ok('register phone duplikat 409', dupPhone.status === 409, `status ${dupPhone.status}`);

    // ---- login ----
    const badPass = await call('/api/auth/login', { method: 'POST', body: { email, password: 'salahbanget' } });
    ok('login password salah 401', badPass.status === 401, `status ${badPass.status}`);

    const noUser = await call('/api/auth/login', { method: 'POST', body: { email: 'tidakada@cleano.test', password: 'UjiRahasia123' } });
    ok('login email tak dikenal 401', noUser.status === 401, `status ${noUser.status}`);

    const empty = await call('/api/auth/login', { method: 'POST', body: { email: '', password: '' } });
    ok('login kosong 400', empty.status === 400, `status ${empty.status}`);

    const login = await call('/api/auth/login', { method: 'POST', body: { email, password: 'UjiRahasia123' } });
    ok('login sukses 200', login.status === 200, `status ${login.status}`);
    ok('login beri token', typeof login.json?.data?.token === 'string' && login.json.data.token.length > 20);
    ok('login email case-insensitive', (await call('/api/auth/login', { method: 'POST', body: { email: email.toUpperCase(), password: 'UjiRahasia123' } })).status === 200);

    // ---- login akun seeder (password123) ----
    const seeded = await call('/api/auth/login', { method: 'POST', body: { email: 'kasir@cleano.id', password: 'password123' } });
    ok('login seeder kasir', seeded.status === 200, `status ${seeded.status}`);
    ok('seeder role kasir', seeded.json?.data?.user?.role === 'kasir', seeded.json?.data?.user?.role);
    ok('seeder tier Silver (poin 0)', seeded.json?.data?.user?.tier === 'Silver', seeded.json?.data?.user?.tier);

    const rina = await call('/api/auth/login', { method: 'POST', body: { email: 'rina@gmail.com', password: 'password123' } });
    ok('login seeder rina', rina.status === 200, `status ${rina.status}`);
    ok('rina tier Gold (poin 150)', rina.json?.data?.user?.tier === 'Gold', `${rina.json?.data?.user?.tier} poin=${rina.json?.data?.user?.points}`);

    const budi = await call('/api/auth/login', { method: 'POST', body: { email: 'budi@gmail.com', password: 'password123' } });
    ok('budi tier Silver (poin 45)', budi.json?.data?.user?.tier === 'Silver', `${budi.json?.data?.user?.tier} poin=${budi.json?.data?.user?.points}`);

    // ---- token bisa dipakai middleware ----
    const token = login.json?.data?.token;
    const decoded = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
    ok('payload JWT berisi id/role', decoded.id === userId && decoded.role === 'pelanggan', JSON.stringify({ id: decoded.id, role: decoded.role }));
    const ttlHours = Math.round((decoded.exp - decoded.iat) / 3600);
    ok('JWT berlaku 24 jam', ttlHours === 24, `${ttlHours} jam`);

    // ---- member_code unik berurutan ----
    const reg2 = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji 2', email: `uji2.${stamp}@cleano.test`, password: 'UjiRahasia123', phone: `0898${stamp}` },
    });
    const code1 = reg.json?.data?.user?.member_code;
    const code2 = reg2.json?.data?.user?.member_code;
    ok('member_code naik 1', Number((code2 || '').slice(4)) === Number((code1 || '').slice(4)) + 1, `${code1} -> ${code2}`);
    if (reg2.json?.data?.user?.id) {
      await pool.query('delete from users where id = ?', [reg2.json.data.user.id]);
    }
  } catch (err) {
    ok('tes auth tidak melempar error', false, err.message);
  } finally {
    if (userId) {
      await pool.query('delete from users where id = ?', [userId]).catch(() => {});
    }
    const [[left]] = await pool.query('select count(*) as n from users where email like ?', [`uji.${stamp}@%`]).catch(() => [[{ n: -1 }]]);
    ok('bersih: user uji terhapus', left.n === 0, `sisa ${left.n}`);

    console.log('');
    for (const r of rows) {
      console.log(`${r.pass ? 'OK  ' : 'GAGAL'} ${r.name.padEnd(38)} ${r.detail}`);
    }
    const failed = rows.filter((r) => !r.pass).length;
    console.log(`\n${rows.length - failed}/${rows.length} lulus`);

    server.close();
    await pool.end().catch(() => {});
    process.exit(failed ? 1 : 0);
  }
})();