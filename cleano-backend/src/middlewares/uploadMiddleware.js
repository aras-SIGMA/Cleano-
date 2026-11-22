'use strict';

const os = require('os');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

// Di serverless (Vercel) filesystem proyek read-only; satu-satunya path yang
// bisa ditulis adalah os.tmpdir(). mkdirSync dulu dipanggil saat modul dimuat,
// sehingga proses mati sebelum server sempat listen. Sekarang folder dibuat
// malas, hanya ketika ada upload sungguhan.
const uploadDir = process.env.VERCEL
  ? path.join(os.tmpdir(), 'cleano-uploads')
  : path.resolve(__dirname, '..', '..', process.env.UPLOAD_DIR || 'uploads');

const maxBytes = (Number(process.env.MAX_IMAGE_MB) || 2) * 1024 * 1024;
const allowed = new Set(['image/jpeg', 'image/png', 'image/webp']);
const extByMime = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp' };

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    try {
      fs.mkdirSync(uploadDir, { recursive: true });
      cb(null, uploadDir);
    } catch (err) {
      cb(err);
    }
  },
  filename: (req, file, cb) => cb(null, `${Date.now()}-${crypto.randomUUID()}${extByMime[file.mimetype]}`),
});

// batas 2 MB + whitelist format (PRD-02 acceptance criteria)
const upload = multer({
  storage,
  limits: { fileSize: maxBytes, files: 1 },
  fileFilter: (req, file, cb) => {
    if (!allowed.has(file.mimetype)) {
      const err = new Error('Format foto harus JPG, PNG, atau WEBP.');
      err.status = 400;
      return cb(err);
    }
    return cb(null, true);
  },
});

module.exports = { upload, uploadDir, maxBytes };