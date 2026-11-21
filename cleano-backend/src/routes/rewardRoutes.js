'use strict';

const express = require('express');
const {
  list, create, update, toggle, redeem, myVouchers,
} = require('../controllers/rewardController');
const { verifyToken, checkRole } = require('../middlewares/authMiddleware');

const router = express.Router();

router.get('/', verifyToken, list);

// Harus didaftarkan sebelum rute ber-:id supaya "my-vouchers" tidak dibaca
// sebagai id.
router.get('/my-vouchers', verifyToken, checkRole(['pelanggan']), myVouchers);
router.post('/redeem', verifyToken, checkRole(['pelanggan']), redeem);

router.post('/', verifyToken, checkRole(['kasir']), create);
router.put('/:id', verifyToken, checkRole(['kasir']), update);
router.patch('/:id/toggle', verifyToken, checkRole(['kasir']), toggle);

module.exports = router;
