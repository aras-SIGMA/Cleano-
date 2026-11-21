'use strict';

const express = require('express');
const { me, lookup } = require('../controllers/userController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

// Tanpa checkRole: kasir dan pelanggan sama-sama perlu membaca profilnya sendiri.
router.get('/me', verifyToken, me);
router.get('/lookup', verifyToken, checkRole(['kasir']), lookup);

module.exports = router;