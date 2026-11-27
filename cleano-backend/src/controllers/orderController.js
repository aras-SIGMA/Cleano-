'use strict';

const { pool } = require('../config/database');
const { created, ok, badRequest, notFound, HttpError } = require('../utils/response');
const { parse, parseId } = require('../utils/validate');
const {
  orderCreateBody, orderListQuery, orderStatusBody, confirmRelayBody,
} = require('../validators/orderValidator');
const { allocateMachine, estimateQueueWait } = require('../services/orderAllocation');
const { runTx, attemptStatusChange, attemptConfirmRelay } = require('../services/orderStatus');
const { attemptSyncPayment } = require('../services/paymentSync');
const { snap, enabled } = require('../config/midtrans');
const { withUploadedImage } = require('../middlewares/uploadMiddleware');

// Ambil kolom view tanpa snap_token karena merupakan kredensial pembayaran.
const COLS = `id, order_code, user_id, customer_name, customer_phone, member_code, customer_tier,
  service_id, service_name, machine_id, machine_code, machine_finish_at, weight,
  subtotal_price, discount_amount, total_price, payment_method, payment_status, paid_at,
  snap_redirect_url, status, queue_wait_minutes, image_url, notes, voucher_id, voucher_code, created_at`;

// Kelompok 'aktif' menggabungkan 4 status berjalan untuk filter dashboard kasir.
const AKTIF = ['antre', 'proses_cuci', 'sedang_diproses', 'siap_diambil'];

// Ambil nomor urut harian dari MAX; bentrok ditangani unique index order_code.
async function nextOrderCode(conn) {
  const [[row]] = await conn.query(
    "select max(order_code) as last, date_format(now(), '%Y%m%d') as today "
    + "from orders where order_code like concat('CLN-', date_format(now(), '%Y%m%d'), '-%')",
  );
  const lastNumber = row.last ? Number(row.last.slice(-4)) : 0;
  if (lastNumber >= 9999) throw badRequest('Kuota kode order hari ini habis (9999).');
  return `CLN-${row.today}-${String(lastNumber + 1).padStart(4, '0')}`;
}

