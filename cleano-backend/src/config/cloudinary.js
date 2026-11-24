'use strict';

const { v2: cloudinary } = require('cloudinary');

// Foto bukti drop-off disimpan di Cloudinary, bukan di disk server.
//
// Di Vercel filesystem proyek read-only dan os.tmpdir() hilang antar-invoke,
// jadi foto yang ditulis lokal akan lenyap sebelum pelanggan sempat membukanya.
// Selain itu express.static() diabaikan Vercel — hanya folder public/ yang
// disajikan, dan folder itu tidak bisa ditulis saat runtime.
//
// Kosongkan ketiga variabel CLOUDINARY_* untuk mode lokal: uploadMiddleware
// lalu memakai disk seperti sebelumnya, sehingga pengembangan tidak wajib
// punya akun Cloudinary.
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

// Folder di akun Cloudinary. Semua foto drop-off masuk ke sini supaya mudah
// dihapus massal bila suatu saat perlu.
const FOLDER = process.env.CLOUDINARY_FOLDER || 'cleano/orders';

/**
 * Unggah satu berkas ke Cloudinary.
 * @param {string} filePath path sementara hasil multer
 * @returns {Promise<{url: string, publicId: string}>}
 */
async function uploadImage(filePath) {
  const res = await cloudinary.uploader.upload(filePath, {
    folder: FOLDER,
    resource_type: 'image',
    // Batas dimensi di sisi Cloudinary, bukan hanya di multer: kuota akun
    // perlu penjaganya sendiri bila nanti ada jalur unggah lain.
    transformation: [{ width: 1600, height: 1600, crop: 'limit' }],
  });
  return { url: res.secure_url, publicId: res.public_id };
}

/**
 * Hapus foto yang sudah terunggah. Dipanggil saat order gagal dibuat supaya
 * tidak ada foto yatim yang menagih kuota.
 */
async function destroyImage(publicId) {
  if (!publicId) return;
  await cloudinary.uploader.destroy(publicId).catch(() => {});
}

module.exports = { enabled, uploadImage, destroyImage, FOLDER };

