'use strict';

// Logger JSON satu baris per kejadian tanpa dependensi eksternal tambahan.

function emit(level, message, meta) {
  const line = { time: new Date().toISOString(), level, message };
  if (meta !== undefined) line.meta = meta;
  const out = level === 'error' || level === 'warn' ? process.stderr : process.stdout;
  out.write(`${JSON.stringify(line)}\n`);
}

// Ringkas objek error MySQL/HTTP agar aman dilog tanpa stack panjang.
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

// Helper log error terstruktur sebagai pengganti console.error di seluruh src/.
function createLogger(scope) {
  const withScope = (level) => (message, meta) => emit(level, message, { scope, ...meta });
  return {
    info: withScope('info'),
    warn: withScope('warn'),
    error: withScope('error'),
  };
}

module.exports = { createLogger, describe };
