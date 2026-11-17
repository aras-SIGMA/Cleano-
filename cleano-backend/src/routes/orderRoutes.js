'use strict';

const express = require('express');
const { create, list } = require('../controllers/orderController');
const { upload } = require('../middlewares/uploadMiddleware');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

// Foto dikirim sebagai multipart, jadi multer jalan sebelum controller.
// upload.single menolak 400 sendiri bila format/ukuran salah (lihat server.js).
router.post('/', verifyToken, checkRole(['kasir']), upload.single('image'), create);
router.get('/', verifyToken, list);

module.exports = router;