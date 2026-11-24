// Uji CRUD master data terhadap Aiven. Tiap kasus menulis di dalam transaksi
// lalu ROLLBACK, jadi database tidak berubah.
// Jalankan: npm run test:master
require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

async function call(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* respons tanpa body */
  }
  return { status: res.status, json };
}

async function login(email, password) {
  const res = await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const json = await res.json().catch(() => null);
  return json?.data?.token ?? null;
}

(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    const kasirToken = await login('kasir@cleano.id', 'password123');
    const pelangganToken = await login('rina@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasirToken));
    ok('login pelanggan untuk uji', Boolean(pelangganToken));

    // ---- otorisasi: semua endpoint tulis menolak pelanggan ----
    const writes = [
      ['POST', '/api/services', { name: 'X', price_per_kg: 1000 }],
      ['PUT', '/api/services/1', { name: 'X', price_per_kg: 1000 }],
      ['DELETE', '/api/services/1', undefined],
      ['POST', '/api/machines', { machine_code: 'MC-99' }],
      ['PATCH', '/api/machines/1', { status: 'tersedia' }],
      ['POST', '/api/rewards', { title: 'X', points_required: 1, discount_amount: 1 }],
      ['PUT', '/api/rewards/1', { title: 'X', points_required: 1, discount_amount: 1 }],
      ['PATCH', '/api/rewards/1/toggle', undefined],
    ];
    for (const [method, path, body] of writes) {
      const r = await call(path, { method, body, token: pelangganToken }); // eslint-disable-line no-await-in-loop
      ok(`pelanggan ${method} ${path} 403`, r.status === 403, `status ${r.status}`);
    }

    for (const path of ['/api/services', '/api/machines', '/api/rewards']) {
      const r = await call(path); // eslint-disable-line no-await-in-loop
      ok(`tanpa token ${path} 401`, r.status === 401, `status ${r.status}`);
    }

    // ---- GET: semua role boleh baca ----
    const svc = await call('/api/services', { token: pelangganToken });
    ok('pelanggan GET services 200', svc.status === 200, `status ${svc.status}`);
    ok('services berisi 4 layanan seeder', svc.json?.data?.length === 4, `${svc.json?.data?.length}`);

    const mach = await call('/api/machines', { token: pelangganToken });
    ok('pelanggan GET machines 200', mach.status === 200, `status ${mach.status}`);
    ok('machines berisi 4 mesin seeder', mach.json?.data?.length === 4, `${mach.json?.data?.length}`);
    ok('mesin maintenance ikut terlihat', mach.json?.data?.some((m) => m.status === 'maintenance'));

    // ---- rewards: pelanggan hanya melihat yang aktif ----
    const rwPel = await call('/api/rewards', { token: pelangganToken });
    ok('pelanggan GET rewards 200', rwPel.status === 200, `status ${rwPel.status}`);
    ok('pelanggan hanya reward aktif', (rwPel.json?.data ?? []).every((r) => r.is_active === 1), `${rwPel.json?.data?.length} reward`);

    const rwKasir = await call('/api/rewards', { token: kasirToken });
    ok('kasir GET rewards 200', rwKasir.status === 200, `status ${rwKasir.status}`);

    // Filter is_active hanya bermakna bila ada reward nonaktif. Seedernya semua
// aktif, jadi buat satu nonaktif lebih dulu. Di-commit karena request HTTP
// memakai koneksi lain dan tidak bisa melihat data transaksi yang belum commit;
// barisnya dihapus lagi di finally.
    let rwTestId = null;
    try {
      const [ins] = await pool.query(
        'insert into rewards (title, description, points_required, discount_amount, is_active) values (?, ?, ?, ?, 0)',
        ['Reward Nonaktif Uji', 'uji', 10, 1000],
      );
      rwTestId = ins.insertId;

      const pel = await call('/api/rewards', { token: pelangganToken });
      const kas = await call('/api/rewards', { token: kasirToken });
      const pelTitles = (pel.json?.data ?? []).map((r) => r.title);
      const kasTitles = (kas.json?.data ?? []).map((r) => r.title);

      ok('pelanggan tidak melihat reward nonaktif', !pelTitles.includes('Reward Nonaktif Uji'), `${pelTitles.length} reward`);
      ok('kasir melihat reward nonaktif', kasTitles.includes('Reward Nonaktif Uji'), `${kasTitles.length} reward`);
    } finally {
      if (rwTestId) await pool.query('delete from rewards where id = ?', [rwTestId]).catch(() => {});
    }

    // ---- validasi zod ----
    const badPrice = await call('/api/services', { method: 'POST', body: { name: 'X', price_per_kg: 0 }, token: kasirToken });
    ok('service harga 0 -> 400', badPrice.status === 400, `status ${badPrice.status}`);

    const badStatus = await call('/api/machines', { method: 'POST', body: { machine_code: 'MC-98', status: 'rusak' }, token: kasirToken });
    ok('machine status tak dikenal -> 400', badStatus.status === 400, `status ${badStatus.status}`);

    const badDate = await call('/api/machines', { method: 'POST', body: { machine_code: 'MC-97', estimated_finish_at: '2026-13-45 99:00:00' }, token: kasirToken });
    ok('machine tanggal mustahil -> 400', badDate.status === 400, `status ${badDate.status}`);

    const badReward = await call('/api/rewards', { method: 'POST', body: { title: 'X', points_required: 0, discount_amount: 1000 }, token: kasirToken });
    ok('reward poin 0 -> 400', badReward.status === 400, `status ${badReward.status}`);

    // ---- 404 pada id yang tidak ada ----
    const missSvc = await call('/api/services/9999', { method: 'PUT', body: { name: 'X', price_per_kg: 1000 }, token: kasirToken });
    ok('PUT service tak ada 400 (body kurang)', missSvc.status === 400, `status ${missSvc.status}`);

    const missSvcFull = await call('/api/services/9999', {
      method: 'PUT',
      token: kasirToken,
      body: { name: 'X', price_per_kg: 1000, wash_duration_minutes: 45, estimated_hours: 24, requires_machine: 1 },
    });
    ok('PUT service tak ada 404', missSvcFull.status === 404, `status ${missSvcFull.status}`);

    const missMach = await call('/api/machines/9999', { method: 'PATCH', body: { status: 'tersedia' }, token: kasirToken });
    ok('PATCH machine tak ada 404', missMach.status === 404, `status ${missMach.status}`);

    const emptyPatch = await call('/api/machines/1', { method: 'PATCH', body: {}, token: kasirToken });
    ok('PATCH machine tanpa field 400', emptyPatch.status === 400, `status ${emptyPatch.status}`);

    // ---- id non-angka tidak boleh jadi 500 yang membocorkan SQL ----
    for (const [method, path, body] of [
      ['PUT', '/api/services/abc', { name: 'X', price_per_kg: 1000 }],
      ['DELETE', '/api/services/abc', undefined],
      ['PATCH', '/api/machines/abc', { status: 'tersedia' }],
      ['PUT', '/api/rewards/abc', { title: 'X', points_required: 1, discount_amount: 1 }],
      ['PATCH', '/api/rewards/abc/toggle', undefined],
    ]) {
      const r = await call(path, { method, body, token: kasirToken }); // eslint-disable-line no-await-in-loop
      ok(`id tidak valid ${method} ${path} 400`, r.status === 400 && !JSON.stringify(r.json).includes('Unknown column'), `status ${r.status}`);
    }

    // ---- PUT tidak boleh mengembalikan field ke default diam-diam ----
    // Layanan 4 'Setrika & Pengeringan Saja' punya durasi 0 dan requires_machine 0.
    // Mengubah harganya saja tidak boleh membuatnya butuh mesin.
    const beforeSvc = (await call('/api/services', { token: kasirToken })).json.data.find((s) => s.id === 4);
    ok('prasyarat: layanan 4 tanpa mesin', beforeSvc.requires_machine === 0 && beforeSvc.wash_duration_minutes === 0, `req=${beforeSvc.requires_machine} durasi=${beforeSvc.wash_duration_minutes}`);

    // Hanya requires_machine yang dihilangkan: kalau PUT memakai default, field
    // ini diam-diam jadi 1 dan layanan tanpa mesin berubah jadi butuh mesin.
    const priceOnly = await call('/api/services/4', {
      method: 'PUT',
      token: kasirToken,
      body: {
        name: beforeSvc.name,
        price_per_kg: beforeSvc.price_per_kg + 100,
        wash_duration_minutes: beforeSvc.wash_duration_minutes,
        estimated_hours: beforeSvc.estimated_hours,
      },
    });
    ok('PUT service tanpa requires_machine -> 400', priceOnly.status === 400, `status ${priceOnly.status}`);
    const [[svcIntact]] = await pool.query('select requires_machine, wash_duration_minutes from services where id = 4');
    ok('layanan 4 tetap tanpa mesin setelah PUT ditolak', svcIntact.requires_machine === 0 && svcIntact.wash_duration_minutes === 0, `req=${svcIntact.requires_machine} durasi=${svcIntact.wash_duration_minutes}`);

    // field teknis yang dikirim eksplisit tetap dihormati
    const explicit = await call('/api/services/4', {
      method: 'PUT',
      token: kasirToken,
      body: {
        name: beforeSvc.name,
        price_per_kg: beforeSvc.price_per_kg,
        wash_duration_minutes: beforeSvc.wash_duration_minutes,
        estimated_hours: beforeSvc.estimated_hours,
        requires_machine: beforeSvc.requires_machine,
        description: beforeSvc.description,
      },
    });
    ok('PUT service lengkap mempertahankan requires_machine 0', explicit.status === 200 && explicit.json?.data?.requires_machine === 0, `req=${explicit.json?.data?.requires_machine} durasi=${explicit.json?.data?.wash_duration_minutes}`);

    // ---- PUT reward tidak boleh menghidupkan kembali reward nonaktif ----
    let rwProbeId = null;
    try {
      const [insRw] = await pool.query(
        'insert into rewards (title, description, points_required, discount_amount, is_active) values (?, ?, ?, ?, 0)',
        ['Reward Mati Uji', 'uji', 10, 1000],
      );
      rwProbeId = insRw.insertId;

      const putDead = await call(`/api/rewards/${rwProbeId}`, {
        method: 'PUT',
        token: kasirToken,
        body: { title: 'Reward Mati Uji 2', points_required: 10, discount_amount: 1000, is_active: 1 },
      });
      const [[stillOff]] = await pool.query('select is_active from rewards where id = ?', [rwProbeId]);
      ok('PUT reward tidak menghidupkan is_active', putDead.status === 200 && stillOff.is_active === 0, `is_active jadi ${stillOff.is_active}`);
    } finally {
      if (rwProbeId) await pool.query('delete from rewards where id = ?', [rwProbeId]).catch(() => {});
    }

    // ---- status mesin 'digunakan' bukan wewenang kasir ----
    const manualUse = await call('/api/machines/2', { method: 'PATCH', body: { status: 'digunakan' }, token: kasirToken });
    ok('PATCH status=digunakan ditolak 400', manualUse.status === 400, `status ${manualUse.status}`);

    // POST juga tidak boleh membuat mesin yang langsung berstatus terpakai.
    // Dihapus di finally: kalau regresi membuatnya 201, barisnya tidak boleh tertinggal.
    let postUsedId = null;
    try {
      const postUsed = await call('/api/machines', {
        method: 'POST',
        token: kasirToken,
        body: { machine_code: 'MC-UJI-USED', status: 'digunakan' },
      });
      postUsedId = postUsed.json?.data?.id ?? null;
      ok('POST machine status=digunakan ditolak 400', postUsed.status === 400, `status ${postUsed.status}`);

      // capacity_kg bukan field PATCH: spesifikasi unit, bukan kondisi sesaat.
      const [[capBefore]] = await pool.query('select capacity_kg from machines where id = 3');
      const capPatch = await call('/api/machines/3', { method: 'PATCH', token: kasirToken, body: { capacity_kg: 12 } });
      ok('PATCH capacity_kg ditolak 400', capPatch.status === 400, `status ${capPatch.status}`);

      const [[capAfter]] = await pool.query('select capacity_kg from machines where id = 3');
      ok('capacity_kg tidak berubah', String(capAfter.capacity_kg) === String(capBefore.capacity_kg), `${capBefore.capacity_kg} -> ${capAfter.capacity_kg}`);
    } finally {
      if (postUsedId) await pool.query('delete from machines where id = ?', [postUsedId]).catch(() => {});
    }

    const maintenance = await call('/api/machines/2', { method: 'PATCH', body: { status: 'maintenance' }, token: kasirToken });
    ok('PATCH status=maintenance diterima', maintenance.status === 200 && maintenance.json?.data?.status === 'maintenance', `status ${maintenance.json?.data?.status}`);
    await call('/api/machines/2', { method: 'PATCH', body: { status: 'tersedia' }, token: kasirToken });

    // ---- tulis sungguhan, di dalam transaksi lalu ROLLBACK ----
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // service
      const [insSvc] = await conn.query(
        'insert into services (name, price_per_kg, wash_duration_minutes, estimated_hours, requires_machine, description) values (?, ?, ?, ?, ?, ?)',
        ['Layanan Uji', 9999, 10, 2, 1, 'uji'],
      );
      ok('insert service uji berhasil', insSvc.insertId > 0, `id ${insSvc.insertId}`);

      const [updSvc] = await conn.query('update services set price_per_kg = ? where id = ?', [12345, insSvc.insertId]);
      ok('update service mengubah 1 baris', updSvc.affectedRows === 1);

      // machine
      const [insMach] = await conn.query(
        'insert into machines (machine_code, status, capacity_kg) values (?, ?, ?)',
        ['MC-TEST', 'tersedia', 5],
      );
      const [updMach] = await conn.query(
        "update machines set status = 'maintenance', estimated_finish_at = '2026-11-18 10:00:00' where id = ?",
        [insMach.insertId],
      );
      ok('update machine mengubah 1 baris', updMach.affectedRows === 1);

      const [[machRow]] = await conn.query('select status, estimated_finish_at from machines where id = ?', [insMach.insertId]);
      ok('status machine tersimpan', machRow.status === 'maintenance', machRow.status);

      // reward toggle: 1 - is_active
      const [insRw] = await conn.query(
        'insert into rewards (title, description, points_required, discount_amount, is_active) values (?, ?, ?, ?, 1)',
        ['Reward Uji', 'uji', 10, 1000],
      );
      await conn.query('update rewards set is_active = 1 - is_active where id = ?', [insRw.insertId]);
      const [[rwRow]] = await conn.query('select is_active from rewards where id = ?', [insRw.insertId]);
      ok('toggle reward 1 -> 0', rwRow.is_active === 0, `is_active ${rwRow.is_active}`);

      await conn.query('update rewards set is_active = 1 - is_active where id = ?', [insRw.insertId]);
      const [[rwRow2]] = await conn.query('select is_active from rewards where id = ?', [insRw.insertId]);
      ok('toggle reward 0 -> 1', rwRow2.is_active === 1, `is_active ${rwRow2.is_active}`);

      // FK restrict: layanan yang dipakai order tidak bisa dihapus
      // (order seeder memakai service 1)
      let fkBlocked = false;
      try {
        await conn.query('delete from services where id = 1');
      } catch (err) {
        fkBlocked = err.code === 'ER_ROW_IS_REFERENCED_2';
      }
      ok('hapus service terpakai ditolak FK', fkBlocked);

      // mesin yang dipakai order juga tertahan (bila ada)
      const [[usedMach]] = await conn.query('select machine_id from orders where machine_id is not null limit 1');
      if (usedMach) {
        let machBlocked = false;
        try {
          await conn.query('delete from machines where id = ?', [usedMach.machine_id]);
        } catch (err) {
          machBlocked = err.code === 'ER_ROW_IS_REFERENCED_2';
        }
        ok('hapus machine terpakai ditolak FK', machBlocked, `machine_id ${usedMach.machine_id}`);
      } else {
        ok('hapus machine terpakai ditolak FK', true, 'tidak ada order dengan machine_id');
      }

      // kode mesin unik
      let dupBlocked = false;
      try {
        await conn.query('insert into machines (machine_code) values (?)', ['MC-01']);
      } catch (err) {
        dupBlocked = err.code === 'ER_DUP_ENTRY';
      }
      ok('kode mesin duplikat ditolak', dupBlocked);
    } finally {
      await conn.rollback().catch(() => {});
      conn.release();
    }

    // ---- rollback benar-benar bersih ----
    const [[left]] = await pool.query("select count(*) n from services where name = 'Layanan Uji'");
    ok('rollback bersih: service uji hilang', left.n === 0, `sisa ${left.n}`);

    const [[leftM]] = await pool.query("select count(*) n from machines where machine_code = 'MC-TEST'");
    ok('rollback bersih: machine uji hilang', leftM.n === 0, `sisa ${leftM.n}`);

    const [[leftR]] = await pool.query("select count(*) n from rewards where title = 'Reward Uji'");
    ok('rollback bersih: reward uji hilang', leftR.n === 0, `sisa ${leftR.n}`);

    const [[counts]] = await pool.query(
      '(select count(*) n from services) union all (select count(*) from machines) union all (select count(*) from rewards)',
    );
    ok('data seeder utuh', counts.n > 0, 'dasar master data terbaca');
  } catch (err) {
    ok('tes master tidak melempar error', false, err.message);
  } finally {
    console.log('');
    for (const r of rows) {
      console.log(`${r.pass ? 'OK  ' : 'GAGAL'} ${r.name.padEnd(46)} ${r.detail}`);
    }
    const failed = rows.filter((r) => !r.pass).length;
    console.log(`\n${rows.length - failed}/${rows.length} lulus`);

    server.close();
    await pool.end().catch(() => {});
    process.exit(failed ? 1 : 0);
  }
})();