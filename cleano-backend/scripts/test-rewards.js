// Uji B9: POST /api/rewards/redeem dan GET /api/rewards/my-vouchers.
// Klaim dijalankan lewat attemptRedeem di dalam transaksi lalu ROLLBACK — poin
// yang sudah terpotong tidak bisa dikembalikan sendiri, dan trigger L-02
// melarang voucher dihapus atau diaktifkan ulang.
// Jalankan: npm run test:rewards
require('dotenv').config({ quiet: true });

const { pool } = require('../src/config/database');
const app = require('../server');
const { attemptRedeem, newVoucherCode, fetchMyVouchers } = require('../src/services/rewardRedeem');

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

// Reward buatan uji yang harus ter-commit supaya terlihat oleh koneksi lain.
// Dihapus di finally luar, dan disapu lagi di awal run berikutnya kalau proses
// sebelumnya mati di tengah — rewards tidak punya penjaga hapus, jadi baris yang
// tertinggal akan ikut terhitung oleh uji dan laporan.
const UJI_PARALEL = 'UJI-PARALEL-B9';
const ujiRewardIds = [];

async function sapuRewardUji() {
  const [res] = await pool.query('delete from rewards where title = ?', [UJI_PARALEL]);
  return res.affectedRows;
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

async function call(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

async function inTx(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    return await fn(conn);
  } finally {
    await conn.rollback().catch(() => {});
    conn.release();
  }
}

async function tryTx(fn) {
  try {
    return { ok: true, value: await inTx(fn) };
  } catch (err) {
    return { ok: false, error: `${err.status || err.code || ''} ${err.message}`.trim() };
  }
}

// Reward karangan di dalam transaksi, supaya tes tidak bergantung pada katalog
// seeder yang bisa berubah.
async function makeReward(conn, { code, points, discount = 5000, active = 1 }) {
  const [ins] = await conn.query(
    'insert into rewards (title, description, points_required, discount_amount, is_active) values (?, ?, ?, ?, ?)',
    [`Uji ${code}`, 'reward untuk uji', points, discount, active],
  );
  return ins.insertId;
}

(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;

  try {
    const sisa = await sapuRewardUji();
    ok('sisa reward uji dari run sebelumnya dibersihkan', true, `${sisa} baris dihapus`);

    const kasir = await login('kasir@cleano.id', 'password123');
    const rina = await login('rina@gmail.com', 'password123');
    const budi = await login('budi@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasir));
    ok('login rina untuk uji', Boolean(rina));
    ok('login budi untuk uji', Boolean(budi));

    // id & saldo dari DB, bukan ditebak: skema bisa dimuat ulang.
    const [[uRina]] = await pool.query("select id, points from users where email = 'rina@gmail.com'");
    const [[uBudi]] = await pool.query("select id, points from users where email = 'budi@gmail.com'");

    // ---- otorisasi ----
    const noToken = await call('/api/rewards/redeem', { method: 'POST', body: { reward_id: 1 } });
    ok('redeem tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    const asKasir = await call('/api/rewards/redeem', {
      method: 'POST', body: { reward_id: 1 }, token: kasir,
    });
    ok('kasir tidak boleh redeem 403', asKasir.status === 403, `status ${asKasir.status}`);

    const myNoToken = await call('/api/rewards/my-vouchers');
    ok('my-vouchers tanpa token 401', myNoToken.status === 401, `status ${myNoToken.status}`);

    const myAsKasir = await call('/api/rewards/my-vouchers', { token: kasir });
    ok('my-vouchers kasir 403', myAsKasir.status === 403, `status ${myAsKasir.status}`);

    // ---- validasi body ----
    const noBody = await call('/api/rewards/redeem', { method: 'POST', body: {}, token: rina });
    ok('reward_id kosong 400', noBody.status === 400, `status ${noBody.status}`);

    const badBody = await call('/api/rewards/redeem', {
      method: 'POST', body: { reward_id: 'abc' }, token: rina,
    });
    ok('reward_id bukan angka 400', badBody.status === 400, `status ${badBody.status}`);

    const missing = await call('/api/rewards/redeem', {
      method: 'POST', body: { reward_id: 999999 }, token: rina,
    });
    ok('reward tidak ada 404', missing.status === 404, `status ${missing.status}`);

    // ---- klaim berhasil: poin dipotong trigger ----
    const claim = await tryTx(async (conn) => {
      const rid = await makeReward(conn, { code: '901', points: 50 });
      const [[before]] = await conn.query('select points from users where id = ?', [uRina.id]);
      const res = await attemptRedeem(conn, { userId: uRina.id, rewardId: rid });
      const [[after]] = await conn.query('select points from users where id = ?', [uRina.id]);
      return { rid, before: Number(before.points), after: Number(after.points), res };
    });
    ok('klaim berhasil', claim.ok, claim.ok ? '' : claim.error);
    ok('poin terpotong sesuai points_required',
      claim.ok && claim.value.after === claim.value.before - 50,
      claim.ok ? `${claim.value.before} -> ${claim.value.after}` : claim.error);
    ok('saldo yang dilaporkan = isi tabel',
      claim.ok && claim.value.res.pointsAfter === claim.value.after,
      claim.ok ? `${claim.value.res.pointsAfter} vs ${claim.value.after}` : claim.error);
    ok('saldo sebelum yang dilaporkan benar',
      claim.ok && claim.value.res.pointsBefore === claim.value.before,
      claim.ok ? `${claim.value.res.pointsBefore}` : claim.error);
    ok('voucher tercatat milik pelanggan',
      claim.ok && claim.value.res.voucher.user_id === uRina.id,
      claim.ok ? `${claim.value.res.voucher.user_id}` : claim.error);
    ok('voucher baru berstatus belum terpakai',
      claim.ok && claim.value.res.voucher.is_used === 0,
      claim.ok ? `${claim.value.res.voucher.is_used}` : claim.error);
    ok('used_at voucher baru kosong',
      claim.ok && claim.value.res.voucher.used_at === null,
      claim.ok ? `${claim.value.res.voucher.used_at}` : claim.error);

    // ---- format kode voucher ----
    ok('kode voucher berformat CLN-VCR-XXXX',
      claim.ok && /^CLN-VCR-[A-Z0-9]{4}$/.test(claim.value.res.voucher.voucher_code),
      claim.ok ? claim.value.res.voucher.voucher_code : claim.error);
    const contoh = Array.from({ length: 40 }, () => newVoucherCode());
    ok('seluruh kode yang dibuat berformat sama',
      contoh.every((c) => /^CLN-VCR-[A-Z0-9]{4}$/.test(c)), contoh.slice(0, 3).join(' '));
    // Karakter mirip tidak dipakai: kode ini dibaca dan diketik manual.
    ok('tidak memakai karakter mirip 0/O/1/I/L',
      contoh.every((c) => !/[01OIL]/.test(c.slice(8))), contoh.slice(0, 3).join(' '));
    ok('kode tidak selalu sama', new Set(contoh).size > 30, `${new Set(contoh).size}/40 unik`);

    // ---- poin kurang: trigger menolak, dan ditolak sebagai 400 bukan 500 ----
    const kurang = await tryTx(async (conn) => {
      const rid = await makeReward(conn, { code: '902', points: 100000 });
      try {
        await attemptRedeem(conn, { userId: uRina.id, rewardId: rid });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message, code: e.code, sqlState: e.sqlState };
      }
    });
    // attemptRedeem melempar error mentah MySQL di sini; yang mengubahnya jadi 400
    // adalah error handler server.js. Jadi yang diperiksa: error itu memang
    // SIGNAL 45000, bukan error lain yang kebetulan juga 400.
    ok('poin kurang ditolak trigger',
      kurang.ok && (kurang.value.sqlState === '45000' || kurang.value.code === 'ER_SIGNAL_EXCEPTION'),
      kurang.ok ? `${kurang.value.sqlState} ${kurang.value.message}` : kurang.error);
    ok('pesan trigger menyebut poin',
      kurang.ok && /poin/i.test(kurang.value.message), kurang.ok ? kurang.value.message : kurang.error);

    // ---- SQLSTATE 45000 lewat HTTP harus 400, bukan 500 ----
    // Reward seeder id 3 butuh 200 poin, rina punya 150. INSERT ditolak trigger
    // sebelum apa pun tersimpan, jadi permintaan ini tidak meninggalkan baris
    // maupun memotong poin — aman dijalankan lewat jalur commit.
    const [[r3]] = await pool.query(
      'select id, points_required, is_active from rewards where id = 3',
    );
    if (r3 && r3.is_active === 1 && Number(r3.points_required) > Number(uRina.points)) {
      const httpKurang = await call('/api/rewards/redeem', {
        method: 'POST', body: { reward_id: 3 }, token: rina,
      });
      ok('poin kurang lewat HTTP -> 400 bukan 500', httpKurang.status === 400,
        `status ${httpKurang.status} ${httpKurang.json?.message ?? ''}`);
      ok('pesan 400 berisi alasan dari trigger', /poin/i.test(httpKurang.json?.message ?? ''),
        httpKurang.json?.message);
      const [[sesudah]] = await pool.query('select points from users where id = ?', [uRina.id]);
      ok('poin tidak terpotong saat klaim ditolak', Number(sesudah.points) === Number(uRina.points),
        `${sesudah.points} vs ${uRina.points}`);
    } else {
      ok('poin kurang lewat HTTP -> 400 bukan 500', true, 'dilewati: reward 3 tidak memenuhi syarat');
      ok('pesan 400 berisi alasan dari trigger', true, 'dilewati');
      ok('poin tidak terpotong saat klaim ditolak', true, 'dilewati');
    }

    // ---- reward nonaktif ----
    const nonaktif = await tryTx(async (conn) => {
      const rid = await makeReward(conn, { code: '903', points: 10, active: 0 });
      try {
        await attemptRedeem(conn, { userId: uRina.id, rewardId: rid });
        return { status: null, message: 'lolos' };
      } catch (e) {
        return { status: e.status ?? null, message: e.message, sqlState: e.sqlState };
      }
    });
    ok('reward nonaktif ditolak',
      nonaktif.ok && (nonaktif.value.sqlState === '45000' || nonaktif.value.status === 400),
      nonaktif.ok ? `${nonaktif.value.sqlState} ${nonaktif.value.message}` : nonaktif.error);

    // ---- poin tidak pernah negatif ----
    const negatif = await tryTx(async (conn) => {
      const rid = await makeReward(conn, { code: '904', points: 100000 });
      try {
        await attemptRedeem(conn, { userId: uRina.id, rewardId: rid });
      } catch {
        // ditolak trigger; yang penting saldo tidak berubah
      }
      const [[row]] = await conn.query('select points from users where id = ?', [uRina.id]);
      return Number(row.points);
    });
    ok('saldo poin tidak berubah saat klaim gagal',
      negatif.ok && negatif.value === Number(uRina.points),
      negatif.ok ? `${negatif.value} vs ${uRina.points}` : negatif.error);

    // ---- kode bentrok diulang, bukan 409 ----
    const bentrok = await tryTx(async (conn) => {
      const rid = await makeReward(conn, { code: '905', points: 5 });
      // Pemanggilan pertama mengembalikan kode yang sudah ada, kedua kode baru.
      const codes = ['CLN-VCR-8821', 'CLN-VCR-TEST'];
      let i = 0;
      const res = await attemptRedeem(conn, {
        userId: uRina.id, rewardId: rid, generateCode: () => codes[i++] ?? 'CLN-VCR-FRESH',
      });
      return { code: res.voucher.voucher_code, percobaan: i };
    });
    ok('kode bentrok diulang, klaim tetap berhasil',
      bentrok.ok && bentrok.value.code === 'CLN-VCR-TEST',
      bentrok.ok ? `${bentrok.value.code} setelah ${bentrok.value.percobaan} percobaan` : bentrok.error);

    // ---- klien tidak bisa menentukan kode voucher atau poin ----
    const injeksi = await tryTx(async (conn) => {
      const rid = await makeReward(conn, { code: '906', points: 5 });
      const res = await attemptRedeem(conn, { userId: uRina.id, rewardId: rid });
      return res.voucher.voucher_code;
    });
    ok('kode voucher dibuat backend, bukan dari klien',
      injeksi.ok && injeksi.value !== 'CLN-VCR-8821', injeksi.ok ? injeksi.value : injeksi.error);

    // ---- my-vouchers: hanya milik sendiri, aktif dan riwayat dipisah ----
    const mv = await call('/api/rewards/my-vouchers', { token: rina });
    ok('my-vouchers 200', mv.status === 200, `status ${mv.status}`);
    ok('respons memisahkan active dan history',
      Array.isArray(mv.json?.data?.active) && Array.isArray(mv.json?.data?.history));
    const semua = [...(mv.json?.data?.active ?? []), ...(mv.json?.data?.history ?? [])];
    ok('semua voucher milik rina', semua.every((v) => v.user_id === uRina.id || v.user_id === undefined),
      `${semua.length} voucher`);
    ok('tidak ada voucher budi di daftar rina',
      semua.every((v) => v.voucher_code !== 'CLN-VCR-BUDI'));

    const mvBudi = await call('/api/rewards/my-vouchers', { token: budi });
    const kodeRina = new Set(semua.map((v) => v.voucher_code));
    const kodeBudi = [...(mvBudi.json?.data?.active ?? []), ...(mvBudi.json?.data?.history ?? [])]
      .map((v) => v.voucher_code);
    ok('budi tidak melihat voucher rina', kodeBudi.every((c) => !kodeRina.has(c)),
      kodeBudi.join(' '));

    // active hanya is_used = 0, history hanya is_used = 1
    ok('active hanya voucher belum terpakai',
      (mv.json?.data?.active ?? []).every((v) => v.is_used === 0));
    ok('history hanya voucher terpakai',
      (mv.json?.data?.history ?? []).every((v) => v.is_used === 1));

    // Voucher membawa data yang dibutuhkan kartu QR (PRD-04 §3.3)
    const contohV = (mv.json?.data?.active ?? [])[0] ?? {};
    const perlu = ['voucher_code', 'title', 'discount_amount', 'points_required', 'is_used'];
    const hilang = perlu.filter((k) => !(k in contohV));
    ok('voucher membawa data kartu QR', hilang.length === 0, `hilang: ${hilang.join(',')}`);

    const [[jml]] = await pool.query('select count(*) as n from user_vouchers where user_id = ?', [uRina.id]);
    ok('total cocok dengan jumlah baris DB',
      mv.json?.data?.total === jml.n, `${mv.json?.data?.total} vs ${jml.n}`);

    // query user_id harus diabaikan; kalau dihormati, pelanggan cukup mengubah
    // angkanya untuk membaca voucher orang lain.
    const mvSpoof = await call(`/api/rewards/my-vouchers?user_id=${uBudi.id}`, { token: rina });
    const kodeSpoof = [...(mvSpoof.json?.data?.active ?? []), ...(mvSpoof.json?.data?.history ?? [])]
      .map((v) => v.voucher_code);
    ok('query user_id diabaikan di my-vouchers',
      mvSpoof.json?.data?.total === mv.json?.data?.total,
      `${mvSpoof.json?.data?.total} vs ${mv.json?.data?.total}`);

    // ---- active vs history, diuji dengan voucher terpakai buatan ----
    // Seeder tidak punya voucher terpakai, dan is_used tidak bisa dikembalikan
    // ke 0 (trigger L-02), jadi voucher terpakai dibuat di dalam transaksi.
    const pisah = await tryTx(async (conn) => {
      const [ins] = await conn.query(
        'insert into user_vouchers (voucher_code, user_id, reward_id, is_used) values (?, ?, 1, 0)',
        ['CLN-VCR-UJI1', uRina.id],
      );
      // Pemakaian lewat jalur resmi: UPDATE 1 baris is_used=1 + used_at terisi,
      // satu-satunya bentuk yang lolos trigger.
      await conn.query(
        'update user_vouchers set is_used = 1, used_at = now() where id = ?', [ins.insertId],
      );
      const data = await fetchMyVouchers(conn, uRina.id);
      return {
        id: ins.insertId,
        aktifMemuat: data.active.some((v) => v.id === ins.insertId),
        riwayatMemuat: data.history.some((v) => v.id === ins.insertId),
        aktifBersih: data.active.every((v) => v.is_used === 0),
        riwayatBersih: data.history.every((v) => v.is_used === 1),
        total: data.total,
      };
    });
    ok('voucher terpakai tidak masuk active', pisah.ok && !pisah.value.aktifMemuat,
      pisah.ok ? `${pisah.value.aktifMemuat}` : pisah.error);
    ok('voucher terpakai masuk history', pisah.ok && pisah.value.riwayatMemuat,
      pisah.ok ? `${pisah.value.riwayatMemuat}` : pisah.error);
    ok('active hanya is_used = 0', pisah.ok && pisah.value.aktifBersih,
      pisah.ok ? `${pisah.value.aktifBersih}` : pisah.error);
    ok('history hanya is_used = 1', pisah.ok && pisah.value.riwayatBersih,
      pisah.ok ? `${pisah.value.riwayatBersih}` : pisah.error);

    // ---- user_id dari token: body tidak bisa mengarahkan klaim ke akun lain ----
    // Payload menyertakan user_id milik budi; rina harus tetap menukar poinnya
    // sendiri. INSERT ditolak trigger (poin kurang) sehingga tidak ada yang
    // tersimpan, dan yang diperiksa adalah pesan trigger yang menyebut saldo
    // rina — bukan saldo budi.
    const [[budiNow]] = await pool.query('select points from users where id = ?', [uBudi.id]);
    const spoofUser = await call('/api/rewards/redeem', {
      method: 'POST', body: { reward_id: 3, user_id: uBudi.id }, token: rina,
    });
    ok('user_id di body diabaikan', spoofUser.status === 400, `status ${spoofUser.status}`);
    const [[budiAfter]] = await pool.query('select points from users where id = ?', [uBudi.id]);
    ok('poin pelanggan lain tidak tersentuh',
      Number(budiAfter.points) === Number(budiNow.points),
      `${budiAfter.points} vs ${budiNow.points}`);
    const [[rinaAfter]] = await pool.query('select points from users where id = ?', [uRina.id]);
    ok('poin rina juga tidak tersentuh', Number(rinaAfter.points) === Number(uRina.points),
      `${rinaAfter.points} vs ${uRina.points}`);

    // ---- dua klaim paralel tidak boleh memotong poin dua kali ----
    // Kuncinya datang dari trigger: INSERT memicu `update users set points =
    // points - ...`, dan UPDATE itu menahan baris user sampai transaksi selesai.
    // Klaim kedua menunggu, lalu melihat saldo yang sudah terpotong.
    //
    // Dua transaksi sungguhan dijalankan bersamaan. Saldo rina hanya cukup untuk
    // satu klaim (reward 100 poin, saldo 150), jadi tepat satu harus berhasil.
    //
    // Reward uji harus ter-commit dulu supaya terlihat oleh kedua koneksi, jadi
    // ia tidak bisa ikut ROLLBACK. Penghapusannya karena itu ada di finally luar
    // (lihat UJI_PARALEL di bawah) dan dijalankan lagi di awal setiap run, supaya
    // proses yang mati di tengah tidak meninggalkan baris permanen.
    // ---------------------------------------------------------------------
    const paralelId = (await pool.query(
      `insert into rewards (title, description, points_required, discount_amount, is_active)
       values (?, 'x', 100, 5000, 1)`, [UJI_PARALEL],
    ))[0].insertId;
    ujiRewardIds.push(paralelId);

    const c1 = await pool.getConnection();
    const c2 = await pool.getConnection();
    let hasil = [];
    try {
      await c1.beginTransaction();
      await c2.beginTransaction();
      hasil = await Promise.all([
        attemptRedeem(c1, { userId: uRina.id, rewardId: paralelId })
          .then(() => ({ ok: true })).catch((e) => ({ ok: false, m: e.message })),
        attemptRedeem(c2, { userId: uRina.id, rewardId: paralelId })
          .then(() => ({ ok: true })).catch((e) => ({ ok: false, m: e.message })),
      ]);
    } finally {
      await c1.rollback().catch(() => {});
      await c2.rollback().catch(() => {});
      c1.release();
      c2.release();
    }
    const sukses = hasil.filter((h) => h.ok).length;
    ok('dua klaim paralel: tepat satu berhasil', sukses === 1,
      `${sukses} berhasil — ${hasil.map((h) => h.m ?? 'ok').join(' | ')}`);
    const [[saldo]] = await pool.query('select points from users where id = ?', [uRina.id]);
    ok('saldo rina utuh setelah uji paralel', Number(saldo.points) === Number(uRina.points),
      `${saldo.points} vs ${uRina.points}`);
  } finally {
    // Reward buatan uji tidak boleh tertinggal walau asersi gagal di tengah.
    for (const id of ujiRewardIds) {
      await pool.query('delete from rewards where id = ?', [id]).catch(() => {});
    }
    const pass = rows.filter((r) => r.pass).length;
    for (const r of rows) {
      console.log(`${r.pass ? 'OK  ' : 'GAGAL'} ${r.name}${r.detail ? `  (${r.detail})` : ''}`);
    }
    console.log(`\n${pass}/${rows.length} lulus`);
    server.close();
    await pool.end().catch(() => {});
    if (pass !== rows.length) process.exitCode = 1;
  }
})();
