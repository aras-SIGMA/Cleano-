'use strict';

const { pool } = require('../config/database');
const { ok } = require('../utils/response');

// Hitung 7 hari terakhir di MySQL (+07:00) memakai recursive CTE.
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

// Konversi SUM() string ke angka; Number(null) otomatis bernilai 0.
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
