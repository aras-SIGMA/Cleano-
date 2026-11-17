'use strict';

const express = require('express');
const { list, create, update } = require('../controllers/machineController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

router.get('/', verifyToken, list);
router.post('/', verifyToken, checkRole(['kasir']), create);
router.patch('/:id', verifyToken, checkRole(['kasir']), update);

module.exports = router;