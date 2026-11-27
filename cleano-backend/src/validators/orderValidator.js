'use strict';

const { z } = require('zod');

// Koersi angka dan nilai kosong dari field multipart form-data.
const nullableInt = (label) =>
  z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : Number(v)),
    z.number({ error: `${label} harus angka.` }).int(`${label} harus bilangan bulat.`).positive(`${label} harus lebih dari 0.`).nullable(),
  );

// Terima hanya field klien; harga, diskon, total, dan poin dihitung trigger.
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
  // Terima voucher_code string lalu petakan ke voucher_id di dalam transaksi.
  voucher_code: z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : String(v).trim().toUpperCase()),
    z.string().max(30, 'Kode voucher maksimal 30 karakter.').nullable(),
  ),
  notes: z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : String(v).trim()),
    z.string().max(2000, 'Catatan maksimal 2000 karakter.').nullable(),
  ),
});

// Validasi filter daftar order, paginasi (maks 100), dan grup status 'aktif'.
const orderListQuery = z.object({
  status: z.enum(['aktif', 'antre', 'proses_cuci', 'sedang_diproses', 'siap_diambil', 'selesai', 'batal'], {
    error: 'Status order tidak dikenal.',
  }).optional(),
  // Kirim parameter pencarian ke SQL agar hasil mencakup seluruh halaman.
  search: z.preprocess(
    (v) => (v === undefined || v === null || String(v).trim() === '' ? undefined : String(v).trim()),
    z.string().max(100, 'Kata kunci pencarian maksimal 100 karakter.').optional(),
  ),
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

// Daftar status tujuan PATCH /:id/status; 'proses_cuci' khusus via confirm-relay.
const orderStatusBody = z.object({
  status: z.enum(['siap_diambil', 'selesai', 'batal'], {
    error: 'Status tujuan hanya boleh siap_diambil, selesai, atau batal.',
  }),
});

const confirmRelayBody = z.object({
  machine_id: z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : Number(v)),
    z.number({ error: 'ID mesin harus angka.' }).int('ID mesin harus bilangan bulat.')
      .positive('ID mesin harus lebih dari 0.')
      .refine((v) => v !== null, 'ID mesin wajib diisi.'),
  ),
});

module.exports = {
  orderCreateBody, orderListQuery, orderStatusBody, confirmRelayBody,
};
