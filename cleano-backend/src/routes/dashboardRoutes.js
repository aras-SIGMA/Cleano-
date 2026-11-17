'use strict';

const express = require('express');
const { summary } = require('../controllers/dashboardController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

// Ringkasan omzet dan kapasitas mesin hanya untuk kasir.
router.get('/summary', verifyToken, checkRole(['kasir']), summary);

module.exports = router;
