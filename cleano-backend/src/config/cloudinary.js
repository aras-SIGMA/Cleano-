'use strict';

const { v2: cloudinary } = require('cloudinary');

// Simpan foto ke Cloudinary; kosongkan variabel CLOUDINARY_* untuk mode disk lokal.
const enabled = Boolean(
  process.env.CLOUDINARY_CLOUD_NAME
  && process.env.CLOUDINARY_API_KEY
  && process.env.CLOUDINARY_API_SECRET,
);

if (enabled) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });
}

// Folder tujuan foto bukti drop-off di akun Cloudinary.
const FOLDER = process.env.CLOUDINARY_FOLDER || 'cleano/orders';

/** Unggah berkas sementara multer ke Cloudinary lalu kembalikan url dan publicId. */
async function uploadImage(filePath, { folder = FOLDER, maxDim = 1600 } = {}) {
  const res = await cloudinary.uploader.upload(filePath, {
    folder,
    resource_type: 'image',
    // Batasi dimensi foto di sisi Cloudinary untuk menjaga kuota akun.
    transformation: [{ width: maxDim, height: maxDim, crop: 'limit' }],
  });
  return { url: res.secure_url, publicId: res.public_id };
}

/** Hapus foto Cloudinary jika pembuatan order gagal agar tidak yatim. */
async function destroyImage(publicId) {
  if (!publicId) return;
  await cloudinary.uploader.destroy(publicId).catch(() => {});
}

module.exports = { enabled, uploadImage, destroyImage, FOLDER };

