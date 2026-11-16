'use strict';

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const uploadDir = path.resolve(__dirname, '..', '..', process.env.UPLOAD_DIR || 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const maxBytes = (Number(process.env.MAX_IMAGE_MB) || 2) * 1024 * 1024;
const allowed = new Set(['image/jpeg', 'image/png', 'image/webp']);
const extByMime = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp' };

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
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