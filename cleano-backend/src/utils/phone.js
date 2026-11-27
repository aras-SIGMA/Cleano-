'use strict';

// Normalisasi awalan nomor Indonesia (+62/62 -> 08) khusus untuk angka telepon.
function normalizePhone(input) {
  const digits = String(input ?? '').replace(/[\s-]/g, '');
  if (!/^\+?\d+$/.test(digits)) return digits;
  if (digits.startsWith('+62')) return `0${digits.slice(3)}`;
  if (digits.startsWith('62')) return `0${digits.slice(2)}`;
  return digits;
}

module.exports = { normalizePhone };