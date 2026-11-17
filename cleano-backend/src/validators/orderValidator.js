'use strict';

const { z } = require('zod');

// multipart/form-data: semua field datang sebagai string, jadi angka dan null
// harus di-koersi sendiri. Klien Flutter mengirim null sebagai string kosong.
const nullableInt = (label) =>
  z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : Number(v)),
    z.number({ error: `${label} harus angka.` }).int(`${label} harus bilangan bulat.`).positive(`${label} harus lebih dari 0.`).nullable(),
  );

// Hanya field yang boleh ditentukan klien. Harga, diskon, total, paid_at,
// customer_tier_snapshot, dan points_awarded dihitung trigger BEFORE INSERT —
// mengirimnya ditolak atau ditimpa, jadi lebih jujur tidak diterima di sini.
const orderCreateBody = z.object({
  user_id: nullableInt('ID pelanggan').refine((v) => v !== null, 'ID pelanggan wajib diisi.'),
  service_id: nullableInt('ID layanan').refine((v) => v !== null, 'ID layanan wajib diisi.'),
  weight: z.preprocess(
    (v) => (typeof v === 'string' ? Number(v) : v),
    z.number({ error: 'Berat harus angka.' })
      .positive('Berat harus lebih dari 0.')
      .max(99.99, 'Berat maksimal 99.99 kg.'),
  ),
  payment_method: z.enum(['tunai', 'midtrans'], { error: 'Metode pembayaran hanya tunai atau midtrans.' }),
  // PRD-02 §4.3 menyebut voucher_code; tabel menyimpan voucher_id, jadi yang
  // diterima adalah kodenya lalu dicari di dalam transaksi.
  voucher_code: z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : String(v).trim().toUpperCase()),
    z.string().max(30, 'Kode voucher maksimal 30 karakter.').nullable(),
  ),
  notes: z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : String(v).trim()),
    z.string().max(2000, 'Catatan maksimal 2000 karakter.').nullable(),
  ),
});

// Query string selalu teks, jadi angka di-koersi. Batas pageSize 100 agar satu
// permintaan tidak bisa memaksa MySQL mengirim seluruh riwayat order.
const orderListQuery = z.object({
  status: z.enum(['antre', 'proses_cuci', 'sedang_diproses', 'siap_diambil', 'selesai', 'batal'], {
    error: 'Status order tidak dikenal.',
  }).optional(),
  page: z.preprocess(
    (v) => (v === undefined || v === '' ? 1 : Number(v)),
    z.number({ error: 'Halaman harus angka.' }).int('Halaman harus bilangan bulat.')
      .positive('Halaman minimal 1.'),
  ),
  pageSize: z.preprocess(
    (v) => (v === undefined || v === '' ? 20 : Number(v)),
    z.number({ error: 'pageSize harus angka.' }).int('pageSize harus bilangan bulat.')
      .positive('pageSize minimal 1.')
      .max(100, 'pageSize maksimal 100.'),
  ),
});

module.exports = { orderCreateBody, orderListQuery };
