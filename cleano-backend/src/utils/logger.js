'use strict';

// Log satu baris JSON per kejadian, supaya bisa dibaca mesin (grep, Loki,
// CloudWatch) tanpa parser khusus. console.* biasa bercampur dengan output
// framework dan tidak membawa konteks.
//
// Ditulis tangan, bukan pino/winston: kebutuhan proyek ini hanya "satu baris
// JSON dengan level dan waktu". Menambah dependensi logging penuh untuk itu
// tidak sepadan.

function emit(level, message, meta) {
  const line = { time: new Date().toISOString(), level, message };
  if (meta !== undefined) line.meta = meta;
  const out = level === 'error' || level === 'warn' ? process.stderr : process.stdout;
  out.write(`${JSON.stringify(line)}\n`);
}

// Error MySQL / HTTP diterjemahkan ke bentuk yang aman dilog: tanpa stack
// panjang, tapi tetap menyimpan kode dan pesan aslinya.
function describe(err) {
  if (!err || typeof err !== 'object') return { message: String(err) };
  return {
    name: err.name,
    message: err.message,
    code: err.code,
    sqlState: err.sqlState,
    errno: err.errno,
    status: err.status,
    stack: err.stack,
  };
}

const logger = {
  info: (message, meta) => emit('info', message, meta),
  warn: (message, meta) => emit('warn', message, meta),
  error: (message, meta) => emit('error', message, meta),
  describe,
};

// Pengganti console.error di seluruh src/. Dipakai database.js dan error
// handler server.js supaya semua baris log punya bentuk yang sama.
function createLogger(scope) {
  const withScope = (level) => (message, meta) => emit(level, message, { scope, ...meta });
  return {
    info: withScope('info'),
    warn: withScope('warn'),
    error: withScope('error'),
    describe,
  };
}

module.exports = { logger, createLogger };
