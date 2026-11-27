'use strict';

const express = require('express');
const { register, login, changePassword } = require('../controllers/authController');
const { loginLimiter, registerLimiter } = require('../middlewares/rateLimit');
const { verifyToken } = require('../middlewares/authMiddleware');

const router = express.Router();

router.post('/register', registerLimiter, register);
router.post('/login', loginLimiter, login);
router.patch('/change-password', verifyToken, loginLimiter, changePassword);

module.exports = router;
