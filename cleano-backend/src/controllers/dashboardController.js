'use strict';

const { pool } = require('../config/database');
const { ok } = require('../utils/response');

// Tanggal 7 hari terakhir dihitung MySQL, bukan Node. Sesi database berjalan
// pada +07:00, jadi curdate() di sini sama dengan curdate() yang dipakai
// vw_dashboard_summary. Kalau daftar tanggal dibuat dengan Date di Node, zona
// waktu mesin server bisa menggeser rentangnya satu hari.
//
// Recursive CTE dipakai supaya hari tanpa transaksi tetap muncul bernilai 0 —
// vw_daily_revenue_7days hanya memuat tanggal yang punya order lunas.
// coalesce tidak perlu: kolom yang tidak punya pasangan bernilai NULL, dan
// num() di bawah mengubahnya jadi 0.
const REVENUE_7_DAYS = `
  with recursive d as (
    select date_sub(curdate(), interval 6 day) as dt
    union all
    select date_add(dt, interval 1 day) from d where dt < curdate()
  )
  select date_format(d.dt, '%Y-%m-%d') as order_date,
         v.daily_revenue,
         v.total_transactions,
         v.total_weight_kg
    from d
    left join vw_daily_revenue_7days v
      on v.order_date = date_format(d.dt, '%Y-%m-%d')
   order by d.dt asc`;

// SUM() kembali sebagai string desimal ("28000"), dan grafik butuh angka.
// Number(null) === 0, jadi hari tanpa transaksi tidak perlu coalesce di SQL.
const num = (v) => Number(v);

// GET /api/dashboard/summary — kasir
async function summary(req, res) {
  const [[kartu]] = await pool.query('select * from vw_dashboard_summary');
  const [tren] = await pool.query(REVENUE_7_DAYS);

  return ok(res, {
    today_revenue: num(kartu.today_revenue),
    active_orders: num(kartu.active_orders),
    ready_orders: num(kartu.ready_orders),
    available_machines: num(kartu.available_machines),
    total_operational_machines: num(kartu.total_operational_machines),
    revenue_7_days: tren.map((r) => ({
      order_date: r.order_date,
      daily_revenue: num(r.daily_revenue),
      total_transactions: num(r.total_transactions),
      total_weight_kg: num(r.total_weight_kg),
    })),
  }, 'Ringkasan dashboard.');
}

module.exports = { summary };
