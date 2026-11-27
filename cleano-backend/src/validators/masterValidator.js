'use strict';

const { z } = require('zod');

// Skema validasi layanan mengikuti kolom dan nilai default database_schema.sql.

const nullableText = (max, label) =>
  z.string().max(max, `${label} maksimal ${max} karakter.`).nullish();

// Kolom wajib. Dipakai apa adanya oleh PUT.
const serviceFields = {
  name: z.string({ error: 'Nama layanan wajib diisi.' }).trim()
    .min(1, 'Nama layanan wajib diisi.')
    .max(100, 'Nama layanan maksimal 100 karakter.'),
  price_per_kg: z.number({ error: 'Harga per kg harus angka.' })
    .int('Harga per kg harus bilangan bulat.')
    .positive('Harga per kg harus lebih dari 0.'),
  wash_duration_minutes: z.number({ error: 'Durasi cuci harus angka.' })
    .int('Durasi cuci harus bilangan bulat.')
    .min(0, 'Durasi cuci tidak boleh negatif.'),
  estimated_hours: z.number({ error: 'Estimasi jam harus angka.' })
    .int('Estimasi jam harus bilangan bulat.')
    .positive('Estimasi jam harus lebih dari 0.'),
  requires_machine: z.union([z.literal(0), z.literal(1)], { error: 'requires_machine harus 0 atau 1.' }),
  description: nullableText(2000, 'Deskripsi'),
};

// PUT layanan mewajibkan semua field agar nilai default tidak menimpa data.
const servicePutBody = z.object({ ...serviceFields, description: serviceFields.description.default(null) });

// POST: tiga field teknis boleh dihilangkan dan memakai default kolom.
const serviceCreateBody = z.object({
  ...serviceFields,
  wash_duration_minutes: serviceFields.wash_duration_minutes.default(45),
  estimated_hours: serviceFields.estimated_hours.default(24),
  requires_machine: serviceFields.requires_machine.default(1),
  description: serviceFields.description.default(null),
});

// Validasi format DATETIME MySQL sebelum nilai dikirim ke database.
const dateTime = z.string({ error: 'Waktu selesai harus teks YYYY-MM-DD HH:MM:SS.' })
  .regex(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, 'Waktu selesai harus format YYYY-MM-DD HH:MM:SS.')
  .refine((v) => !Number.isNaN(Date.parse(v.replace(' ', 'T'))), 'Waktu selesai bukan tanggal yang valid.');

// Larang status 'digunakan' ditulis manual karena dikelola penuh oleh alur order.
const machineBody = z.object({
  machine_code: z.string({ error: 'Kode mesin wajib diisi.' }).trim()
    .min(1, 'Kode mesin wajib diisi.')
    .max(20, 'Kode mesin maksimal 20 karakter.'),
  status: z.enum(['tersedia', 'maintenance'], { error: 'Status mesin hanya boleh tersedia atau maintenance.' })
    .default('tersedia'),
  capacity_kg: z.number({ error: 'Kapasitas harus angka.' })
    .positive('Kapasitas harus lebih dari 0.')
    .max(99.99, 'Kapasitas maksimal 99.99 kg.')
    .default(7),
  estimated_finish_at: dateTime.nullish().default(null),
});

// PATCH mesin hanya ubah status; capacity_kg tetap sesuai spesifikasi awal.
const machinePatchBody = z.object({
  status: z.enum(['tersedia', 'maintenance'], { error: 'Status mesin hanya boleh tersedia atau maintenance.' }).optional(),
  estimated_finish_at: dateTime.nullish(),
});

const rewardFields = {
  title: z.string({ error: 'Judul reward wajib diisi.' }).trim()
    .min(1, 'Judul reward wajib diisi.')
    .max(100, 'Judul reward maksimal 100 karakter.'),
  description: nullableText(2000, 'Deskripsi'),
  points_required: z.number({ error: 'Poin wajib diisi.' })
    .int('Poin harus bilangan bulat.')
    .positive('Poin harus lebih dari 0.'),
  discount_amount: z.number({ error: 'Nilai diskon wajib diisi.' })
    .int('Nilai diskon harus bilangan bulat.')
    .positive('Nilai diskon harus lebih dari 0.'),
  is_active: z.union([z.literal(0), z.literal(1)], { error: 'is_active harus 0 atau 1.' }),
};

const rewardCreateBody = z.object({
  ...rewardFields,
  description: rewardFields.description.default(null),
  is_active: rewardFields.is_active.default(1),
});

// PUT reward mengecualikan is_active karena status aktif dikelola endpoint toggle.
const rewardPutBody = z.object({
  title: rewardFields.title,
  description: rewardFields.description.default(null),
  points_required: rewardFields.points_required,
  discount_amount: rewardFields.discount_amount,
});

// Skema klaim voucher hanya menerima reward_id; kode dan poin oleh server.
const rewardRedeemBody = z.object({
  reward_id: z.preprocess(
    (v) => (v === undefined || v === null || v === '' ? null : Number(v)),
    z.number({ error: 'ID reward harus angka.' }).int('ID reward harus bilangan bulat.')
      .positive('ID reward harus lebih dari 0.')
      .refine((v) => v !== null, 'ID reward wajib diisi.'),
  ),
});

module.exports = {
  serviceCreateBody,
  servicePutBody,
  machineBody,
  machinePatchBody,
  rewardCreateBody,
  rewardPutBody,
  rewardRedeemBody,
};