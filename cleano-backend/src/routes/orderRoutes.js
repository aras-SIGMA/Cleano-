'use strict';

const express = require('express');
const { create, list, updateStatus, confirmRelay } = require('../controllers/orderController');
const { upload } = require('../middlewares/uploadMiddleware');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

// Foto dikirim sebagai multipart, jadi multer jalan sebelum controller.
// upload.single menolak 400 sendiri bila format/ukuran salah (lihat server.js).
router.post('/', verifyToken, checkRole(['kasir']), upload.single('image'), create);
router.get('/', verifyToken, list);

// Dua endpoint ini yang menggerakkan estafet mesin, jadi keduanya kasir saja.
router.patch('/:id/status', verifyToken, checkRole(['kasir']), updateStatus);
router.patch('/:id/confirm-relay', verifyToken, checkRole(['kasir']), confirmRelay);

module.exports = router;