'use strict';

// Pusatkan aturan alokasi mesin agar create-order dan confirm-relay selalu konsisten.

// Kunci satu mesin 'tersedia' dalam transaksi memakai FOR UPDATE.
async function allocateMachine(conn, durationMinutes) {
  const [rows] = await conn.query(
    "select id from machines where status = 'tersedia' order by id asc limit 1 for update",
  );
  const machine = rows[0];
  if (!machine) return null;

  const minutes = Number(durationMinutes) || 0;
  await conn.query(
    "update machines set status = 'digunakan', estimated_finish_at = date_add(now(), interval ? minute) where id = ?",
    [minutes, machine.id],
  );
  return machine.id;
}

// Hitung estimasi tunggu dari mesin tercepat selesai dengan coalesce 0.
async function estimateQueueWait(conn) {
  const [[row]] = await conn.query(
    "select min(coalesce(estimated_finish_at, now())) as earliest from machines where status = 'digunakan'",
  );
  if (!row.earliest) return 0;
  const [[diff]] = await conn.query('select timestampdiff(minute, now(), ?) as minutes', [row.earliest]);
  return Math.max(0, Number(diff.minutes) || 0);
}

module.exports = { allocateMachine, estimateQueueWait };
