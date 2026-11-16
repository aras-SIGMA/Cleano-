'use strict';

const midtransClient = require('midtrans-client');

// snap dipakai membuat transaksi; core dipakai cek status di sync-payment
const isProduction = process.env.MIDTRANS_IS_PRODUCTION === 'true';

const snap = new midtransClient.Snap({
  isProduction,
  serverKey: process.env.MIDTRANS_SERVER_KEY || '',
  clientKey: process.env.MIDTRANS_CLIENT_KEY || '',
});

const core = new midtransClient.CoreApi({
  isProduction,
  serverKey: process.env.MIDTRANS_SERVER_KEY || '',
  clientKey: process.env.MIDTRANS_CLIENT_KEY || '',
});

// server key kosong = mode stub; jangan sampai app diam-diam minta ke Midtrans
const enabled = Boolean(process.env.MIDTRANS_SERVER_KEY);

module.exports = { snap, core, enabled, isProduction };