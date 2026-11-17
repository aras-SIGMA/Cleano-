'use strict';

const { core } = require('../config/midtrans');
const { HttpError, badRequest, notFound, conflict } = require('../utils/response');

// Status Midtrans yang berarti uang sudah masuk. 'capture' hanya untuk kartu dan
// masih bisa ditahan pemeriksaan fraud, jadi ia baru lunas bila fraud_status
// 'accept'. capture + challenge masih ditinjau: uangnya belum tentu sampai.
function isPaid(tx) {
  if (tx.transaction_status === 'settlement') return true;
  return tx.transaction_status === 'capture' && tx.fraud_status === 'accept';
}

// Dipisah supaya skrip uji bisa menggantinya tanpa memanggil jaringan.
async function midtransStatus(orderCode) {
  return core.transaction.status(orderCode);
}

// Satu sinkronisasi, di atas koneksi yang sudah membuka transaksi (pola B4/B6)
// supaya skrip uji bisa ROLLBACK — payment_status tidak bisa dikembalikan ke
// belum_bayar (L-05), jadi rollback satu-satunya cara membersihkan.
//
// Baris order dibaca tanpa FOR UPDATE: panggilan HTTP ke Midtrans berjalan di
// antara baca dan tulis, dan menahan kunci selama round-trip gateway akan
// memblokir kasir lain. Pengaman balapan ada di WHERE saat UPDATE.
async function attemptSyncPayment(conn, orderId, { fetchStatus = midtransStatus } = {}) {
  const [[order]] = await conn.query(
    'select id, order_code, payment_method, payment_status, status from orders where id = ?',
    [orderId],
  );
  if (!order) throw notFound('Order tidak ditemukan.');
  if (order.payment_method !== 'midtrans') {
    throw badRequest('Order ini dibayar tunai, tidak ada transaksi Midtrans untuk disinkronkan.');
  }
  // Order batal tidak boleh dilunasi: uangnya tidak punya transaksi yang bisa
  // dipertanggungjawabkan, dan statusnya sudah final.
  if (order.status === 'batal') throw badRequest('Order batal tidak bisa dilunasi.');

  // Sudah lunas: jangan panggil gateway lagi. Dua klik tombol sinkronisasi tidak
  // boleh menghasilkan dua panggilan dan dua pesan berbeda.
  if (order.payment_status === 'lunas') {
    return { transactionStatus: null, fraudStatus: null, changed: false, alreadyPaid: true };
  }

  let tx;
  try {
    tx = await fetchStatus(order.order_code);
  } catch (err) {
    // 404 dari Midtrans = transaksi tidak pernah dibuat, mis. Snap gagal saat
    // order dibuat. Itu masalah data, bukan gangguan gateway.
    if (Number(err.httpStatusCode) === 404) {
      throw conflict('Transaksi Midtrans untuk order ini tidak ditemukan di gateway.');
    }
    throw new HttpError(502, `Gagal memeriksa status ke Midtrans: ${err.message}`);
  }

  let changed = false;
  if (isPaid(tx)) {
    // paid_at tidak ikut ditulis: trigger BEFORE UPDATE yang menstempelnya, dan
    // menulisnya sendiri ditolak L-04. WHERE payment_status = 'belum_bayar'
    // menjaga dua sinkronisasi bersamaan tidak saling menimpa.
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
