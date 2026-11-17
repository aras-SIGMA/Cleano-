'use strict';

const { badRequest } = require('../utils/response');

// Ubah hasil zod jadi HttpError 400 dengan pesan pertama. Controller tetap
// melempar, error handler server.js yang membentuk JSON.
function parse(schema, input) {
  // body bisa berupa string/array kalau klien mengirim JSON aneh; perlakukan
  // sebagai kosong supaya pesannya tetap pesan validasi, bukan pesan zod internal.
  const data = input && typeof input === 'object' && !Array.isArray(input) ? input : {};
  const result = schema.safeParse(data);
  if (!result.success) throw badRequest(result.error.issues[0].message);
  return result.data;
}

module.exports = { parse };