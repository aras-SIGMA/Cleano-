'use strict';

const jwt = require('jsonwebtoken');

// req.user = { id, member_code, role } (PRD-02 §3.1)
function verifyToken(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ success: false, message: 'Token tidak ditemukan.' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: payload.id, member_code: payload.member_code, role: payload.role };
    return next();
  } catch {
    return res.status(401).json({ success: false, message: 'Token tidak valid atau kedaluwarsa.' });
  }
}

function checkRole(allowed) {
  return (req, res, next) => {
    if (!req.user || !allowed.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Akses ditolak untuk role ini.' });
    }
    return next();
  };
}

module.exports = { verifyToken, checkRole };