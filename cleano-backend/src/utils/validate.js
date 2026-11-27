'use strict';

const { badRequest } = require('../utils/response');

// Ubah error validasi zod menjadi HttpError 400 dengan pesan pertama.
function parse(schema, input) {
  // Normalisasi body non-objek menjadi objek kosong sebelum validasi zod.
  const data = input && typeof input === 'object' && !Array.isArray(input) ? input : {};
  const result = schema.safeParse(data);
  if (!result.success) throw badRequest(result.error.issues[0].message);
  return result.data;
}

// Validasi parameter :id harus bilangan bulat positif sebelum query MySQL.
function parseId(value) {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) throw badRequest('ID tidak valid.');
  return id;
}

module.exports = { parse, parseId };