'use strict';

const { pool } = require('../config/database');
const { badRequest, notFound } = require('../utils/response');

// Peta transisi status sah; 'proses_cuci' hanya lewat confirm-relay, final ditolak.
const TRANSITIONS = {
  antre: ['batal'],
  proses_cuci: ['siap_diambil', 'batal'],
  sedang_diproses: ['siap_diambil', 'batal'],
  siap_diambil: ['selesai', 'batal'],
  selesai: [],
  batal: [],
};

// Kunci order lalu mesin secara konsisten untuk mencegah deadlock paralel.
async function lockOrder(conn, orderId) {
  const [[order]] = await conn.query(
    `select id, order_code, service_id, machine_id, status
       from orders where id = ? for update`,
    [orderId],
  );
  if (!order) throw notFound('Order tidak ditemukan.');
  return order;
}

async function releaseMachine(conn, machineId) {
  await conn.query(
    "update machines set status = 'tersedia', estimated_finish_at = null where id = ?",
    [machineId],
  );
}

// Urutkan antrean FIFO berdasarkan created_at lalu id sebagai pemutus seri.
async function nextQueuedOrder(conn) {
  const [[row]] = await conn.query(
    `select o.id, o.order_code, o.weight, u.name as customer_name, s.name as service_name
       from orders o
       join users u on o.user_id = u.id
       join services s on o.service_id = s.id
      where o.status = 'antre'
      order by o.created_at asc, o.id asc
      limit 1`,
  );
  return row ?? null;
}

// Hitung ulang queue_wait_minutes seluruh order 'antre' setiap kali mesin dilepas.
async function refreshQueueWaits(conn) {
  await conn.query(
    `update orders
        set queue_wait_minutes = (
          select greatest(0, coalesce(
            timestampdiff(minute, now(),
              (select min(estimated_finish_at) from machines
                where status = 'digunakan' and estimated_finish_at is not null)),
            0))
        )
      where status = 'antre'`,
  );
}

// Satu perubahan status, di atas koneksi yang sudah membuka transaksi.
async function attemptStatusChange(conn, { orderId, status }) {
  const order = await lockOrder(conn, orderId);
  const allowed = TRANSITIONS[order.status] ?? [];
  if (!allowed.includes(status)) {
    throw badRequest(allowed.length === 0
      ? `Order berstatus "${order.status}" sudah final dan tidak bisa diubah lagi.`
      : `Status "${order.status}" tidak bisa menjadi "${status}". Yang sah: ${allowed.join(', ')}.`);
  }

  await conn.query('update orders set status = ? where id = ?', [status, orderId]);

  // Lepas mesin hanya jika order ini masih memegangnya.
  const holdsMachine = order.status === 'proses_cuci' && Boolean(order.machine_id);
  if (holdsMachine) {
    await releaseMachine(conn, order.machine_id);
    // Perbarui estimasi tunggu seluruh order 'antre' saat mesin baru saja kosong.
    await refreshQueueWaits(conn);
  }

  return {
    orderId,
    freedMachineId: holdsMachine ? order.machine_id : null,
    nextQueueOrder: holdsMachine ? await nextQueuedOrder(conn) : null,
  };
}

// Pasangkan order antre ke mesin yang benar-benar sedang bebas.
async function attemptConfirmRelay(conn, { orderId, machineId }) {
  const order = await lockOrder(conn, orderId);
  if (order.status !== 'antre') {
    throw badRequest(`Hanya order berstatus "antre" yang bisa dikonfirmasi ke mesin. Order ini berstatus "${order.status}".`);
  }

  const [[machine]] = await conn.query(
    'select id, machine_code, status from machines where id = ? for update',
    [machineId],
  );
  if (!machine) throw notFound('Mesin tidak ditemukan.');
  if (machine.status !== 'tersedia') {
    throw badRequest(`Mesin ${machine.machine_code} sedang ${machine.status} sehingga tidak bisa dipakai.`);
  }

  const [[service]] = await conn.query(
    'select wash_duration_minutes, requires_machine from services where id = ?', [order.service_id],
  );
  // Tolak confirm-relay untuk layanan tanpa mesin agar tidak mengunci drum.
  if (!service?.requires_machine) {
    throw badRequest('Layanan order ini tidak memakai mesin, jadi tidak bisa dikonfirmasi ke mesin.');
  }
  const minutes = Number(service?.wash_duration_minutes) || 0;

  await conn.query(
    "update machines set status = 'digunakan', estimated_finish_at = date_add(now(), interval ? minute) where id = ?",
    [minutes, machineId],
  );
  // Perbarui machine_id karena estafet memindahkan order antar unit mesin.
  await conn.query("update orders set status = 'proses_cuci', machine_id = ? where id = ?", [machineId, orderId]);
  // Mesin ini sekarang terpakai, jadi estimasi antrean yang tersisa ikut berubah.
  await refreshQueueWaits(conn);

  return { orderId, machineId, machineCode: machine.machine_code };
}

const isLockError = (err) => (
  err.code === 'ER_LOCK_DEADLOCK' || err.code === 'ER_LOCK_WAIT_TIMEOUT'
);

// Satu percobaan penuh termasuk transaksi dan pengulangan saat bentrok kunci.
async function runTx(fn, shouldRetry = isLockError) {
  for (let attempt = 1; ; attempt += 1) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const result = await fn(conn);
      await conn.commit();
      return result;
    } catch (err) {
      await conn.rollback().catch(() => {});
      if (attempt >= 3 || !shouldRetry(err)) throw err;
    } finally {
      conn.release();
    }
  }
}

module.exports = {
  TRANSITIONS, attemptStatusChange, attemptConfirmRelay, nextQueuedOrder, refreshQueueWaits, runTx,
};