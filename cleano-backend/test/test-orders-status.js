// Uji B6 status order & confirm-relay dalam transaksi lalu ROLLBACK.
require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');
const {
  attemptStatusChange, attemptConfirmRelay, TRANSITIONS, runTx,
} = require('../src/services/orderStatus');

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

// Ubah exception tak terduga menjadi asersi gagal agar ringkasan tes akurat.
async function tryTx(fn) {
  try {
    return { ok: true, value: await inTx(fn) };
  } catch (err) {
    return { ok: false, error: `${err.status || err.code || ''} ${err.message}`.trim(), raw: err };
  }
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
    const noToken = await call('/api/orders/3/status', { method: 'PATCH', body: { status: 'selesai' } });
    ok('tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    const asPelanggan = await call('/api/orders/3/status', {
      method: 'PATCH', body: { status: 'selesai' }, token: pelanggan,
    });
    ok('pelanggan PATCH status 403', asPelanggan.status === 403, `status ${asPelanggan.status}`);

    const relayPelanggan = await call('/api/orders/3/confirm-relay', {
      method: 'PATCH', body: { machine_id: 1 }, token: pelanggan,
    });
    ok('pelanggan PATCH confirm-relay 403', relayPelanggan.status === 403, `status ${relayPelanggan.status}`);

    const badId = await call('/api/orders/abc/status', {
      method: 'PATCH', body: { status: 'selesai' }, token: kasir,
    });
    ok(':id non-angka 400', badId.status === 400, `status ${badId.status}`);

    const badStatus = await call('/api/orders/3/status', {
      method: 'PATCH', body: { status: 'proses_cuci' }, token: kasir,
    });
    ok('status proses_cuci ditolak 400 lewat HTTP', badStatus.status === 400, `status ${badStatus.status}`);

    const unknownStatus = await call('/api/orders/3/status', {
      method: 'PATCH', body: { status: 'hilang' }, token: kasir,
    });
    ok('status tidak dikenal 400', unknownStatus.status === 400, `status ${unknownStatus.status}`);

    const missingOrder = await call('/api/orders/999999/status', {
      method: 'PATCH', body: { status: 'batal' }, token: kasir,
    });
    ok('order tidak ada 404', missingOrder.status === 404, `status ${missingOrder.status}`);

    const noMachine = await call('/api/orders/3/confirm-relay', {
      method: 'PATCH', body: {}, token: kasir,
    });
    ok('confirm-relay tanpa machine_id 400', noMachine.status === 400, `status ${noMachine.status}`);

    // Uji tabel transisi status: transisi sah diterima, sisanya ditolak.
    const ALL_STATUS = ['antre', 'proses_cuci', 'sedang_diproses', 'siap_diambil', 'selesai', 'batal'];
    const gagal = [];
    for (const from of ALL_STATUS) {
      for (const to of ['proses_cuci', 'siap_diambil', 'selesai', 'batal']) {
        const allowed = (TRANSITIONS[from] ?? []).includes(to);
        // Order karangan dengan status awal `from`, lalu dicoba pindah ke `to`.
        const r = await tryTx(async (conn) => {
          const [ins] = await conn.query(
            `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
               status, image_url)
             values (?, 2, 4, null, 1.00, 'tunai', ?, '/uploads/uji.png')`,
            [`CLN-19990101-${String(ALL_STATUS.indexOf(from)).padStart(2, '0')}${to[0]}`, from],
          );
          return attemptStatusChange(conn, { orderId: ins.insertId, status: to });
        });
        const actually = r.ok;
        if (actually !== allowed) gagal.push(`${from}->${to} harap ${allowed} dapat ${actually}`);
      }
    }
    ok('tabel transisi sesuai harapan', gagal.length === 0, gagal.slice(0, 3).join('; '));

    // ---- proses_cuci -> siap_diambil melepas mesin ----
    const release = await tryTx(async (conn) => {
      const [ins] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9901', 2, 1, 1, 3.00, 'tunai', 'proses_cuci', '/uploads/uji.png')`,
      );
      await conn.query("update machines set status = 'digunakan', estimated_finish_at = date_add(now(), interval 40 minute) where id = 1");
      const res = await attemptStatusChange(conn, { orderId: ins.insertId, status: 'siap_diambil' });
      const [[order]] = await conn.query('select status, machine_id from orders where id = ?', [ins.insertId]);
      const [[mesin]] = await conn.query('select status, estimated_finish_at from machines where id = 1');
      return { res, order, mesin };
    });
    ok('proses_cuci -> siap_diambil berhasil', release.ok && release.value.order.status === 'siap_diambil',
      release.ok ? release.value.order.status : release.error);
    ok('mesin dilepas jadi tersedia', release.ok && release.value.mesin.status === 'tersedia',
      release.ok ? release.value.mesin.status : release.error);
    ok('estimated_finish_at mesin dikosongkan', release.ok && release.value.mesin.estimated_finish_at === null,
      release.ok ? `${release.value.mesin.estimated_finish_at}` : release.error);
    ok('freed_machine_id dilaporkan', release.ok && release.value.res.freedMachineId === 1,
      release.ok ? `${release.value.res.freedMachineId}` : release.error);
    // Pertahankan machine_id pada order agar riwayat mesin tetap terbaca pelanggan.
    ok('machine_id order dipertahankan', release.ok && release.value.order.machine_id === 1,
      release.ok ? `${release.value.order.machine_id}` : release.error);

    // ---- selesai tidak boleh melepas mesin yang dipakai order lain ----
    const noSteal = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9902', 2, 1, 2, 3.00, 'tunai', 'siap_diambil', '/uploads/uji.png')`,
      );
      await conn.query("update machines set status = 'digunakan', estimated_finish_at = date_add(now(), interval 20 minute) where id = 2");
      const res = await attemptStatusChange(conn, { orderId: a.insertId, status: 'selesai' });
      const [[mesin]] = await conn.query('select status from machines where id = 2');
      const [[order]] = await conn.query('select status from orders where id = ?', [a.insertId]);
      return { res, mesin, order };
    });
    ok('siap_diambil -> selesai berhasil', noSteal.ok && noSteal.value.order.status === 'selesai',
      noSteal.ok ? noSteal.value.order.status : noSteal.error);
    // Pastikan order non-proses_cuci tidak membebaskan mesin milik order lain.
    ok('mesin milik order lain tidak dilepas', noSteal.ok && noSteal.value.mesin.status === 'digunakan',
      noSteal.ok ? noSteal.value.mesin.status : noSteal.error);
    ok('freed_machine_id null tanpa pelepasan', noSteal.ok && noSteal.value.res.freedMachineId === null,
      noSteal.ok ? `${noSteal.value.res.freedMachineId}` : noSteal.error);

    // ---- next_queue_order hanya dikirim saat ada antrean ----
    const withQueue = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9903', 2, 1, 1, 3.00, 'tunai', 'proses_cuci', '/uploads/uji.png')`,
      );
      // Antrean dengan created_at berbeda supaya FIFO bisa dibuktikan.
      const [lama] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url, created_at)
         values ('CLN-19990101-9904', 3, 1, null, 2.00, 'tunai', 'antre', '/uploads/uji.png',
                 date_sub(now(), interval 5 minute))`,
      );
      await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9905', 2, 1, null, 4.00, 'tunai', 'antre', '/uploads/uji.png')`,
      );
      const res = await attemptStatusChange(conn, { orderId: a.insertId, status: 'siap_diambil' });
      return { res, lamaId: lama.insertId };
    });
    ok('next_queue_order terisi saat ada antrean', withQueue.ok && Boolean(withQueue.value.res.nextQueueOrder),
      withQueue.ok ? `${withQueue.value.res.nextQueueOrder?.order_code}` : withQueue.error);
    ok('antrean terdepan = yang paling lama', withQueue.ok
      && withQueue.value.res.nextQueueOrder?.id === withQueue.value.lamaId,
      withQueue.ok ? `${withQueue.value.res.nextQueueOrder?.order_code} vs id ${withQueue.value.lamaId}` : withQueue.error);
    ok('next_queue_order membawa nama pelanggan', withQueue.ok
      && typeof withQueue.value.res.nextQueueOrder?.customer_name === 'string',
      withQueue.ok ? `${withQueue.value.res.nextQueueOrder?.customer_name}` : withQueue.error);

    // Pastikan antrean seri pada detik sama dipilih berdasarkan id terkecil.
    const tie = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9914', 2, 1, 1, 3.00, 'tunai', 'proses_cuci', '/uploads/uji.png')`,
      );
      await conn.query("update orders set status = 'batal' where status = 'antre'");
      const [kecil] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url, created_at)
         values ('CLN-19990101-9915', 3, 1, null, 2.00, 'tunai', 'antre', '/uploads/uji.png', '2026-01-01 08:00:00')`,
      );
      await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url, created_at)
         values ('CLN-19990101-9916', 2, 1, null, 4.00, 'tunai', 'antre', '/uploads/uji.png', '2026-01-01 08:00:00')`,
      );
      const res = await attemptStatusChange(conn, { orderId: a.insertId, status: 'siap_diambil' });
      return { res, kecilId: kecil.insertId };
    });
    ok('created_at seri -> id terkecil menang', tie.ok
      && tie.value.res.nextQueueOrder?.id === tie.value.kecilId,
      tie.ok ? `${tie.value.res.nextQueueOrder?.order_code} vs id ${tie.value.kecilId}` : tie.error);

    const noQueue = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9906', 2, 1, 1, 3.00, 'tunai', 'proses_cuci', '/uploads/uji.png')`,
      );
      // Semua order antre dipindahkan supaya antrean benar-benar kosong.
      await conn.query("update orders set status = 'batal' where status = 'antre'");
      const res = await attemptStatusChange(conn, { orderId: a.insertId, status: 'siap_diambil' });
      return res;
    });
    ok('next_queue_order null saat antrean kosong', noQueue.ok && noQueue.value.nextQueueOrder === null,
      noQueue.ok ? `${noQueue.value.nextQueueOrder}` : noQueue.error);

    // ---- confirm-relay ----
    const relay = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9907', 2, 1, null, 3.00, 'tunai', 'antre', '/uploads/uji.png')`,
      );
      const res = await attemptConfirmRelay(conn, { orderId: a.insertId, machineId: 2 });
      const [[order]] = await conn.query('select status, machine_id from orders where id = ?', [a.insertId]);
      const [[mesin]] = await conn.query('select status, estimated_finish_at from machines where id = 2');
      const [[svc]] = await conn.query('select wash_duration_minutes from services where id = 1');
      return { res, order, mesin, svc };
    });
    ok('confirm-relay mengubah status ke proses_cuci', relay.ok && relay.value.order.status === 'proses_cuci',
      relay.ok ? relay.value.order.status : relay.error);
    ok('confirm-relay mencatat machine_id', relay.ok && relay.value.order.machine_id === 2,
      relay.ok ? `${relay.value.order.machine_id}` : relay.error);
    ok('confirm-relay menandai mesin digunakan', relay.ok && relay.value.mesin.status === 'digunakan',
      relay.ok ? relay.value.mesin.status : relay.error);
    ok('confirm-relay mengisi estimated_finish_at', relay.ok && Boolean(relay.value.mesin.estimated_finish_at),
      relay.ok ? `${relay.value.mesin.estimated_finish_at}` : relay.error);

    // Jeda harus ± wash_duration_minutes layanan, bukan angka tetap.
    const menit = await tryTx(async (conn) => {
      const [[svc]] = await conn.query('select wash_duration_minutes from services where id = 1');
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9908', 2, 1, null, 3.00, 'tunai', 'antre', '/uploads/uji.png')`,
      );
      await attemptConfirmRelay(conn, { orderId: a.insertId, machineId: 3 });
      const [[d]] = await conn.query(
        'select timestampdiff(minute, now(), estimated_finish_at) as m from machines where id = 3',
      );
      return { m: Number(d.m), svc: Number(svc.wash_duration_minutes) };
    });
    ok('jeda mesin = wash_duration_minutes layanan', menit.ok && Math.abs(menit.value.m - menit.value.svc) <= 1,
      menit.ok ? `${menit.value.m} vs ${menit.value.svc}` : menit.error);

    // relay hanya untuk order antre
    const relayNotQueued = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9909', 2, 1, 1, 3.00, 'tunai', 'proses_cuci', '/uploads/uji.png')`,
      );
      try {
        await attemptConfirmRelay(conn, { orderId: a.insertId, machineId: 2 });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    ok('confirm-relay menolak order bukan antre', relayNotQueued.ok && relayNotQueued.value.status === 400,
      relayNotQueued.ok ? `${relayNotQueued.value.status} ${relayNotQueued.value.message}` : relayNotQueued.error);

    // mesin maintenance tidak boleh dipakai
    const relayMaintenance = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9910', 2, 1, null, 3.00, 'tunai', 'antre', '/uploads/uji.png')`,
      );
      const [[m]] = await conn.query("select id from machines where status = 'maintenance' limit 1");
      try {
        await attemptConfirmRelay(conn, { orderId: a.insertId, machineId: m.id });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    ok('confirm-relay menolak mesin maintenance', relayMaintenance.ok && relayMaintenance.value.status === 400,
      relayMaintenance.ok ? `${relayMaintenance.value.status} ${relayMaintenance.value.message}` : relayMaintenance.error);

    const relayMissingMachine = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9911', 2, 1, null, 3.00, 'tunai', 'antre', '/uploads/uji.png')`,
      );
      try {
        await attemptConfirmRelay(conn, { orderId: a.insertId, machineId: 999999 });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    ok('confirm-relay mesin tidak ada 404', relayMissingMachine.ok && relayMissingMachine.value.status === 404,
      relayMissingMachine.ok ? `${relayMissingMachine.value.status}` : relayMissingMachine.error);

    // Pastikan queue_wait_minutes seluruh order antre dihitung ulang saat mesin dilepas.
    const recalc = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, queue_wait_minutes, image_url)
         values ('CLN-19990101-9920', 2, 1, 1, 3.00, 'tunai', 'proses_cuci', 0, '/uploads/uji.png')`,
      );
      await conn.query("update machines set status = 'digunakan', estimated_finish_at = date_add(now(), interval 40 minute) where id = 1");
      // Angka lama yang sengaja salah, untuk membuktikan baris ini ditimpa.
      const [antre] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, queue_wait_minutes, image_url)
         values ('CLN-19990101-9921', 3, 1, null, 2.00, 'tunai', 'antre', 99, '/uploads/uji.png')`,
      );
      await attemptStatusChange(conn, { orderId: a.insertId, status: 'siap_diambil' });
      const [[sesudah]] = await conn.query('select queue_wait_minutes from orders where id = ?', [antre.insertId]);
      return { sebelum: 99, sesudah: Number(sesudah.queue_wait_minutes) };
    });
    ok('queue_wait dihitung ulang saat mesin dilepas',
      recalc.ok && recalc.value.sesudah !== 99,
      recalc.ok ? `${recalc.value.sebelum} -> ${recalc.value.sesudah}` : recalc.error);
    ok('antrean tanpa mesin terpakai jadi 0 menit', recalc.ok && recalc.value.sesudah === 0,
      recalc.ok ? `${recalc.value.sesudah}` : recalc.error);

    const recalcRelay = await tryTx(async (conn) => {
      const [antre] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, queue_wait_minutes, image_url)
         values ('CLN-19990101-9922', 2, 1, null, 3.00, 'tunai', 'antre', 0, '/uploads/uji.png')`,
      );
      const [sisa] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, queue_wait_minutes, image_url)
         values ('CLN-19990101-9923', 3, 1, null, 2.00, 'tunai', 'antre', 0, '/uploads/uji.png')`,
      );
      await attemptConfirmRelay(conn, { orderId: antre.insertId, machineId: 3 });
      const [[s]] = await conn.query('select queue_wait_minutes from orders where id = ?', [sisa.insertId]);
      return Number(s.queue_wait_minutes);
    });
    ok('confirm-relay memperbarui estimasi antrean sisa',
      recalcRelay.ok && recalcRelay.value > 0,
      recalcRelay.ok ? `${recalcRelay.value} menit` : recalcRelay.error);

    // Pastikan confirm-relay menolak layanan tanpa mesin (requires_machine = 0).
    const relayNoMachine = await tryTx(async (conn) => {
      const [[svc]] = await conn.query('select requires_machine from services where id = 4');
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9924', 2, 4, null, 1.00, 'tunai', 'antre', '/uploads/uji.png')`,
      );
      try {
        await attemptConfirmRelay(conn, { orderId: a.insertId, machineId: 1 });
        return { status: null, message: 'lolos', requiresMachine: svc.requires_machine };
      } catch (e) {
        return { status: e.status ?? null, message: e.message, requiresMachine: svc.requires_machine };
      }
    });
    ok('layanan uji memang requires_machine = 0',
      relayNoMachine.ok && relayNoMachine.value.requiresMachine === 0,
      relayNoMachine.ok ? `${relayNoMachine.value.requiresMachine}` : relayNoMachine.error);
    ok('confirm-relay menolak layanan tanpa mesin',
      relayNoMachine.ok && relayNoMachine.value.status === 400
      && /tidak memakai mesin/i.test(relayNoMachine.value.message ?? ''),
      relayNoMachine.ok ? `${relayNoMachine.value.status} ${relayNoMachine.value.message}` : relayNoMachine.error);

    // ---- poin diberikan trigger, bukan backend ----
    const poin = await tryTx(async (conn) => {
      const [[before]] = await conn.query('select points from users where id = 2');
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9912', 2, 1, null, 10.00, 'tunai', 'siap_diambil', '/uploads/uji.png')`,
      );
      await attemptStatusChange(conn, { orderId: a.insertId, status: 'selesai' });
      const [[after]] = await conn.query('select points from users where id = 2');
      const [[order]] = await conn.query('select points_awarded from orders where id = ?', [a.insertId]);
      return { before: Number(before.points), after: Number(after.points), awarded: order.points_awarded };
    });
    ok('selesai memicu poin lewat trigger', poin.ok && poin.value.after > poin.value.before,
      poin.ok ? `${poin.value.before} -> ${poin.value.after}` : poin.error);
    ok('points_awarded ditandai 1', poin.ok && poin.value.awarded === 1,
      poin.ok ? `${poin.value.awarded}` : poin.error);

    // ---- status final tidak bisa diubah ----
    const finalLocked = await tryTx(async (conn) => {
      const [a] = await conn.query(
        `insert into orders (order_code, user_id, service_id, machine_id, weight, payment_method,
           status, image_url)
         values ('CLN-19990101-9913', 2, 4, null, 1.00, 'tunai', 'batal', '/uploads/uji.png')`,
      );
      try {
        await attemptStatusChange(conn, { orderId: a.insertId, status: 'selesai' });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message };
      }
    });
    ok('order batal tidak bisa dihidupkan', finalLocked.ok && finalLocked.value.status === 400,
      finalLocked.ok ? `${finalLocked.value.status} ${finalLocked.value.message}` : finalLocked.error);

    // Pastikan peta TRANSITIONS mencakup seluruh nilai enum status order.
    ok('tabel transisi menutup semua status enum',
      ALL_STATUS.every((s) => s in TRANSITIONS), ALL_STATUS.filter((s) => !(s in TRANSITIONS)).join(','));
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