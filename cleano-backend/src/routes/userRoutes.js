'use strict';

const express = require('express');
const { me, updateAvatar, lookup } = require('../controllers/userController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');
const { lookupLimiter } = require('../middlewares/rateLimit');
const { upload } = require('../middlewares/uploadMiddleware');

const router = express.Router();

// Tanpa checkRole: kasir dan pelanggan sama-sama perlu membaca & memperbarui profilnya sendiri.
router.get('/me', verifyToken, me);
router.patch('/me/avatar', verifyToken, upload.single('image'), updateAvatar);
router.get('/lookup', verifyToken, checkRole(['kasir']), lookupLimiter, lookup);

module.exports = router;