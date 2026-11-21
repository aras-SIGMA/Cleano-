'use strict';

// Nomor Indonesia ditulis dengan tiga awalan berbeda oleh orang yang sama:
// 081234567890 (kartu & database), 6281234567890 (WhatsApp), +6281234567890
// (tautan wa.me). Semuanya disimpan dalam bentuk 08…, jadi pencarian harus
// menormalkan dulu sebelum membandingkan.
//
// Bukan validator: masukan yang bukan nomor dikembalikan apa adanya (setelah
// spasi/tanda hubung dibuang) supaya pencarian member_code tidak ikut terganggu.
function normalizePhone(input) {
  const digits = String(input ?? '').replace(/[\s-]/g, '');
  if (!/^\+?\d+$/.test(digits)) return digits;
  if (digits.startsWith('+62')) return `0${digits.slice(3)}`;
  if (digits.startsWith('62')) return `0${digits.slice(2)}`;
  return digits;
}

module.exports = { normalizePhone };