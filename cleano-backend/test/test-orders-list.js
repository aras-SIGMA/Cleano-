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

    // ---- grup status `aktif` (PRD-03 §4) ----
    // Dashboard kasir meminta GET /api/orders?status=aktif dalam satu permintaan.
    // 'aktif' bukan nilai enum di tabel: itu grup antre+proses_cuci+sedang_diproses+
    // siap_diambil. Tanpa pemetaan ini permintaannya dijawab 400 dan daftar ringkas
    // order aktif tidak bisa ditampilkan.
    const AKTIF = ['antre', 'proses_cuci', 'sedang_diproses', 'siap_diambil'];
    const aktif = await get('/api/orders?status=aktif', { token: kasir });
    ok('filter status=aktif 200', aktif.status === 200, `status ${aktif.status}`);
    ok('status=aktif hanya berisi order belum final',
      (aktif.json?.data?.items ?? []).every((o) => AKTIF.includes(o.status)),
      `${(aktif.json?.data?.items ?? []).map((o) => o.status).join(' ')}`);
    const [[jmlAktif]] = await pool.query(
      `select count(*) as n from orders where status in (${AKTIF.map(() => '?').join(',')})`,
      AKTIF,
    );
    ok('total status=aktif cocok DB', aktif.json?.data?.total === jmlAktif.n,
      `${aktif.json?.data?.total} vs ${jmlAktif.n}`);
    ok('status=aktif tidak memuat order selesai/batal',
      (aktif.json?.data?.items ?? []).every((o) => o.status !== 'selesai' && o.status !== 'batal'));

    // Grup tetap dibatasi kepemilikan: pelanggan tidak boleh melihat order aktif
    // milik pelanggan lain lewat satu filter.
    const aktifRina = await get('/api/orders?status=aktif', { token: tokRina });
    const [[jmlAktifRina]] = await pool.query(
      `select count(*) as n from orders where user_id = ? and status in (${AKTIF.map(() => '?').join(',')})`,
      [rina.id, ...AKTIF],
    );
    ok('status=aktif tetap dibatasi kepemilikan', aktifRina.json?.data?.total === jmlAktifRina.n,
      `${aktifRina.json?.data?.total} vs ${jmlAktifRina.n}`);

    const [[jmlSelesaiBatal]] = await pool.query("select count(*) as n from orders where status in ('selesai','batal')");
    ok('aktif + final = seluruh order',
      jmlAktif.n + jmlSelesaiBatal.n === totalAll.n,
      `${jmlAktif.n} + ${jmlSelesaiBatal.n} vs ${totalAll.n}`);

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

    // ---- pencarian ----
    // Dicocokkan terhadap DB, bukan terhadap tebakan: yang diuji adalah SQL
    // yang sama, jadi hitungannya harus identik dengan query acuan.
    const cariNama = await get('/api/orders?search=Rina', { token: kasir });
    const [[jmlCariNama]] = await pool.query(
      "select count(*) as n from orders o join users u on u.id = o.user_id where u.name like '%Rina%'",
    );
    ok('search nama mengembalikan 200', cariNama.status === 200, `status ${cariNama.status}`);
    ok('search nama cocok dengan hitungan DB', cariNama.json?.data?.total === jmlCariNama.n,
      `${cariNama.json?.data?.total} vs ${jmlCariNama.n}`);
    ok('search nama hanya berisi baris yang cocok',
      (cariNama.json?.data?.items ?? []).every((o) => o.customer_name.toLowerCase().includes('rina')));

    const cariKode = await get('/api/orders?search=CLN-20261114', { token: kasir });
    ok('search kode order menemukan satu baris',
      (cariKode.json?.data?.items ?? []).length === 1
      && cariKode.json.data.items[0].order_code === 'CLN-20261114-0001',
      `${(cariKode.json?.data?.items ?? []).map((o) => o.order_code).join(' ')}`);

    const cariHp = await get('/api/orders?search=081234567890', { token: kasir });
    ok('search nomor HP menemukan order rina',
      (cariHp.json?.data?.items ?? []).some((o) => o.customer_name === 'Rina Marlina'),
      `${(cariHp.json?.data?.items ?? []).map((o) => o.customer_name).join(' ')}`);

    // '%' dan '_' dari pengguna harus jadi karakter biasa, bukan wildcard.
    // Tanpa escape, search=% akan mengembalikan seluruh order.
    const cariWildcard = await get('/api/orders?search=%25', { token: kasir });
    ok('wildcard % di-escape (bukan cocok semua)', cariWildcard.json?.data?.total === 0,
      `${cariWildcard.json?.data?.total} vs 0`);

    // Pencarian tetap dibatasi kepemilikan seperti filter lain.
    const cariRinaBudi = await get('/api/orders?search=Budi', { token: tokRina });
    ok('search tidak membocorkan order pelanggan lain', cariRinaBudi.json?.data?.total === 0,
      `${cariRinaBudi.json?.data?.total} vs 0`);

    const cariTerlaluPanjang = await get('/api/orders?search=' + 'a'.repeat(101), { token: kasir });
    ok('search > 100 karakter ditolak 400', cariTerlaluPanjang.status === 400,
      `status ${cariTerlaluPanjang.status}`);

    // Gabungan filter dan pencarian harus menyempit, bukan saling menimpa.
    const gabung = await get('/api/orders?status=selesai&search=CLN-20261114', { token: kasir });
    ok('search digabung status mempersempit hasil',
      (gabung.json?.data?.items ?? []).length === 1
      && gabung.json.data.items[0].order_code === 'CLN-20261114-0001',
      `${(gabung.json?.data?.items ?? []).map((o) => o.order_code).join(' ')}`);
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