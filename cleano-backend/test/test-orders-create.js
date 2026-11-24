// Uji POST /api/orders terhadap Aiven.
// Jalur sukses dijalankan lewat attemptOrder() di dalam transaksi lalu ROLLBACK:
// order tidak boleh dihapus (trigger L-07), jadi rollback satu-satunya cara
// membersihkan. Jalur gagal diuji lewat HTTP karena yang diperiksa justru
// status code-nya.
// Jalankan: npm run test:orders-create
require('dotenv').config({ quiet: true });

const fs = require('fs');
const { pool } = require('../src/config/database');
const app = require('../server');
const { attemptOrder } = require('../src/controllers/orderController');
const { allocateMachine } = require('../src/services/orderAllocation');

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

// PNG 1x1 asli supaya lolos fileFilter tanpa perlu berkas di disk.
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
  'base64',
);

// body: objek biasa; image: Buffer | null (null = tanpa file)
async function post(fields, { token, image = PNG, filename = 'bukti.png', type = 'image/png' } = {}) {
  const form = new FormData();
  for (const [k, v] of Object.entries(fields)) {
    if (v !== undefined && v !== null) form.append(k, String(v));
  }
  if (image !== null) form.append('image', new Blob([image], { type }), filename);
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}/api/orders`, { method: 'POST', headers, body: form });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

// Jalankan attemptOrder di dalam transaksi, ambil hasilnya, lalu selalu rollback.
async function inTx(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    return result;
  } finally {
    await conn.rollback().catch(() => {});
    conn.release();
  }
}

// Sama seperti inTx tetapi kegagalan dilempar berubah menjadi objek gagal, supaya
// error tak terduga muncul sebagai satu asersi GAGAL, bukan menghentikan skrip
// dengan ringkasan "N/N lulus" yang menyesatkan.
async function tryTx(fn) {
  try {
    return { ok: true, value: await inTx(fn) };
  } catch (err) {
    return { ok: false, error: `${err.code || err.status || ''} ${err.message}`.trim() };
  }
}

const orderBody = (over = {}) => ({
  user_id: 2, // rina, 150 poin -> Gold
  service_id: 1, // butuh mesin
  weight: 3.5,
  payment_method: 'tunai',
  notes: 'uji otomatis',
  ...over,
});

(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    const kasir = await login('kasir@cleano.id', 'password123');
    const pelanggan = await login('rina@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasir));
    ok('login pelanggan untuk uji', Boolean(pelanggan));

    const [[countStart]] = await pool.query('select count(*) as n from orders');
    const ORDERS_AWAL = countStart.n;

    // ---- otorisasi & validasi lewat HTTP (tidak ada baris yang tersimpan) ----
    const noToken = await post(orderBody(), { token: null });
    ok('tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    const asPelanggan = await post(orderBody(), { token: pelanggan });
    ok('pelanggan POST orders 403', asPelanggan.status === 403, `status ${asPelanggan.status}`);

    const noImage = await post(orderBody(), { token: kasir, image: null });
    ok('tanpa foto 400', noImage.status === 400, `status ${noImage.status} ${noImage.json?.message ?? ''}`);

    const wrongType = await post(orderBody(), {
      token: kasir, image: Buffer.from('bukan gambar'), filename: 'x.txt', type: 'text/plain',
    });
    ok('format foto salah 400', wrongType.status === 400, `status ${wrongType.status}`);

    const tooBig = await post(orderBody(), {
      token: kasir, image: Buffer.alloc(2.5 * 1024 * 1024, 1), filename: 'besar.png',
    });
    ok('foto > 2 MB 400', tooBig.status === 400, `status ${tooBig.status}`);

    const weightZero = await post(orderBody({ weight: 0 }), { token: kasir });
    ok('weight 0 ditolak 400', weightZero.status === 400, `status ${weightZero.status}`);

    const weightMissing = await post(orderBody({ weight: undefined }), { token: kasir });
    ok('weight kosong ditolak 400', weightMissing.status === 400, `status ${weightMissing.status}`);

    // Batas panjang masukan: tanpa ini satu permintaan bisa membawa teks
    // sepanjang apa pun dan server menyangganya sebelum validator menolak.
    const weightHuge = await post(orderBody({ weight: '100' }), { token: kasir });
    ok('weight > 99.99 ditolak 400', weightHuge.status === 400, `status ${weightHuge.status}`);

    const voucherLong = await post(orderBody({ voucher_code: 'A'.repeat(31) }), { token: kasir });
    ok('voucher_code 31 karakter 400', voucherLong.status === 400, `status ${voucherLong.status}`);

    const notesLong = await post(orderBody({ notes: 'x'.repeat(2001) }), { token: kasir });
    ok('notes 2001 karakter 400', notesLong.status === 400, `status ${notesLong.status}`);

    // Melewati fieldSize multer (8 KB): ditolak di lapisan multipart sebelum
    // zod sempat membaca. Pesannya membedakan kedua lapisan; tanpa fieldSize
    // yang ketat, pesan yang keluar justru milik zod.
    const fieldHuge = await post(orderBody({ notes: 'x'.repeat(9000) }), { token: kasir });
    ok('field > 8 KB ditolak multer, bukan zod',
      fieldHuge.status === 400 && /terlalu panjang/.test(fieldHuge.json?.message ?? ''),
      `status ${fieldHuge.status} ${fieldHuge.json?.message ?? ''}`);

    const badPay = await post(orderBody({ payment_method: 'kartu' }), { token: kasir });
    ok('payment_method asing ditolak 400', badPay.status === 400, `status ${badPay.status}`);

    const noService = await post(orderBody({ service_id: 999999 }), { token: kasir });
    ok('service_id tidak ada 404', noService.status === 404, `status ${noService.status}`);

    const noUser = await post(orderBody({ user_id: 999999 }), { token: kasir });
    ok('user_id tidak ada 404', noUser.status === 404, `status ${noUser.status}`);

    // Penjaga kebersihan: semua request di atas harus gagal, jadi jumlah order
    // harus tetap sama dengan seeder. Kalau ada yang lolos 201, barisnya sudah
    // commit dan tidak bisa dihapus (trigger L-07) — tertangkap di sini.
    const [[countAfterRejects]] = await pool.query('select count(*) as n from orders');
    ok('tidak ada order tertinggal dari request yang ditolak', countAfterRejects.n === ORDERS_AWAL,
      `${countAfterRejects.n} vs ${ORDERS_AWAL}`);

    // ---- jalur sukses: mesin tersedia ----
    // Mesin seeder bisa saja sudah dipegang order nyata dan order tidak boleh
    // dihapus (L-07), jadi uji menyiapkan mesinnya sendiri.
    await pool.query("delete from machines where machine_code like 'MC-UJI-%'");
    await pool.query(
      "insert into machines (machine_code, status, capacity_kg) values ('MC-UJI-SUKSES', 'tersedia', 7.00)",
    );
    const allocTx = await tryTx(async (conn) => {
      const row = await attemptOrder(conn, { body: orderBody(), imageUrl: '/uploads/uji.png' });
      const [[mesin]] = await conn.query('select status, estimated_finish_at from machines where id = ?', [row.machine_id]);
      const [[svc]] = await conn.query('select price_per_kg from services where id = 1');
      const [[order]] = await conn.query('select payment_status, paid_at, customer_tier_snapshot from orders where id = ?', [row.id]);
      return { row, mesin, svc, order };
    });
    await pool.query("delete from machines where machine_code like 'MC-UJI-%'");
    ok('order berhasil dibuat', allocTx.ok && allocTx.value.row.id > 0,
      allocTx.ok ? `id ${allocTx.value.row.id}` : allocTx.error);
    if (allocTx.ok) {
      const alloc = allocTx.value;
      ok('status proses_cuci saat mesin tersedia', alloc.row.status === 'proses_cuci', `${alloc.row.status}`);
      ok('machine_id terisi', Boolean(alloc.row.machine_id), `${alloc.row.machine_id}`);
      ok('machine_code ikut di respons', Boolean(alloc.row.machine_code), `${alloc.row.machine_code}`);
      ok('mesin jadi digunakan', alloc.mesin.status === 'digunakan', `${alloc.mesin.status}`);
      ok('estimated_finish_at mesin terisi', Boolean(alloc.mesin.estimated_finish_at), `${alloc.mesin.estimated_finish_at}`);
      ok('queue_wait_minutes 0 saat dapat mesin', alloc.row.queue_wait_minutes === 0, `${alloc.row.queue_wait_minutes}`);
      ok('order_code pola CLN-YYYYMMDD-XXXX', /^CLN-\d{8}-\d{4}$/.test(alloc.row.order_code), alloc.row.order_code);
      ok('subtotal = round(berat x harga/kg)',
        alloc.row.subtotal_price === Math.round(3.5 * alloc.svc.price_per_kg),
        `${alloc.row.subtotal_price} vs ${3.5 * alloc.svc.price_per_kg}`);
      ok('tanpa voucher diskon 0', alloc.row.discount_amount === 0, `${alloc.row.discount_amount}`);
      ok('total = subtotal', alloc.row.total_price === alloc.row.subtotal_price, `${alloc.row.total_price}`);
      ok('tunai langsung lunas', alloc.order.payment_status === 'lunas', `${alloc.order.payment_status}`);
      ok('tunai paid_at terisi', Boolean(alloc.order.paid_at), `${alloc.order.paid_at}`);
      ok('tier snapshot Gold (150 poin)', alloc.order.customer_tier_snapshot === 'Gold', `${alloc.order.customer_tier_snapshot}`);
      ok('snap_token tidak ikut terkirim', alloc.row.snap_token === undefined);
    }

    // ---- layanan tanpa mesin ----
    const nomesinTx = await tryTx(async (conn) => attemptOrder(conn, {
      body: orderBody({ service_id: 4, weight: 2 }), imageUrl: '/uploads/uji.png',
    }));
    ok('requires_machine=0 -> sedang_diproses', nomesinTx.ok && nomesinTx.value.status === 'sedang_diproses',
      nomesinTx.ok ? nomesinTx.value.status : nomesinTx.error);
    ok('requires_machine=0 -> machine_id null', nomesinTx.ok && nomesinTx.value.machine_id === null,
      nomesinTx.ok ? `${nomesinTx.value.machine_id}` : nomesinTx.error);
    ok('requires_machine=0 -> queue 0', nomesinTx.ok && nomesinTx.value.queue_wait_minutes === 0,
      nomesinTx.ok ? `${nomesinTx.value.queue_wait_minutes}` : nomesinTx.error);

    // ---- semua mesin terpakai -> antre ----
    const antreTx = await tryTx(async (conn) => {
      await conn.query("update machines set status = 'digunakan', estimated_finish_at = date_add(now(), interval 30 minute)");
      return attemptOrder(conn, { body: orderBody(), imageUrl: '/uploads/uji.png' });
    });
    ok('mesin penuh -> status antre', antreTx.ok && antreTx.value.status === 'antre',
      antreTx.ok ? antreTx.value.status : antreTx.error);
    ok('mesin penuh -> machine_id null', antreTx.ok && antreTx.value.machine_id === null,
      antreTx.ok ? `${antreTx.value.machine_id}` : antreTx.error);
    ok('mesin penuh -> queue_wait_minutes ~30',
      antreTx.ok && antreTx.value.queue_wait_minutes >= 28 && antreTx.value.queue_wait_minutes <= 30,
      antreTx.ok ? `${antreTx.value.queue_wait_minutes}` : antreTx.error);

    // ---- voucher ----
    const vcr = await inTx(async (conn) => {
      const [vrows] = await conn.query(
        'select voucher_code, id from user_vouchers where user_id = 2 and is_used = 0 limit 1',
      );
      const v = vrows[0];
      if (!v) return null;
      const r = await attemptOrder(conn, {
        body: orderBody({ voucher_code: v.voucher_code }), imageUrl: '/uploads/uji.png',
      });
      const [[after]] = await conn.query('select is_used, used_at from user_vouchers where id = ?', [v.id]);
      const [[reward]] = await conn.query(
        'select r.discount_amount from user_vouchers uv join rewards r on uv.reward_id = r.id where uv.id = ?', [v.id],
      );
      // Pemakaian kedua kode yang sama: trigger setelah insert sudah menandai
      // is_used = 1 di dalam transaksi ini, jadi penjaga backend harus menolak
      // sebelum INSERT berikutnya. Yang diperiksa bukan hanya pesannya (trigger
      // juga menolak dengan pesan serupa) melainkan statusnya: 400 dari
      // penjaga backend, bukan ER_SIGNAL_EXCEPTION yang jadi 500.
      let second = { status: null, message: 'lolos' };
      try {
        await attemptOrder(conn, { body: orderBody({ voucher_code: v.voucher_code }), imageUrl: '/uploads/uji.png' });
      } catch (e) {
        second = { status: e.status ?? null, message: e.message };
      }
      return { r, after, reward, second };
    });
    ok('ada voucher seeder milik rina', Boolean(vcr));
    if (vcr) {
      ok('diskon voucher dipakai', vcr.r.discount_amount === vcr.reward.discount_amount,
        `${vcr.r.discount_amount} vs ${vcr.reward.discount_amount}`);
      ok('total = subtotal - diskon', vcr.r.total_price === vcr.r.subtotal_price - vcr.r.discount_amount,
        `${vcr.r.total_price}`);
      ok('voucher_id tercatat di order', Boolean(vcr.r.voucher_id), `${vcr.r.voucher_id}`);
      ok('voucher ditandai terpakai dalam transaksi', vcr.after.is_used === 1, `${vcr.after.is_used}`);
      ok('used_at voucher terisi', Boolean(vcr.after.used_at), `${vcr.after.used_at}`);
      ok('voucher sekali pakai ditolak 400 oleh backend',
        vcr.second.status === 400 && /sudah pernah digunakan/i.test(vcr.second.message),
        `${vcr.second.status} ${vcr.second.message}`);
    }

    const vcrOrangLain = await inTx(async (conn) => {
      const [vrows] = await conn.query('select voucher_code from user_vouchers where user_id = 2 and is_used = 0 limit 1');
      if (!vrows[0]) return { status: null, message: 'tidak ada voucher uji' };
      try {
        await attemptOrder(conn, {
          body: orderBody({ user_id: 3, voucher_code: vrows[0].voucher_code }), imageUrl: '/uploads/uji.png',
        });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    // 400 dari penjaga backend. Trigger memakai pesan yang sama tapi keluar
    // sebagai ER_SIGNAL_EXCEPTION tanpa status, jadi 500.
    ok('voucher milik orang lain ditolak 400 oleh backend',
      vcrOrangLain.status === 400 && /tidak valid untuk akun/i.test(vcrOrangLain.message),
      `${vcrOrangLain.status} ${vcrOrangLain.message}`);

    const vcrAsing = await inTx(async (conn) => {
      try {
        await attemptOrder(conn, { body: orderBody({ voucher_code: 'CLN-VCR-ZZZZ' }), imageUrl: '/uploads/uji.png' });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    // 404 berarti backend yang mencari dan tidak menemukan, bukan trigger.
    ok('kode voucher asing ditolak 404 oleh backend',
      vcrAsing.status === 404 && /tidak ditemukan/i.test(vcrAsing.message),
      `${vcrAsing.status} ${vcrAsing.message}`);

    // ---- trigger pemilik harga, bukan backend ----
    const ownershipTx = await tryTx(async (conn) => {
      const [ins] = await conn.query(
        `insert into orders
           (order_code, user_id, service_id, machine_id, weight, subtotal_price, discount_amount,
            total_price, payment_method, status, image_url)
         values (?, 2, 1, null, 2.00, 1, 0, 1, 'tunai', 'antre', '/uploads/uji.png')`,
        ['CLN-19990101-9999'],
      );
      const [[after]] = await conn.query('select subtotal_price, total_price from orders where id = ?', [ins.insertId]);
      return after;
    });
    ok('trigger menimpa subtotal_price kiriman klien',
      ownershipTx.ok && ownershipTx.value.subtotal_price > 1,
      ownershipTx.ok ? `${ownershipTx.value.subtotal_price}` : ownershipTx.error);
    ok('trigger menimpa total_price kiriman klien',
      ownershipTx.ok && ownershipTx.value.total_price > 1,
      ownershipTx.ok ? `${ownershipTx.value.total_price}` : ownershipTx.error);

    // ---- tie: dua order berurutan mendapat kode berbeda ----
    const codes = await tryTx(async (conn) => {
      const a = await attemptOrder(conn, { body: orderBody(), imageUrl: '/uploads/uji.png' });
      const b = await attemptOrder(conn, { body: orderBody(), imageUrl: '/uploads/uji.png' });
      return [a.order_code, b.order_code];
    });
    // Nomor diambil dari MAX per tanggal, jadi dua order pada transaksi sama
    // harus naik satu. Kalau nomornya konstan, indeks unik order_code menolak
    // INSERT kedua dan pesannya muncul di sini sebagai asersi merah.
    ok('dua order berurutan beda order_code',
      codes.ok && codes.value[0] !== codes.value[1],
      codes.ok ? codes.value.join(' / ') : codes.error);

    // ---- midtrans: respons wajib membawa snap_redirect_url ----
    const midTx = await tryTx(async (conn) => attemptOrder(conn, {
      body: orderBody({ payment_method: 'midtrans' }), imageUrl: '/uploads/uji.png',
    }));
    ok('midtrans -> payment_status belum_bayar', midTx.ok && midTx.value.payment_status === 'belum_bayar',
      midTx.ok ? midTx.value.payment_status : midTx.error);
    ok('midtrans -> paid_at null', midTx.ok && midTx.value.paid_at === null,
      midTx.ok ? `${midTx.value.paid_at}` : midTx.error);
    ok('midtrans -> snap_redirect_url ada', midTx.ok && /^https?:\/\//.test(String(midTx.value.snap_redirect_url)),
      midTx.ok ? `${midTx.value.snap_redirect_url}` : midTx.error);

    // Catatan: klausa `for update` pada SELECT voucher tidak diuji balapan di sini.
    // Membuktikannya butuh satu transaksi yang COMMIT, dan order yang sudah commit
    // tidak bisa dihapus (trigger L-07) — uji akan meninggalkan baris permanen dan
    // membakar voucher seeder. Penjaga nyata untuk jalur ini adalah indeks unik
    // uq_orders_voucher plus trigger AFTER INSERT, dan keduanya sudah terbukti di
    // tes pemakaian-ganda di atas.

    // ---- penguncian mesin: dua transaksi tidak boleh mendapat mesin yang sama ----
    // Yang diuji bukan "terblokir" (UPDATE juga mengunci baris) melainkan hasil
    // setelah blokir selesai: FOR UPDATE membuat transaksi kedua membaca ulang
    // versi terbaru dan tidak menemukan mesin bebas. Tanpa FOR UPDATE, SELECT
    // memakai snapshot lama ('tersedia'), lalu UPDATE-nya berhasil setelah
    // transaksi pertama commit — dua order berbagi satu drum.
    const lockTx = await tryTx(async () => {
      // Sisakan tepat satu mesin 'tersedia'. Tanpa ini transaksi kedua wajar
      // mendapat mesin lain dan uji tidak membedakan apa pun.
      //
      // Mesin seeder tidak bisa dipakai sebagai "yang satu itu": ia bisa sedang
      // dipegang order nyata berstatus proses_cuci, dan order tidak boleh
      // dihapus (trigger L-07), jadi tidak ada cara membebaskannya dari uji.
      // Karena itu mesin seeder diparkir semua lalu ditambah satu mesin uji.
      // Sisa dari jalannya uji sebelumnya dibersihkan lebih dulu berdasarkan
      // awalan, bukan id, supaya jalan ulang tidak bertabrakan.
      await pool.query("delete from machines where machine_code like 'MC-UJI-%'");
      const [parked] = await pool.query(
        "select id from machines where status = 'tersedia' for update",
      );
      const parkedIds = parked.map((r) => r.id);
      if (parkedIds.length) {
        await pool.query(
          "update machines set status = 'maintenance', estimated_finish_at = null where id in (?)",
          [parkedIds],
        );
      }
      const [ins] = await pool.query(
        "insert into machines (machine_code, status, capacity_kg) values ('MC-UJI-KUNCI', 'tersedia', 7.00)",
      );
      const testMachineId = ins.insertId;
      const a = await pool.getConnection();
      const b = await pool.getConnection();
      let firstId = null;
      let secondId = null;
      let blocked = null;
      try {
        await a.beginTransaction();
        firstId = await allocateMachine(a, 30);

        await b.beginTransaction();
        const pending = allocateMachine(b, 30);

        // Beri B waktu masuk antrean kunci, lalu A commit supaya B lanjut.
        await new Promise((resolve) => setTimeout(resolve, 500));
        await a.commit();

        try {
          secondId = await pending;
        } catch (e) {
          blocked = e.code || e.message;
        }
        await b.rollback();
      } finally {
        await a.rollback().catch(() => {});
        await b.rollback().catch(() => {});
        a.release();
        b.release();
        await pool.query('delete from machines where id = ?', [testMachineId]).catch(() => {});
        if (parkedIds.length) {
          await pool.query(
            "update machines set status = 'tersedia' where id in (?)",
            [parkedIds],
          ).catch(() => {});
        }
      }
      return { firstId, secondId, blocked, testMachineId };
    });
    ok('transaksi pertama mendapat mesin', lockTx.ok && lockTx.value.firstId > 0,
      lockTx.ok ? `id ${lockTx.value.firstId}` : lockTx.error);
    ok('transaksi kedua TIDAK mendapat mesin yang sama',
      lockTx.ok && lockTx.value.secondId === null && lockTx.value.blocked === null,
      lockTx.ok ? `id ${lockTx.value.secondId} ${lockTx.value.blocked ?? ''}`.trim() : lockTx.error);
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