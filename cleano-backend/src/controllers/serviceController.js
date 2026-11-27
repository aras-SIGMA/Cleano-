'use strict';

const { pool } = require('../config/database');
const { ok, created, notFound, conflict } = require('../utils/response');
const { parse, parseId } = require('../utils/validate');
const { serviceCreateBody, servicePutBody } = require('../validators/masterValidator');

const COLS = 'id, name, price_per_kg, wash_duration_minutes, estimated_hours, requires_machine, description, created_at';

// GET /api/services — semua login
async function list(req, res) {
  const [rows] = await pool.query(`select ${COLS} from services order by id asc`);
  return ok(res, rows, 'Daftar layanan.');
}

// POST /api/services — kasir
async function create(req, res) {
  const b = parse(serviceCreateBody, req.body);
  const [result] = await pool.query(
    `insert into services (name, price_per_kg, wash_duration_minutes, estimated_hours, requires_machine, description)
     values (?, ?, ?, ?, ?, ?)`,
    [b.name, b.price_per_kg, b.wash_duration_minutes, b.estimated_hours, b.requires_machine, b.description],
  );
  const [rows] = await pool.query(`select ${COLS} from services where id = ?`, [result.insertId]);
  return created(res, rows[0], 'Layanan dibuat.');
}

// PUT /api/services/:id: semua field wajib agar nilai lama tidak tertimpa.
async function update(req, res) {
  const id = parseId(req.params.id);
  const b = parse(servicePutBody, req.body);
  const [result] = await pool.query(
    `update services
        set name = ?, price_per_kg = ?, wash_duration_minutes = ?, estimated_hours = ?, requires_machine = ?, description = ?
      where id = ?`,
    [b.name, b.price_per_kg, b.wash_duration_minutes, b.estimated_hours, b.requires_machine, b.description, id],
  );
  if (!result.affectedRows) throw notFound('Layanan tidak ditemukan.');
  const [rows] = await pool.query(`select ${COLS} from services where id = ?`, [id]);
  return ok(res, rows[0], 'Layanan diperbarui.');
}

// DELETE /api/services/:id: tolak hapus layanan yang dipakai order (FK restrict).
async function remove(req, res) {
  const id = parseId(req.params.id);
  try {
    const [result] = await pool.query('delete from services where id = ?', [id]);
    if (!result.affectedRows) throw notFound('Layanan tidak ditemukan.');
  } catch (err) {
    if (err.code === 'ER_ROW_IS_REFERENCED_2') {
      throw conflict('Layanan sudah dipakai pada order sehingga tidak bisa dihapus. Ubah lewat PUT bila perlu.');
    }
    throw err;
  }
  return ok(res, { id }, 'Layanan dihapus.');
}

module.exports = { list, create, update, remove };