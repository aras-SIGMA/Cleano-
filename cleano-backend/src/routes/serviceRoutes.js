'use strict';

const express = require('express');
const { list, create, update, remove } = require('../controllers/serviceController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

router.get('/', verifyToken, list);
router.post('/', verifyToken, checkRole(['kasir']), create);
router.put('/:id', verifyToken, checkRole(['kasir']), update);
router.delete('/:id', verifyToken, checkRole(['kasir']), remove);

module.exports = router;