'use strict';

const os = require('os');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { badRequest } = require('../utils/response');

// Buat folder upload secara malas di os.tmpdir() agar aman di Vercel.
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

// Batasi ukuran berkas 2 MB, field teks 8 KB, dan jumlah parts.
const upload = multer({
  storage,
  limits: { fileSize: maxBytes, files: 1, fieldSize: 8 * 1024, parts: 10 },
  fileFilter: (req, file, cb) => {
    if (!allowed.has(file.mimetype)) {
      const err = new Error('Format foto harus JPG, PNG, atau WEBP.');
      err.status = 400;
      return cb(err);
    }
    return cb(null, true);
  },
});

/** Verifikasi magic bytes JPEG/PNG/WEBP agar ekstensi palsu ditolak. */
function verifyImageMagicBytes(filePath) {
  const fd = fs.openSync(filePath, 'r');
  try {
    const buf = Buffer.alloc(12);
    const bytesRead = fs.readSync(fd, buf, 0, 12, 0);
    if (bytesRead < 3) return false;

    const isJpeg = buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff;
    const isPng = bytesRead >= 8
      && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47
      && buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a && buf[7] === 0x0a;
    const isWebp = bytesRead >= 12
      && buf.toString('ascii', 0, 4) === 'RIFF'
      && buf.toString('ascii', 8, 12) === 'WEBP';

    return isJpeg || isPng || isWebp;
  } finally {
    fs.closeSync(fd);
  }
}

/** Kelola validasi foto, unggahan Cloudinary/lokal, dan pembersihan file otomatis. */
async function withUploadedImage(req, {
  missingMessage,
  parseBody,
  beforeUpload,
  uploadOptions,
}, handler) {
  let uploaded = null;
  let validFile = false;
  try {
    const context = parseBody ? parseBody(req) : null;
    if (!req.file) throw badRequest(missingMessage);
    if (!verifyImageMagicBytes(req.file.path)) {
      throw badRequest('Format foto harus JPG, PNG, atau WEBP yang valid.');
    }
    validFile = true;
    if (beforeUpload) beforeUpload(context);

    uploaded = cloudinary.enabled
      ? await cloudinary.uploadImage(req.file.path, uploadOptions)
      : { url: `/uploads/${req.file.filename}`, publicId: null };

    return await handler(uploaded.url, context);
  } catch (err) {
    if (uploaded?.publicId) await cloudinary.destroyImage(uploaded.publicId);
    if (req.file && (!cloudinary.enabled || !validFile)) fs.unlink(req.file.path, () => {});
    throw err;
  } finally {
    if (cloudinary.enabled && req.file) fs.unlink(req.file.path, () => {});
  }
}

module.exports = { upload, uploadDir, maxBytes, verifyImageMagicBytes, withUploadedImage };