// Jalankan percobaan pembuatan order dalam transaksi agar tes bisa ROLLBACK.
async function attemptOrder(conn, { body, imageUrl }) {
  const [[user]] = await conn.query('select id from users where id = ?', [body.user_id]);
  if (!user) throw notFound('Pelanggan tidak ditemukan.');

  const [[service]] = await conn.query(
    'select requires_machine, wash_duration_minutes from services where id = ?',
    [body.service_id],
  );
  if (!service) throw notFound('Paket layanan tidak ditemukan.');

  // Kunci baris voucher dengan FOR UPDATE mencegah pemakaian ganda paralel.
  let voucherId = null;
  if (body.voucher_code) {
    const [[voucher]] = await conn.query(
      'select id, user_id, is_used from user_vouchers where voucher_code = ? for update',
      [body.voucher_code],
    );
    if (!voucher) throw notFound('Kode voucher tidak ditemukan.');
    if (voucher.user_id !== body.user_id) throw badRequest('Voucher tidak valid untuk akun pelanggan ini.');
    if (voucher.is_used) throw badRequest('Voucher sudah pernah digunakan (hanya berlaku 1x pakai).');
    voucherId = voucher.id;
  }

  let machineId = null;
  let status;
  let queueWait = 0;

  if (service.requires_machine) {
    machineId = await allocateMachine(conn, service.wash_duration_minutes);
    if (machineId) {
      status = 'proses_cuci';
    } else {
      status = 'antre';
      queueWait = await estimateQueueWait(conn);
    }
  } else {
    status = 'sedang_diproses';
  }

  const orderCode = await nextOrderCode(conn);

  // Harga, diskon, total, paid_at, tier, dan poin dihitung oleh trigger.
  const [ins] = await conn.query(
    `insert into orders
       (order_code, user_id, service_id, machine_id, weight, payment_method, status,
        queue_wait_minutes, image_url, notes, voucher_id)
     values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [orderCode, body.user_id, body.service_id, machineId, body.weight, body.payment_method,
      status, queueWait, imageUrl, body.notes, voucherId],
  );

  if (body.payment_method === 'midtrans') {
    const [[priced]] = await conn.query('select total_price from orders where id = ?', [ins.insertId]);
    // Panggilan Midtrans berjalan dalam transaksi sesuai alur PRD-02 §4.3.
    const [[cust]] = await conn.query('select name, phone, email from users where id = ?', [body.user_id]);
    const tx = await snap.createTransaction({
      transaction_details: { order_id: orderCode, gross_amount: priced.total_price },
      customer_details: { first_name: cust.name, phone: cust.phone, email: cust.email },
    }).catch((err) => {
      throw new HttpError(502, `Gagal membuat transaksi Midtrans: ${err.message}`);
    });
    await conn.query('update orders set snap_token = ?, snap_redirect_url = ? where id = ?',
      [tx.token, tx.redirect_url, ins.insertId]);
  }

  const [[row]] = await conn.query(`select ${COLS} from vw_order_details where id = ?`, [ins.insertId]);
  return row;
}

function isRetryable(err) {
  if (err.code === 'ER_LOCK_DEADLOCK' || err.code === 'ER_LOCK_WAIT_TIMEOUT') return true;
  // Ulangi bila order_code bentrok; tolak langsung bila voucher sudah dipakai.
  return err.code === 'ER_DUP_ENTRY' && String(err.sqlMessage || '').includes('order_code');
}

// Satu percobaan termasuk transaksi dan pengulangan bila bentrok.
function placeOrder(input) {
  return runTx((conn) => attemptOrder(conn, input), isRetryable);
}

// POST /api/orders — kasir, multipart dengan foto wajib
async function create(req, res) {
  const row = await withUploadedImage(
    req,
    {
      missingMessage: 'Foto bukti kondisi pakaian wajib diunggah pada field "image".',
      parseBody: () => parse(orderCreateBody, req.body),
      beforeUpload: (body) => {
        if (body.payment_method === 'midtrans' && !enabled) {
          throw new HttpError(503, 'Pembayaran Midtrans belum dikonfigurasi (MIDTRANS_SERVER_KEY kosong).');
        }
      },
    },
    (imageUrl, body) => placeOrder({ body, imageUrl }),
  );
  return created(res, row, 'Order dibuat.');
}

// GET /api/orders: tanpa snap_token; snap_redirect_url hanya untuk kasir.
const LIST_COLS_KASIR = `id, order_code, user_id, customer_name, customer_phone, member_code,
  customer_tier, service_id, service_name, price_per_kg, requires_machine, machine_id, machine_code,
  machine_finish_at, weight, subtotal_price, discount_amount, total_price, payment_method,
  payment_status, paid_at, snap_redirect_url, status, queue_wait_minutes, points_awarded,
  image_url, notes, voucher_id, voucher_code, created_at, updated_at`;

const LIST_COLS_PELANGGAN = `id, order_code, service_id, service_name, machine_id, machine_code,
  machine_finish_at, weight, subtotal_price, discount_amount, total_price, payment_method,
  payment_status, status, queue_wait_minutes, points_awarded, image_url, notes,
  voucher_code, created_at, updated_at`;

async function list(req, res) {
  const q = parse(orderListQuery, req.query);
  const isKasir = req.user.role === 'kasir';

  // Ambil user_id dari token, bukan query, untuk mencegah akses lintas akun.
  const where = [];
  const values = [];
  if (!isKasir) { where.push('user_id = ?'); values.push(req.user.id); }
  // Escape karakter % dan _ sebelum query LIKE di MySQL.
  if (q.search) {
    const like = `%${q.search.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    where.push('(order_code like ? or customer_name like ? or customer_phone like ?)');
    values.push(like, like, like);
  }
  if (q.status === 'aktif') {
    where.push(`status in (${AKTIF.map(() => '?').join(', ')})`);
    values.push(...AKTIF);
  } else if (q.status) {
    where.push('status = ?');
    values.push(q.status);
  }

  const whereSql = where.length ? `where ${where.join(' and ')}` : '';
  const offset = (q.page - 1) * q.pageSize;

  const [[{ total }]] = await pool.query(
    `select count(*) as total from vw_order_details ${whereSql}`, values,
  );

  const [rows] = await pool.query(
    `select ${isKasir ? LIST_COLS_KASIR : LIST_COLS_PELANGGAN}
       from vw_order_details ${whereSql}
      order by created_at desc, id desc
      limit ? offset ?`,
    [...values, q.pageSize, offset],
  );

  return ok(res, {
    items: rows,
    page: q.page,
    pageSize: q.pageSize,
    total,
    totalPages: Math.max(1, Math.ceil(total / q.pageSize)),
  }, 'Daftar order.');
}

// PATCH /api/orders/:id/status — kasir
async function updateStatus(req, res) {
  const id = parseId(req.params.id);
  const b = parse(orderStatusBody, req.body);

  const result = await runTx((conn) => attemptStatusChange(conn, { orderId: id, status: b.status }));
  const [[row]] = await pool.query(`select ${COLS} from vw_order_details where id = ?`, [id]);

  return ok(res, {
    ...row,
    // Kirim objek next_queue_order hanya bila mesin benar-benar baru dilepas.
    freed_machine_id: result.freedMachineId,
    next_queue_order: result.nextQueueOrder,
  }, 'Status order diperbarui.');
}

// PATCH /api/orders/:id/confirm-relay — kasir
async function confirmRelay(req, res) {
  const id = parseId(req.params.id);
  const b = parse(confirmRelayBody, req.body);

  const result = await runTx((conn) => attemptConfirmRelay(conn, { orderId: id, machineId: b.machine_id }));
  const [[row]] = await pool.query(`select ${COLS} from vw_order_details where id = ?`, [id]);

  return ok(res, row, `Order mulai dicuci di ${result.machineCode}.`);
}

// POST /api/orders/:id/sync-payment — kasir
async function syncPayment(req, res) {
  const id = parseId(req.params.id);

  // Mode stub: jangan balas sukses palsu saat server key Midtrans kosong.
  if (!enabled) {
    throw new HttpError(503, 'Pembayaran Midtrans belum dikonfigurasi (MIDTRANS_SERVER_KEY kosong).');
  }

  const result = await runTx((conn) => attemptSyncPayment(conn, id));
  const [[row]] = await pool.query(`select ${COLS} from vw_order_details where id = ?`, [id]);

  const pesan = result.changed
    ? 'Pembayaran dikonfirmasi lunas.'
    : result.alreadyPaid
      ? 'Order ini sudah lunas.'
      : `Midtrans melaporkan status "${result.transactionStatus}", belum lunas.`;

  return ok(res, {
    ...row,
    transaction_status: result.transactionStatus,
    fraud_status: result.fraudStatus,
    changed: result.changed,
  }, pesan);
}

module.exports = {
  create, attemptOrder, placeOrder, list, updateStatus, confirmRelay, syncPayment,
};