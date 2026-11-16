'use strict';

// verifikasi kesiapan: env Aiven terbaca, pool konek, schema cleano_db lengkap
require('dotenv').config({ quiet: true });

const fs = require('fs');
const path = require('path');
const { pool } = require('../src/config/database');
const { enabled } = require('../src/config/midtrans');

const REQUIRED_ENV = [
  'DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME',
  'JWT_SECRET', 'MIDTRANS_SERVER_KEY', 'MIDTRANS_CLIENT_KEY',
];

const REQUIRED_OBJECTS = {
  tables: ['users', 'services', 'machines', 'rewards', 'user_vouchers', 'orders'],
  views: ['vw_order_details', 'vw_dashboard_summary', 'vw_daily_revenue_7days'],
  triggers: [
    'trg_before_insert_user_voucher',
    'trg_before_insert_order',
    'trg_after_insert_order',
    'trg_before_update_order',
    'trg_before_update_user_voucher',
    'trg_before_delete_order',
  ],
};

const checks = [];
const check = (name, ok, detail = '') => checks.push({ name, ok, detail });

(async () => {
  check('.env terbaca', fs.existsSync(path.resolve(__dirname, '..', '.env')), '.env siap (jangan commit)');

  const blank = REQUIRED_ENV.filter((k) => !process.env[k]);
  check('variabel env wajib', blank.length === 0, blank.length ? `kosong: ${blank.join(', ')}` : 'lengkap');

  if (!process.env.DB_HOST) {
    finish();
    return;
  }

  try {
    const [meta] = await pool.query('select database() as db, @@session.time_zone as tz, version() as v');
    check('koneksi Aiven (TLS)', true, `db=${meta[0].db} tz=${meta[0].tz} mysql=${meta[0].v}`);

    const [rows] = await pool.query(
      `select
         (select group_concat(table_name) from information_schema.tables
            where table_schema = database() and table_type = 'BASE TABLE') as tables,
         (select group_concat(table_name) from information_schema.views
            where table_schema = database()) as views,
         (select group_concat(trigger_name) from information_schema.triggers
            where trigger_schema = database()) as triggers`
    );
    for (const [kind, expected] of Object.entries(REQUIRED_OBJECTS)) {
      const found = new Set(String(rows[0][kind] || '').split(','));
      const missing = expected.filter((n) => !found.has(n));
      check(`${kind} (${expected.length})`, missing.length === 0,
        missing.length ? `hilang: ${missing.join(', ')}` : 'lengkap');
    }

    const [seed] = await pool.query('select count(*) as n from users');
    check('data seeder', seed[0].n >= 3, `users=${seed[0].n}`);
  } catch (err) {
    check('koneksi Aiven (TLS)', false, `${err.code || err.message}`);
  } finally {
    await pool.end().catch(() => {});
  }

  check('midtrans server key', enabled, enabled ? 'terkonfigurasi' : 'kosong, endpoint pembayaran nonaktif');
  finish();
})();

function finish() {
  const width = Math.max(...checks.map((c) => c.name.length));
  for (const c of checks) {
    console.log(`${c.ok ? 'OK  ' : 'FAIL'}  ${c.name.padEnd(width)}  ${c.detail}`);
  }
  const failed = checks.filter((c) => !c.ok).length;
  console.log(`\n${checks.length - failed}/${checks.length} cek lulus`);
  process.exit(failed ? 1 : 0);
}