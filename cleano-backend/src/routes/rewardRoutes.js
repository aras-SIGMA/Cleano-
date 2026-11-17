'use strict';

const express = require('express');
const { list, create, update, toggle } = require('../controllers/rewardController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

router.get('/', verifyToken, list);
router.post('/', verifyToken, checkRole(['kasir']), create);
router.put('/:id', verifyToken, checkRole(['kasir']), update);
router.patch('/:id/toggle', verifyToken, checkRole(['kasir']), toggle);

module.exports = router;