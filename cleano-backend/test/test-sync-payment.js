// Uji B7 sync-payment dengan stub fetchStatus dalam transaksi lalu ROLLBACK.
require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');
const { isPaid, attemptSyncPayment } = require('../src/services/paymentSync');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

async function login(email, password) {
  const res = await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const json = await res.json().catch(() => null);
  return json?.data?.token ?? null;
}

async function call(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

async function inTx(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    return await fn(conn);
  } finally {
    await conn.rollback().catch(() => {});
    conn.release();
  }
}

async function tryTx(fn) {
  try {
    return { ok: true, value: await inTx(fn) };
  } catch (err) {
    return { ok: false, error: `${err.status || err.code || ''} ${err.message}`.trim() };
  }
}

// Buat order midtrans belum_bayar memakai layanan tanpa mesin di dalam transaksi.
const fake = (transactionStatus, fraudStatus = null) => async () => ({
  transaction_status: transactionStatus,
  fraud_status: fraudStatus,
});

async function makeOrder(conn, code) {
  const [ins] = await conn.query(
    `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
       status, image_url)
     values (?, 2, 4, null, 2.00, 'midtrans', 'sedang_diproses', '/uploads/uji.png')`,
    [code],
  );
  return ins.insertId;
}

(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    const kasir = await login('kasir@cleano.id', 'password123');
    const pelanggan = await login('rina@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasir));
    ok('login pelanggan untuk uji', Boolean(pelanggan));

    // ---- otorisasi & validasi lewat HTTP (tidak ada baris yang berubah) ----
    const noToken = await call('/api/orders/3/sync-payment', { method: 'POST' });
    ok('tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    const asPelanggan = await call('/api/orders/3/sync-payment', { method: 'POST', token: pelanggan });
    ok('pelanggan 403', asPelanggan.status === 403, `status ${asPelanggan.status}`);

    const badId = await call('/api/orders/abc/sync-payment', { method: 'POST', token: kasir });
    ok(':id non-angka 400', badId.status === 400, `status ${badId.status}`);

    const missing = await call('/api/orders/999999/sync-payment', { method: 'POST', token: kasir });
    ok('order tidak ada 404', missing.status === 404, `status ${missing.status}`);

    // Order tunai tidak punya transaksi Midtrans. Seeder id 3 = tunai.
    const tunai = await call('/api/orders/3/sync-payment', { method: 'POST', token: kasir });
    ok('order tunai ditolak 400', tunai.status === 400, `status ${tunai.status}`);

    // Pastikan order yang sudah lunas tidak memanggil gateway Midtrans lagi.
    const sudahLunas = await call('/api/orders/2/sync-payment', { method: 'POST', token: kasir });
    ok('order lunas 200 tanpa panggilan gateway', sudahLunas.status === 200, `status ${sudahLunas.status}`);
    ok('order lunas melaporkan changed=false', sudahLunas.json?.data?.changed === false,
      `${sudahLunas.json?.data?.changed}`);
    ok('snap_token tidak ikut di respons', sudahLunas.json?.data?.snap_token === undefined);

    // ---- isPaid: aturan status gateway ----
    ok('settlement dihitung lunas', isPaid({ transaction_status: 'settlement' }));
    ok('capture + accept dihitung lunas',
      isPaid({ transaction_status: 'capture', fraud_status: 'accept' }));
    // capture tanpa fraud accept belum tentu uangnya sampai.
    ok('capture + challenge tidak lunas',
      !isPaid({ transaction_status: 'capture', fraud_status: 'challenge' }));
    ok('capture tanpa fraud_status tidak lunas', !isPaid({ transaction_status: 'capture' }));
    for (const s of ['pending', 'deny', 'cancel', 'expire', 'failure', 'refund']) {
      ok(`${s} tidak dihitung lunas`, !isPaid({ transaction_status: s }));
    }
    ok('respons gateway kosong tidak dihitung lunas', !isPaid({}));

    // ---- settlement menandai lunas, paid_at diisi trigger ----
    const settle = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8801');
      const [[before]] = await conn.query('select payment_status, paid_at from orders where id = ?', [id]);
      const res = await attemptSyncPayment(conn, id, { fetchStatus: fake('settlement') });
      const [[after]] = await conn.query('select payment_status, paid_at from orders where id = ?', [id]);
      return { before, after, res };
    });
    ok('settlement -> payment_status lunas', settle.ok && settle.value.after.payment_status === 'lunas',
      settle.ok ? settle.value.after.payment_status : settle.error);
    ok('paid_at kosong sebelum sinkronisasi', settle.ok && settle.value.before.paid_at === null,
      settle.ok ? `${settle.value.before.paid_at}` : settle.error);
    // Backend tidak menulis paid_at sendiri (L-04); trigger yang menstempel.
    ok('paid_at diisi trigger saat lunas', settle.ok && settle.value.after.paid_at !== null,
      settle.ok ? `${settle.value.after.paid_at}` : settle.error);
    ok('settlement melaporkan changed=true', settle.ok && settle.value.res.changed === true,
      settle.ok ? `${settle.value.res.changed}` : settle.error);

    // ---- capture + accept juga lunas ----
    const capture = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8802');
      await attemptSyncPayment(conn, id, { fetchStatus: fake('capture', 'accept') });
      const [[row]] = await conn.query('select payment_status from orders where id = ?', [id]);
      return row.payment_status;
    });
    ok('capture + accept -> lunas', capture.ok && capture.value === 'lunas',
      capture.ok ? capture.value : capture.error);

    // ---- capture + challenge tidak boleh melunasi ----
    const challenge = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8803');
      const res = await attemptSyncPayment(conn, id, { fetchStatus: fake('capture', 'challenge') });
      const [[row]] = await conn.query('select payment_status from orders where id = ?', [id]);
      return { status: row.payment_status, res };
    });
    ok('capture + challenge tetap belum_bayar',
      challenge.ok && challenge.value.status === 'belum_bayar',
      challenge.ok ? challenge.value.status : challenge.error);
    ok('capture + challenge melaporkan changed=false',
      challenge.ok && challenge.value.res.changed === false,
      challenge.ok ? `${challenge.value.res.changed}` : challenge.error);

    // ---- pending tidak melunasi apa pun ----
    const pending = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8804');
      const res = await attemptSyncPayment(conn, id, { fetchStatus: fake('pending') });
      const [[row]] = await conn.query('select payment_status from orders where id = ?', [id]);
      return { status: row.payment_status, res };
    });
    ok('pending tetap belum_bayar', pending.ok && pending.value.status === 'belum_bayar',
      pending.ok ? pending.value.status : pending.error);
    ok('pending melaporkan status gateway', pending.ok && pending.value.res.transactionStatus === 'pending',
      pending.ok ? `${pending.value.res.transactionStatus}` : pending.error);

    // ---- sudah lunas: tidak memanggil gateway lagi ----
    const twice = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8805');
      await attemptSyncPayment(conn, id, { fetchStatus: fake('settlement') });
      let calls = 0;
      const res = await attemptSyncPayment(conn, id, {
        fetchStatus: async () => { calls += 1; return { transaction_status: 'settlement' }; },
      });
      return { res, calls };
    });
    ok('sinkronisasi kedua tidak memanggil gateway', twice.ok && twice.value.calls === 0,
      twice.ok ? `${twice.value.calls} panggilan` : twice.error);
    ok('sinkronisasi kedua melaporkan alreadyPaid', twice.ok && twice.value.res.alreadyPaid === true,
      twice.ok ? `${twice.value.res.alreadyPaid}` : twice.error);

    // ---- transaksi tidak ada di gateway -> 409, bukan 500 ----
    const notInGateway = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8806');
      try {
        await attemptSyncPayment(conn, id, {
          fetchStatus: async () => {
            const err = new Error('Transaction doesn\'t exist.');
            err.httpStatusCode = 404;
            throw err;
          },
        });
        return { status: null };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    ok('gateway 404 -> 409', notInGateway.ok && notInGateway.value.status === 409,
      notInGateway.ok ? `${notInGateway.value.status} ${notInGateway.value.message}` : notInGateway.error);

    // ---- gangguan gateway -> 502, order tidak berubah ----
    const gatewayDown = await tryTx(async (conn) => {
      const id = await makeOrder(conn, 'CLN-19990101-8807');
      try {
        await attemptSyncPayment(conn, id, {
          fetchStatus: async () => { throw new Error('socket hang up'); },
        });
        return { status: null };
      } catch (e) {
        const [[row]] = await conn.query('select payment_status from orders where id = ?', [id]);
        return { status: e.status ?? null, message: e.message, payment: row.payment_status };
      }
    });
    ok('gangguan gateway -> 502', gatewayDown.ok && gatewayDown.value.status === 502,
      gatewayDown.ok ? `${gatewayDown.value.status}` : gatewayDown.error);
    ok('gangguan gateway tidak mengubah pembayaran',
      gatewayDown.ok && gatewayDown.value.payment === 'belum_bayar',
      gatewayDown.ok ? gatewayDown.value.payment : gatewayDown.error);

    // Pastikan order berstatus batal ditolak saat disinkronkan sebagai lunas.
    const batal = await tryTx(async (conn) => {
      const [ins] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-8808', 2, 4, null, 2.00, 'midtrans', 'batal', '/uploads/uji.png')`,
      );
      try {
        await attemptSyncPayment(conn, ins.insertId, { fetchStatus: fake('settlement') });
        return { status: null };
      } catch (e) {
        const [[row]] = await conn.query('select payment_status from orders where id = ?', [ins.insertId]);
        return { status: e.status ?? null, message: e.message, payment: row.payment_status };
      }
    });
    ok('order batal tidak bisa dilunasi', batal.ok && batal.value.status === 400,
      batal.ok ? `${batal.value.status} ${batal.value.message}` : batal.error);

    // Uji mode stub sync-payment saat server key kosong membalas HTTP 503.
    const { execFileSync } = require('child_process');
    let stubOut = '';
    try {
      stubOut = execFileSync(process.execPath, ['-e', `
        process.env.MIDTRANS_SERVER_KEY = '';
        require('dotenv').config({ quiet: true, override: false });
        process.env.MIDTRANS_SERVER_KEY = '';
        const app = require('./server');
        const s = app.listen(0, async () => {
          const base = 'http://127.0.0.1:' + s.address().port;
          const r1 = await fetch(base + '/api/auth/login', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'kasir@cleano.id', password: 'password123' }),
          });
          const tok = (await r1.json()).data.token;
          const r2 = await fetch(base + '/api/orders/2/sync-payment', {
            method: 'POST', headers: { Authorization: 'Bearer ' + tok },
          });
          console.log('STUB_STATUS=' + r2.status);
          s.close();
          process.exit(0);
        });
      `], { encoding: 'utf8', cwd: process.cwd(), stdio: 'pipe' });
    } catch (e) {
      stubOut = String(e.stdout || '');
    }
    const stubStatus = (stubOut.match(/STUB_STATUS=(\d+)/) || [])[1];
    ok('server key kosong -> 503', stubStatus === '503', `status ${stubStatus ?? 'tidak terbaca'}`);
  } finally {
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
