// Uji GET /api/orders terhadap Aiven. Seluruhnya baca saja, jadi tidak ada
// baris yang perlu dibersihkan: order tidak bisa dihapus (trigger L-07).
// Data acuan adalah 3 order seeder — rina 2 order (selesai, siap_diambil),
// budi 1 order (selesai, midtrans).
// Jalankan: npm run test:orders-list
require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');

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

async function get(path, { token } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, { headers });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    // id pelanggan diambil dari DB, bukan ditebak: nomor urut bisa berubah
    // kalau skema dimuat ulang.
    const [[rina]] = await pool.query("select id from users where email = 'rina@gmail.com'");
    const [[budi]] = await pool.query("select id from users where email = 'budi@gmail.com'");
    const [[jmlRina]] = await pool.query('select count(*) as n from orders where user_id = ?', [rina.id]);
    const [[jmlBudi]] = await pool.query('select count(*) as n from orders where user_id = ?', [budi.id]);

    const kasir = await login('kasir@cleano.id', 'password123');
    const tokRina = await login('rina@gmail.com', 'password123');
    const tokBudi = await login('budi@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasir));
    ok('login rina untuk uji', Boolean(tokRina));
    ok('login budi untuk uji', Boolean(tokBudi));

    // ---- otorisasi ----
    const noToken = await get('/api/orders');
    ok('tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    // ---- kasir melihat semua order ----
    const kasirAll = await get('/api/orders', { token: kasir });
    ok('kasir GET orders 200', kasirAll.status === 200, `status ${kasirAll.status}`);
    const [[totalAll]] = await pool.query('select count(*) as n from orders');
    ok('kasir melihat seluruh order', kasirAll.json?.data?.total === totalAll.n,
      `${kasirAll.json?.data?.total} vs ${totalAll.n}`);
    ok('respons memuat items/page/pageSize/total/totalPages',
      Array.isArray(kasirAll.json?.data?.items)
      && kasirAll.json?.data?.page === 1
      && kasirAll.json?.data?.pageSize === 20
      && typeof kasirAll.json?.data?.totalPages === 'number');

    // ---- pelanggan hanya melihat miliknya ----
    const rinaAll = await get('/api/orders', { token: tokRina });
    ok('rina GET orders 200', rinaAll.status === 200, `status ${rinaAll.status}`);
    ok('rina hanya melihat ordernya sendiri', rinaAll.json?.data?.total === jmlRina.n,
      `${rinaAll.json?.data?.total} vs ${jmlRina.n}`);
    ok('tidak ada order budi di daftar rina',
      (rinaAll.json?.data?.items ?? []).every((o) => o.order_code !== 'CLN-20261114-0001'),
      `${(rinaAll.json?.data?.items ?? []).map((o) => o.order_code).join(' ')}`);

    const budiAll = await get('/api/orders', { token: tokBudi });
    ok('budi hanya melihat ordernya sendiri', budiAll.json?.data?.total === jmlBudi.n,
      `${budiAll.json?.data?.total} vs ${jmlBudi.n}`);
    ok('rina dan budi melihat himpunan berbeda',
      JSON.stringify((rinaAll.json?.data?.items ?? []).map((o) => o.id))
      !== JSON.stringify((budiAll.json?.data?.items ?? []).map((o) => o.id)));

    // user_id dari query string harus diabaikan; kalau dihormati, pelanggan
    // cukup mengubah angkanya untuk membaca order orang lain.
    const spoof = await get(`/api/orders?user_id=${budi.id}`, { token: tokRina });
    ok('query user_id diabaikan untuk pelanggan', spoof.json?.data?.total === jmlRina.n,
      `${spoof.json?.data?.total} vs ${jmlRina.n}`);

    // ---- rahasia pembayaran tidak boleh ikut ----
    const pelangganItem = (rinaAll.json?.data?.items ?? [])[0] ?? {};
    ok('pelanggan tidak menerima snap_token', pelangganItem.snap_token === undefined);
    ok('pelanggan tidak menerima snap_redirect_url', pelangganItem.snap_redirect_url === undefined);
    // Data pribadi orang lain pun tidak perlu: namanya tidak dipakai di portal.
    ok('pelanggan tidak menerima nama pelanggan lain', pelangganItem.customer_name === undefined);

    const kasirItem = (kasirAll.json?.data?.items ?? [])[0] ?? {};
    ok('kasir juga tidak menerima snap_token', kasirItem.snap_token === undefined);
    ok('kasir menerima nama pelanggan', typeof kasirItem.customer_name === 'string',
      `${kasirItem.customer_name}`);
    ok('kasir menerima snap_redirect_url bila ada', 'snap_redirect_url' in kasirItem);

    // ---- field yang dibutuhkan UI pelacakan (PRD-04 §3.1) ----
    const pelacakan = ['order_code', 'service_name', 'weight', 'status', 'queue_wait_minutes',
      'machine_code', 'machine_finish_at', 'payment_status', 'total_price', 'image_url', 'points_awarded'];
    const hilang = pelacakan.filter((k) => !(k in pelangganItem));
    ok('field pelacakan tersedia untuk pelanggan', hilang.length === 0, `hilang: ${hilang.join(',')}`);

    // ---- filter status ----
    const selesai = await get('/api/orders?status=selesai', { token: kasir });
    ok('filter status=selesai 200', selesai.status === 200, `status ${selesai.status}`);
    ok('filter status=selesai hanya mengembalikan selesai',
      (selesai.json?.data?.items ?? []).every((o) => o.status === 'selesai'),
      `${(selesai.json?.data?.items ?? []).map((o) => o.status).join(' ')}`);
    const [[jmlSelesai]] = await pool.query("select count(*) as n from orders where status = 'selesai'");
    ok('jumlah filter status=selesai cocok DB', selesai.json?.data?.total === jmlSelesai.n,
      `${selesai.json?.data?.total} vs ${jmlSelesai.n}`);

    // filter harus dihormati bersama batas role, bukan menggantikannya
    const rinaBatal = await get('/api/orders?status=batal', { token: tokRina });
    ok('filter status tetap dibatasi kepemilikan',
      (rinaBatal.json?.data?.items ?? []).every((o) => o.status === 'batal'),
      `${rinaBatal.json?.data?.total}`);

    const badStatus = await get('/api/orders?status=hilang', { token: kasir });
    ok('status tidak dikenal 400', badStatus.status === 400, `status ${badStatus.status}`);

    // ---- pagination ----
    const page1 = await get('/api/orders?page=1&pageSize=2', { token: kasir });
    ok('pageSize=2 mengembalikan maksimal 2', (page1.json?.data?.items ?? []).length <= 2,
      `${(page1.json?.data?.items ?? []).length}`);
    ok('pageSize diteruskan ke respons', page1.json?.data?.pageSize === 2,
      `${page1.json?.data?.pageSize}`);
    ok('totalPages dihitung dari total', page1.json?.data?.totalPages === Math.max(1, Math.ceil(totalAll.n / 2)),
      `${page1.json?.data?.totalPages}`);

    // Halaman berbeda harus berisi baris berbeda, bukan halaman pertama diulang.
    if (totalAll.n > 2) {
      const page2 = await get('/api/orders?page=2&pageSize=2', { token: kasir });
      const id1 = (page1.json?.data?.items ?? []).map((o) => o.id).join(',');
      const id2 = (page2.json?.data?.items ?? []).map((o) => o.id).join(',');
      ok('halaman 2 berisi baris berbeda', id1 !== id2, `${id1} | ${id2}`);
      ok('jumlah seluruh halaman = total',
        (page1.json?.data?.items ?? []).length + (page2.json?.data?.items ?? []).length
        === Math.min(totalAll.n, 4),
        `${(page1.json?.data?.items ?? []).length} + ${(page2.json?.data?.items ?? []).length} vs ${totalAll.n}`);
    } else {
      ok('halaman 2 berisi baris berbeda', true, 'dilewati: order <= 2');
      ok('jumlah seluruh halaman = total', true, 'dilewati: order <= 2');
    }

    // Urutan harus stabil antar halaman, kalau tidak ada baris yang terlewat
    // atau muncul dua kali saat data bertambah.
    const desc = await get('/api/orders?pageSize=100', { token: kasir });
    const times = (desc.json?.data?.items ?? []).map((o) => `${o.created_at}|${o.id}`);
    const sorted = [...times].sort().reverse();
    ok('urut created_at desc lalu id desc', JSON.stringify(times) === JSON.stringify(sorted),
      times.slice(0, 2).join(' '));

    const badPage = await get('/api/orders?page=0', { token: kasir });
    ok('page=0 ditolak 400', badPage.status === 400, `status ${badPage.status}`);

    const tooBig = await get('/api/orders?pageSize=101', { token: kasir });
    ok('pageSize=101 ditolak 400', tooBig.status === 400, `status ${tooBig.status}`);

    const notNumber = await get('/api/orders?page=abc', { token: kasir });
    ok('page bukan angka ditolak 400', notNumber.status === 400, `status ${notNumber.status}`);
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