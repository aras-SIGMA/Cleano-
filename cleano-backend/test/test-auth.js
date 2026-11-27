// Uji endpoint auth di Aiven lalu bersihkan user uji.
require('dotenv').config({ quiet: true });

// Naikkan batas rate limit khusus di suite ini; limiter diuji di test-hardening.
process.env.AUTH_LOGIN_LIMIT = '1000';
process.env.AUTH_REGISTER_LIMIT = '1000';

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
  const pass = 'rahasiaUji123';
  let userId = null;

  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    // ---- register: validasi input ----
    for (const [label, body] of [
      ['register tanpa nama', { email, password: pass, phone }],
      ['register email salah', { name: 'Uji', email: 'bukan-email', password: pass, phone }],
      ['register password pendek', { name: 'Uji', email, password: 'pendek', phone }],
      ['register phone bukan angka', { name: 'Uji', email, password: pass, phone: 'abcd12345' }],
    ]) {
      const r = await call('/api/auth/register', { method: 'POST', body }); // eslint-disable-line no-await-in-loop
      ok(label, r.status === 400 && r.json?.success === false, `status ${r.status}`);
    }

    // ---- register: sukses ----
    const reg = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email, password: pass, phone },
    });
    ok('register sukses 201', reg.status === 201, `status ${reg.status}`);
    ok('register beri token', typeof reg.json?.data?.token === 'string' && reg.json.data.token.length > 20);
    ok('register role pelanggan', reg.json?.data?.user?.role === 'pelanggan', reg.json?.data?.user?.role);
    ok('register tier Silver', reg.json?.data?.user?.tier === 'Silver', reg.json?.data?.user?.tier);
    ok('register member_code MBR-', /^MBR-\d{4,}$/.test(reg.json?.data?.user?.member_code || ''), reg.json?.data?.user?.member_code);
    ok('register tidak bocorkan password', !JSON.stringify(reg.json).includes(pass) && reg.json?.data?.user?.password === undefined);

    userId = reg.json?.data?.user?.id ?? null;

    // ---- register: duplikat ----
    const dupEmail = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email, password: pass, phone: `0899${stamp}` },
    });
    ok('register email duplikat 409', dupEmail.status === 409, `status ${dupEmail.status}`);
    ok('register email duplikat sebut email', /email sudah terdaftar/i.test(dupEmail.json?.message ?? ''), dupEmail.json?.message);

    const dupPhone = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email: `lain.${stamp}@cleano.test`, password: pass, phone },
    });
    ok('register phone duplikat 409', dupPhone.status === 409, `status ${dupPhone.status}`);
    // Pastikan pesan duplikat menunjuk kolom email atau phone yang benar.
    ok('register phone duplikat sebut nomor HP', /nomor hp sudah terdaftar/i.test(dupPhone.json?.message ?? ''), dupPhone.json?.message);

    // Pastikan bentrok email dan phone bersamaan tetap membalas HTTP 409.
    const dupBoth = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji', email, password: pass, phone },
    });
    ok('register email+phone duplikat 409', dupBoth.status === 409, `status ${dupBoth.status}`);
    ok('register duplikat tidak salah sebut member_code',
      !/kode member/i.test(dupBoth.json?.message ?? ''), dupBoth.json?.message);

    // ---- login ----
    const badPass = await call('/api/auth/login', { method: 'POST', body: { email, password: 'salahbanget' } });
    ok('login password salah 401', badPass.status === 401, `status ${badPass.status}`);

    const noUser = await call('/api/auth/login', { method: 'POST', body: { email: 'tidakada@cleano.test', password: pass } });
    ok('login email tak dikenal 401', noUser.status === 401, `status ${noUser.status}`);

    const empty = await call('/api/auth/login', { method: 'POST', body: { email: '', password: '' } });
    ok('login kosong 400', empty.status === 400, `status ${empty.status}`);

    const login = await call('/api/auth/login', { method: 'POST', body: { email, password: pass } });
    ok('login sukses 200', login.status === 200, `status ${login.status}`);
    ok('login beri token', typeof login.json?.data?.token === 'string' && login.json.data.token.length > 20);
    ok('login email case-insensitive', (await call('/api/auth/login', { method: 'POST', body: { email: email.toUpperCase(), password: pass } })).status === 200);

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
      body: { name: 'User Uji 2', email: `uji2.${stamp}@cleano.test`, password: 'password123', phone: `0898${stamp}` },
    });
    const code1 = reg.json?.data?.user?.member_code;
    const code2 = reg2.json?.data?.user?.member_code;
    ok('member_code naik 1', Number((code2 || '').slice(4)) === Number((code1 || '').slice(4)) + 1, `${code1} -> ${code2}`);

    // Uji ulang C-1: member_code bentrok otomatis diulang, bukan membalas 409.
    const realGet = pool.getConnection.bind(pool);
    const taken = 'MBR-0001';
    let armed = true;
    pool.getConnection = async () => {
      const conn = await realGet();
      const q = conn.query.bind(conn);
      conn.query = (sql, params) => {
        if (armed && /select member_code from users/i.test(String(sql))) {
          armed = false;
          return Promise.resolve([[{ member_code: 'MBR-0000' }]]); // next = MBR-0001
        }
        return q(sql, params);
      };
      return conn;
    };
    let race;
    try {
      race = await call('/api/auth/register', {
        method: 'POST',
        body: { name: 'User Balapan', email: `uji3.${stamp}@cleano.test`, password: 'password123', phone: `0897${stamp}` },
      });
    } finally {
      pool.getConnection = realGet;
    }
    ok('M1: member_code bentrok diulang (bukan 409)', race.status === 201, `status ${race.status}`);
    ok('M1: kode baru berbeda dari yang bentrok', race.json?.data?.user?.member_code !== taken, `${race.json?.data?.user?.member_code} vs ${taken}`);

    // ---- R-4: batas atas password ----
    const longPass = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'Uji', email: `uji4.${stamp}@cleano.test`, password: 'a'.repeat(129), phone: `0896${stamp}` },
    });
    ok('register password terlalu panjang 400', longPass.status === 400, `status ${longPass.status}`);

    // ---- validasi zod: body aneh, nama kepanjangan, normalisasi HP ----
    const noBody = await call('/api/auth/register', { method: 'POST' });
    ok('register tanpa body 400', noBody.status === 400, `status ${noBody.status}`);

    const longName = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'x'.repeat(101), email: `uji5.${stamp}@cleano.test`, password: pass, phone: `0895${stamp}` },
    });
    ok('register nama 101 karakter 400', longName.status === 400, `status ${longName.status}`);

    // email 100+ karakter harus ditolak validator, bukan 500 dari kolom varchar(100)
    const longEmail = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'Uji', email: `${'a'.repeat(95)}@cleano.test`, password: pass, phone: `0894${stamp}` },
    });
    ok('register email 107 karakter 400', longEmail.status === 400, `status ${longEmail.status}`);

    const dashed = await call('/api/auth/login', {
      method: 'POST',
      body: { email: `  ${email.toUpperCase()}  `, password: pass },
    });
    ok('login email spasi & huruf besar tetap 200', dashed.status === 200, `status ${dashed.status}`);

    // password pendek di login = kredensial salah (401), bukan aturan registrasi (400)
    const shortLogin = await call('/api/auth/login', { method: 'POST', body: { email, password: 'pendek' } });
    ok('login password pendek 401 (bukan 400)', shortLogin.status === 401, `status ${shortLogin.status}`);

    // nomor HP bertanda hubung dinormalisasi saat registrasi
    const dashedPhone = `0813-${stamp.slice(0, 4)}-${stamp.slice(4)}`;
    const norm = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'User Uji 6', email: `uji6.${stamp}@cleano.test`, password: pass, phone: dashedPhone },
    });
    ok('register HP bertanda hubung 201', norm.status === 201, `status ${norm.status}`);
    ok('HP tersimpan tanpa tanda hubung', norm.json?.data?.user?.phone === dashedPhone.replace(/-/g, ''), norm.json?.data?.user?.phone);

    // Pastikan email berisi kata 'member_code' tetap terdeteksi sebagai duplikat email.
    const aneh = `member_code.phone.${stamp}@cleano.test`;
    const a1 = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'Uji Alamat Aneh', email: aneh, password: pass, phone: `0893${stamp}` },
    });
    ok('register email memuat kata member_code 201', a1.status === 201, `status ${a1.status}`);
    const a2 = await call('/api/auth/register', {
      method: 'POST',
      body: { name: 'Uji Alamat Aneh', email: aneh, password: pass, phone: `0892${stamp}` },
    });
    ok('duplikat email memuat kata member_code tetap disebut email',
      a2.status === 409 && /email sudah terdaftar/i.test(a2.json?.message ?? ''),
      `${a2.status} ${a2.json?.message}`);
  } catch (err) {
    ok('tes auth tidak melempar error', false, err.message);
  } finally {
    // Hapus user uji berdasarkan pola email di blok finally.
    const [sisa] = await pool
      .query('delete from users where email like ?', [`%.${stamp}@cleano.test`])
      .catch(() => [null]);
    const [[left]] = await pool
      .query('select count(*) as n from users where email like ?', [`%.${stamp}@cleano.test`])
      .catch(() => [[{ n: -1 }]]);
    ok('bersih: user uji terhapus', left.n === 0, `sisa ${left.n} (dihapus ${sisa?.affectedRows ?? '?'})`);

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