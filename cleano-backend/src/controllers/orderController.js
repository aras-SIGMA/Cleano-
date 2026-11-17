'use strict';

const fs = require('fs');
const { pool } = require('../config/database');
const { created, badRequest, notFound, HttpError } = require('../utils/response');
const { parse } = require('../utils/validate');
const { orderCreateBody } = require('../validators/orderValidator');
const { allocateMachine, estimateQueueWait } = require('../services/orderAllocation');
const { snap, enabled } = require('../config/midtrans');

// Kolom respons diambil dari view supaya nama pelanggan/layanan ikut terbawa.
// snap_token sengaja tidak ada: itu kredensial pembayaran dan tidak pernah perlu
// sampai ke klien (aturan yang sama dipakai B5).
const COLS = `id, order_code, user_id, customer_name, customer_phone, member_code, customer_tier,
  service_id, service_name, machine_id, machine_code, machine_finish_at, weight,
  subtotal_price, discount_amount, total_price, payment_method, payment_status, paid_at,
  snap_redirect_url, status, queue_wait_minutes, image_url, notes, voucher_id, voucher_code, created_at`;

const MAX_ATTEMPTS = 3;

// Nomor urut diambil dari MAX per tanggal. Dua request pada milidetik yang sama
// bisa mendapat nomor yang sama; indeks unik order_code yang memutuskan, lalu
// percobaan diulang dengan nomor baru. Jangan dikunci FOR UPDATE — agregat tidak
// mengunci baris yang belum ada.
async function nextOrderCode(conn) {
  const [[row]] = await conn.query(
    "select max(order_code) as last, date_format(now(), '%Y%m%d') as today "
    + "from orders where order_code like concat('CLN-', date_format(now(), '%Y%m%d'), '-%')",
  );
  const lastNumber = row.last ? Number(row.last.slice(-4)) : 0;
  if (lastNumber >= 9999) throw badRequest('Kuota kode order hari ini habis (9999).');
  return `CLN-${row.today}-${String(lastNumber + 1).padStart(4, '0')}`;
}

// Satu percobaan penuh di atas koneksi yang sudah membuka transaksi. Tidak
// memulai atau mengakhiri transaksi sendiri supaya skrip uji bisa menjalankannya
// lalu ROLLBACK — order tidak boleh dihapus (trigger L-07), jadi rollback adalah
// satu-satunya cara membersihkan hasil uji.
async function attemptOrder(conn, { body, imageUrl }) {
  const [[user]] = await conn.query('select id from users where id = ?', [body.user_id]);
  if (!user) throw notFound('Pelanggan tidak ditemukan.');

  const [[service]] = await conn.query(
    'select requires_machine, wash_duration_minutes from services where id = ?',
    [body.service_id],
  );
  if (!service) throw notFound('Paket layanan tidak ditemukan.');

  // Dikunci supaya dua order tidak memakai kupon sekali-pakai yang sama.
  // Trigger juga memeriksa, tapi pemeriksaan itu baru berjalan saat INSERT —
  // dua transaksi paralel sudah sama-sama membaca is_used = 0 saat itu.
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

  // subtotal_price / discount_amount / total_price / paid_at /
  // customer_tier_snapshot / points_awarded sengaja tidak dikirim: trigger
  // BEFORE INSERT yang menghitung dan menimpanya.
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
    // ponytail: panggilan HTTP Midtrans terjadi di dalam transaksi, sesuai
    // PRD-02 §4.3 langkah 5. Konsekuensinya lock voucher/mesin ditahan selama
    // round-trip gateway. Pindahkan ke pola outbox kalau latensi Midtrans mulai
    // menahan kasir lain.
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
  // Nomor order bentrok boleh diulang. ER_DUP_ENTRY dari uq_orders_voucher tidak:
  // itu berarti voucher sudah dipakai order lain, dan mengulang tidak menolong.
  return err.code === 'ER_DUP_ENTRY' && String(err.sqlMessage || '').includes('order_code');
}

// Satu percobaan termasuk transaksi dan pengulangan bila bentrok.
async function placeOrder(input) {
  for (let attempt = 1; ; attempt += 1) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const row = await attemptOrder(conn, input);
      // Commit setelah semua langkah selesai: rollback tidak bisa menarik kembali
      // transaksi Midtrans yang sudah terlanjur dibuat.
      await conn.commit();
      return row;
    } catch (err) {
      // Mesin dan voucher ditandai di dalam transaksi ini, jadi rollback sudah
      // mengembalikannya. Tidak ada pelepasan manual di sini.
      await conn.rollback().catch(() => {});
      if (attempt >= MAX_ATTEMPTS || !isRetryable(err)) throw err;
    } finally {
      conn.release();
    }
  }
}

// POST /api/orders — kasir, multipart dengan foto wajib
async function create(req, res) {
  const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;
  try {
    const body = parse(orderCreateBody, req.body);
    if (!imageUrl) throw badRequest('Foto bukti kondisi pakaian wajib diunggah pada field "image".');

    if (body.payment_method === 'midtrans' && !enabled) {
      throw new HttpError(503, 'Pembayaran Midtrans belum dikonfigurasi (MIDTRANS_SERVER_KEY kosong).');
    }

    const row = await placeOrder({ body, imageUrl });
    return created(res, row, 'Order dibuat.');
  } catch (err) {
    // Foto sudah tersimpan ke disk sebelum validasi jalan. Jangan tinggalkan
    // sampah bila request akhirnya ditolak.
    if (req.file) fs.unlink(req.file.path, () => {});
    throw err;
  }
}

module.exports = { create, attemptOrder, placeOrder };