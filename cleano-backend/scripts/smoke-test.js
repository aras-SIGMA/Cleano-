// Smoke test trigger v1.4 di Aiven dalam transaksi lalu ROLLBACK.
require('dotenv').config({ quiet: true });
const { pool } = require('../src/config/database');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

(async () => {
  const conn = await pool.getConnection();
  const stamp = Date.now().toString().slice(-6);

  async function expectReject(label, sql, params = []) {
    try {
      await conn.query(sql, params);
      ok(label, false, 'statement LOLOS padahal harusnya ditolak');
    } catch (err) {
      const rejected = err.sqlState === '45000' || err.errno === 1644 || err.code === 'ER_SIGNAL_EXCEPTION';
      ok(label, rejected, rejected ? 'ditolak trigger' : `error lain: ${err.code}`);
    }
  }

  try {
    for (const t of ['orders', 'user_vouchers', 'users']) {
      // eslint-disable-next-line no-await-in-loop
      const [[n]] = await conn.query(`select count(*) as n from ${t}`);
      rows.push({ name: `__baseline_${t}`, pass: true, detail: n.n, hidden: true });
    }

    await conn.beginTransaction();

    const [ins] = await conn.query(
      `insert into orders (order_code, user_id, service_id, weight, subtotal_price,
                           discount_amount, total_price, payment_method, status, image_url)
       values (?, 2, 1, 3.00, 0, 0, 0, 'tunai', 'antre', '/uploads/smoke.jpg')`,
      [`SMOKE-${stamp}`]
    );
    const id = ins.insertId;

    const [[order]] = await conn.query(
      `select subtotal_price, total_price, payment_status, paid_at,
              customer_tier_snapshot, points_awarded
         from orders where id = ?`,
      [id]
    );
    ok('trigger hitung harga', order.subtotal_price === 21000 && order.total_price === 21000,
      `${order.subtotal_price}/${order.total_price}`);
    ok('trigger stempel tunai', order.payment_status === 'lunas' && order.paid_at !== null,
      `status=${order.payment_status} paid_at=${order.paid_at}`);
    ok('trigger snapshot tier', ['Silver', 'Gold', 'Platinum'].includes(order.customer_tier_snapshot),
      order.customer_tier_snapshot);

    await expectReject('guard harga immutable', 'update orders set total_price = 1 where id = ?', [id]);
    await expectReject('guard paid_at immutable', "update orders set paid_at = '2020-01-01' where id = ?", [id]);
    await expectReject('guard hard delete', 'delete from orders where id = ?', [id]);

    const [[before]] = await conn.query('select points from users where id = 2');
    await conn.query("update orders set status = 'selesai' where id = ?", [id]);
    const [[after1]] = await conn.query('select points from users where id = 2');
    ok('poin masuk saat selesai', after1.points > before.points, `${before.points} -> ${after1.points}`);

    await conn.query("update orders set notes = 'smoke' where id = ?", [id]);
    const [[after2]] = await conn.query('select points from users where id = 2');
    ok('poin idempoten', after2.points === after1.points, `${after1.points} -> ${after2.points}`);

    await expectReject('guard points_awarded', 'update orders set points_awarded = 0 where id = ?', [id]);

    const [[v]] = await conn.query('select today_revenue, available_machines from vw_dashboard_summary');
    ok('view dashboard', v !== undefined, `omzet=${v.today_revenue} mesin_tersedia=${v.available_machines}`);

    const [[detail]] = await conn.query(
      'select customer_tier, customer_current_tier from vw_order_details where id = ?', [id]);
    ok('view order details', detail !== undefined,
      `tier=${detail.customer_tier} now=${detail.customer_current_tier}`);

    await conn.rollback();
  } catch (err) {
    await conn.rollback().catch(() => {});
    throw err;
  } finally {
    conn.release();
  }

  // pastikan rollback benar-benar mengembalikan data
  const [[post]] = await pool.query('select count(*) as n from orders');
  const baseline = rows.find((r) => r.name === '__baseline_orders');
  ok('rollback bersih', post.n === baseline.detail, `orders ${baseline.detail} -> ${post.n}`);

  await pool.end();

  const visible = rows.filter((r) => !r.hidden);
  const width = Math.max(...visible.map((r) => r.name.length));
  for (const r of visible) console.log(`${r.pass ? 'OK  ' : 'FAIL'}  ${r.name.padEnd(width)}  ${r.detail}`);
  const failed = visible.filter((r) => !r.pass).length;
  console.log(`\n${visible.length - failed}/${visible.length} lulus`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error('GAGAL:', e.code || e.message);
  process.exit(1);
});