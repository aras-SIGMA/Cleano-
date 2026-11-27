'use strict';

const express = require('express');
const { create, list, updateStatus, confirmRelay, syncPayment } = require('../controllers/orderController');
const { upload } = require('../middlewares/uploadMiddleware');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

// Multer memproses foto multipart sebelum controller; ukuran/format salah ditolak 400.
router.post('/', verifyToken, checkRole(['kasir']), upload.single('image'), create);
router.get('/', verifyToken, list);

// Dua endpoint ini yang menggerakkan estafet mesin, jadi keduanya kasir saja.
router.patch('/:id/status', verifyToken, checkRole(['kasir']), updateStatus);
router.patch('/:id/confirm-relay', verifyToken, checkRole(['kasir']), confirmRelay);

// Pakai POST karena endpoint ini memeriksa gateway sebelum memperbarui status.
router.post('/:id/sync-payment', verifyToken, checkRole(['kasir']), syncPayment);

module.exports = router;