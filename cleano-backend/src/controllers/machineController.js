'use strict';

const { pool } = require('../config/database');
const { ok, created, badRequest, notFound, conflict } = require('../utils/response');
const { parse, parseId } = require('../utils/validate');
const { machineBody, machinePatchBody } = require('../validators/masterValidator');

const COLS = 'id, machine_code, status, capacity_kg, estimated_finish_at';

// GET /api/machines — semua login
async function list(req, res) {
  const [rows] = await pool.query(`select ${COLS} from machines order by machine_code asc`);
  return ok(res, rows, 'Daftar mesin.');
}

// POST /api/machines — kasir
async function create(req, res) {
  const b = parse(machineBody, req.body);
  try {
    const [result] = await pool.query(
      'insert into machines (machine_code, status, capacity_kg, estimated_finish_at) values (?, ?, ?, ?)',
      [b.machine_code, b.status, b.capacity_kg, b.estimated_finish_at],
    );
    const [rows] = await pool.query(`select ${COLS} from machines where id = ?`, [result.insertId]);
    return created(res, rows[0], 'Mesin dibuat.');
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') throw conflict('Kode mesin sudah dipakai.');
    throw err;
  }
}

// PATCH /api/machines/:id — kasir
// Tidak ada DELETE: mesin dinonaktifkan lewat status = 'maintenance' (PRD).
async function update(req, res) {
  const id = parseId(req.params.id);
  const b = parse(machinePatchBody, req.body);

  const fields = [];
  const values = [];
  if (b.status !== undefined) { fields.push('status = ?'); values.push(b.status); }
  // null berarti mengosongkan, jadi dibedakan dari "tidak dikirim".
  if (b.estimated_finish_at !== undefined) { fields.push('estimated_finish_at = ?'); values.push(b.estimated_finish_at); }

  if (!fields.length) throw badRequest('Tidak ada field yang diubah.');

  const [result] = await pool.query(`update machines set ${fields.join(', ')} where id = ?`, [...values, id]);
  if (!result.affectedRows) throw notFound('Mesin tidak ditemukan.');

  const [rows] = await pool.query(`select ${COLS} from machines where id = ?`, [id]);
  return ok(res, rows[0], 'Mesin diperbarui.');
}

module.exports = { list, create, update };