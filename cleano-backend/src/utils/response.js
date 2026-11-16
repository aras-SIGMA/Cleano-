'use strict';

// Format respons seragam (PRD-02 §3.2). Dipakai semua controller.

function ok(res, data, message = 'Operasi berhasil.') {
  return res.status(200).json({ success: true, message, data });
}

function created(res, data, message = 'Data berhasil dibuat.') {
  return res.status(201).json({ success: true, message, data });
}

// Error terstruktur. Controller melempar HttpError, error handler di server.js
// yang mengubahnya jadi JSON.
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const badRequest = (msg) => new HttpError(400, msg);
const unauthorized = (msg) => new HttpError(401, msg);
const forbidden = (msg) => new HttpError(403, msg);
const notFound = (msg) => new HttpError(404, msg);
const conflict = (msg) => new HttpError(409, msg);

module.exports = { ok, created, HttpError, badRequest, unauthorized, forbidden, notFound, conflict };
