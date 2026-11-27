'use strict';

const express = require('express');
const { register, login, changePassword } = require('../controllers/authController');
const { loginLimiter, registerLimiter, changePasswordLimiter } = require('../middlewares/rateLimit');
const { verifyToken } = require('../middlewares/authMiddleware');

const router = express.Router();

router.post('/register', registerLimiter, register);
router.post('/login', loginLimiter, login);
router.patch('/change-password', verifyToken, changePasswordLimiter, changePassword);

module.exports = router;
