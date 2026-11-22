// Uji B8: GET /api/dashboard/summary. Seluruhnya baca saja — tidak ada baris
// yang perlu dibersihkan.
// Jalankan: npm run test:dashboard
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
    const kasir = await login('kasir@cleano.id', 'password123');
    const pelanggan = await login('rina@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasir));
    ok('login pelanggan untuk uji', Boolean(pelanggan));

    // ---- otorisasi ----
    const noToken = await get('/api/dashboard/summary');
    ok('tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    const asPelanggan = await get('/api/dashboard/summary', { token: pelanggan });
    ok('pelanggan 403', asPelanggan.status === 403, `status ${asPelanggan.status}`);

    // ---- bentuk respons ----
    const res = await get('/api/dashboard/summary', { token: kasir });
    ok('kasir 200', res.status === 200, `status ${res.status}`);
    const d = res.json?.data ?? {};
    const kartu = ['today_revenue', 'active_orders', 'ready_orders',
      'available_machines', 'total_operational_machines'];
    const hilang = kartu.filter((k) => !(k in d));
    ok('lima kartu dashboard ada', hilang.length === 0, `hilang: ${hilang.join(',')}`);
    ok('revenue_7_days berupa array', Array.isArray(d.revenue_7_days),
      `${typeof d.revenue_7_days}`);

    // ---- kartu cocok dengan view ----
    const [[v]] = await pool.query('select * from vw_dashboard_summary');
    for (const k of kartu) {
      // SUM/COUNT kembali sebagai string desimal; respons sudah jadi angka.
      ok(`kartu ${k} cocok view`, Number(d[k]) === Number(v[k]),
        `${d[k]} vs ${v[k]}`);
    }

    // ---- 7 tanggal selalu lengkap, urut, dan tidak dobel ----
    const tren = d.revenue_7_days ?? [];
    ok('tepat 7 hari', tren.length === 7, `${tren.length}`);
    const tanggal = tren.map((r) => r.order_date);
    ok('tanggal unik', new Set(tanggal).size === tanggal.length, tanggal.join(' '));
    ok('tanggal urut naik', JSON.stringify(tanggal) === JSON.stringify([...tanggal].sort()),
      tanggal.join(' '));
    ok('format tanggal YYYY-MM-DD', tanggal.every((t) => /^\d{4}-\d{2}-\d{2}$/.test(t)),
      tanggal.join(' '));

    // Hari terakhir harus hari ini menurut MySQL (+07:00), bukan menurut jam mesin
    // penguji. Kalau backend menyusun tanggal sendiri, keduanya bisa berbeda.
    const [[{ hari_ini }]] = await pool.query("select date_format(curdate(), '%Y-%m-%d') as hari_ini");
    ok('hari terakhir = curdate() MySQL', tanggal[6] === hari_ini,
      `${tanggal[6]} vs ${hari_ini}`);

    // Rentang harus bersambung 7 hari tanpa bolong.
    const [[{ span }]] = await pool.query(
      'select datediff(?, ?) as span', [tanggal[6], tanggal[0]],
    );
    ok('rentang bersambung 6 hari', Number(span) === 6, `${span}`);

    // ---- hari tanpa transaksi tetap muncul dengan nol ----
    const [adaDiView] = await pool.query('select order_date from vw_daily_revenue_7days');
    const setView = new Set(adaDiView.map((r) => r.order_date));
    const kosong = tren.filter((r) => !setView.has(r.order_date));
    ok('hari tanpa transaksi terisi nol', kosong.every((r) => r.daily_revenue === 0
      && r.total_transactions === 0 && r.total_weight_kg === 0),
    kosong.map((r) => `${r.order_date}=${r.daily_revenue}`).join(' '));

    // ---- nilai hari yang ada transaksi cocok view ----
    const [vTren] = await pool.query('select * from vw_daily_revenue_7days');
    const peta = new Map(vTren.map((r) => [r.order_date, r]));
    const beda = tren.filter((r) => {
      const v2 = peta.get(r.order_date);
      if (!v2) return false;
      return Number(r.daily_revenue) !== Number(v2.daily_revenue)
        || Number(r.total_transactions) !== Number(v2.total_transactions)
        || Number(r.total_weight_kg) !== Number(v2.total_weight_kg);
    });
    ok('nilai per hari cocok view', beda.length === 0,
      beda.map((r) => r.order_date).join(' '));

    // ---- angka, bukan string desimal ----
    ok('daily_revenue berupa angka', tren.every((r) => typeof r.daily_revenue === 'number'),
      typeof tren[0]?.daily_revenue);
    ok('today_revenue berupa angka', typeof d.today_revenue === 'number', typeof d.today_revenue);
    ok('total_weight_kg berupa angka', tren.every((r) => typeof r.total_weight_kg === 'number'),
      typeof tren[0]?.total_weight_kg);

    // ---- order batal tidak dihitung ----
    // Seeder tidak punya order batal, jadi yang diuji: hari ini omzetnya sama
    // dengan jumlah total_price order lunas hari ini yang bukan batal.
    const [[hitung]] = await pool.query(
      `select coalesce(sum(total_price), 0) as n from orders
        where payment_status = 'lunas' and status != 'batal' and date(paid_at) = curdate()`,
    );
    ok('today_revenue = jumlah order lunas hari ini', d.today_revenue === Number(hitung.n),
      `${d.today_revenue} vs ${hitung.n}`);

    // ---- kapasitas mesin ----
    const [[m]] = await pool.query(
      `select sum(status = 'tersedia') as tersedia,
              sum(status != 'maintenance') as operasional from machines`,
    );
    ok('available_machines cocok', d.available_machines === Number(m.tersedia),
      `${d.available_machines} vs ${m.tersedia}`);
    ok('total_operational_machines cocok', d.total_operational_machines === Number(m.operasional),
      `${d.total_operational_machines} vs ${m.operasional}`);
    ok('available <= total_operational',
      d.available_machines <= d.total_operational_machines,
      `${d.available_machines}/${d.total_operational_machines}`);
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
