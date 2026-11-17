'use strict';

const express = require('express');
const { lookup } = require('../controllers/userController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

router.get('/lookup', verifyToken, checkRole(['kasir']), lookup);

module.exports = router;