'use strict';

const { core } = require('../config/midtrans');
const { HttpError, badRequest, notFound, conflict } = require('../utils/response');

// Status Midtrans lunas: settlement atau capture dengan fraud_status accept.
function isPaid(tx) {
  if (tx.transaction_status === 'settlement') return true;
  return tx.transaction_status === 'capture' && tx.fraud_status === 'accept';
}

// Dipisah supaya skrip uji bisa menggantinya tanpa memanggil jaringan.
async function midtransStatus(orderCode) {
  return core.transaction.status(orderCode);
}

// Sinkronisasi pembayaran dalam transaksi tanpa FOR UPDATE; pengaman balapan di WHERE.
async function attemptSyncPayment(conn, orderId, { fetchStatus = midtransStatus } = {}) {
  const [[order]] = await conn.query(
    'select id, order_code, payment_method, payment_status, status from orders where id = ?',
    [orderId],
  );
  if (!order) throw notFound('Order tidak ditemukan.');
  if (order.payment_method !== 'midtrans') {
    throw badRequest('Order ini dibayar tunai, tidak ada transaksi Midtrans untuk disinkronkan.');
  }
  // Tolak pelunasan untuk order yang sudah berstatus batal.
  if (order.status === 'batal') throw badRequest('Order batal tidak bisa dilunasi.');

  // Kembalikan status lunas langsung tanpa memanggil gateway Midtrans lagi.
  if (order.payment_status === 'lunas') {
    return { transactionStatus: null, fraudStatus: null, changed: false, alreadyPaid: true };
  }

  let tx;
  try {
    tx = await fetchStatus(order.order_code);
  } catch (err) {
    // HTTP 404 Midtrans menandakan transaksi memang belum pernah dibuat di gateway.
    if (Number(err.httpStatusCode) === 404) {
      throw conflict('Transaksi Midtrans untuk order ini tidak ditemukan di gateway.');
    }
    throw new HttpError(502, `Gagal memeriksa status ke Midtrans: ${err.message}`);
  }

  let changed = false;
  if (isPaid(tx)) {
    // Biarkan trigger mengisi paid_at; WHERE payment_status='belum_bayar' cegah timpa ganda.
    const [res] = await conn.query(
      "update orders set payment_status = 'lunas' where id = ? and payment_status = 'belum_bayar'",
      [orderId],
    );
    changed = res.affectedRows === 1;
  }

  return {
    transactionStatus: tx.transaction_status,
    fraudStatus: tx.fraud_status ?? null,
    changed,
    alreadyPaid: false,
  };
}

module.exports = { isPaid, attemptSyncPayment, midtransStatus };
