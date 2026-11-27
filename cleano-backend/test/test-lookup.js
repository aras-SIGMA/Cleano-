// Uji lookup, /me, dan /me/avatar terhadap Aiven; jalankan npm run test:lookup.
require('dotenv').config({ quiet: true });

const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { pool } = require('../src/config/database');
const app = require('../server');
const { uploadDir } = require('../src/middlewares/uploadMiddleware');

const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
  'base64',
);

const rows = [];
const ok = (name, pass, detail = '') => rows.push({ name, pass, detail });

let server;
let base;

async function call(path, { token } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, { headers });
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
    // kata sandi seeder: lihat database_schema.sql bagian data seeder
    const kasirToken = await login('kasir@cleano.id', 'password123');
    const pelangganToken = await login('rina@gmail.com', 'password123');
    ok('login kasir untuk uji', Boolean(kasirToken));
    ok('login pelanggan untuk uji', Boolean(pelangganToken));

    // ---- otorisasi ----
    const noToken = await call('/api/users/lookup?query=MBR-0001');
    ok('tanpa token 401', noToken.status === 401, `status ${noToken.status}`);

    const asPelanggan = await call('/api/users/lookup?query=MBR-0002', { token: pelangganToken });
    ok('token pelanggan 403 (TC-04)', asPelanggan.status === 403, `status ${asPelanggan.status}`);

    const badToken = await call('/api/users/lookup?query=MBR-0001', { token: 'bukan.token.asli' });
    ok('token palsu 401', badToken.status === 401, `status ${badToken.status}`);

    // ---- validasi ----
    const empty = await call('/api/users/lookup?query=', { token: kasirToken });
    ok('query kosong 400', empty.status === 400, `status ${empty.status}`);

    const noParam = await call('/api/users/lookup', { token: kasirToken });
    ok('tanpa parameter 400', noParam.status === 400, `status ${noParam.status}`);

    const space = await call('/api/users/lookup?query=%20%20', { token: kasirToken });
    ok('query hanya spasi 400', space.status === 400, `status ${space.status}`);

    // Pastikan query lookup terlalu panjang ditolak sebelum menyentuh database.
    const longQuery = await call(`/api/users/lookup?query=${'A'.repeat(31)}`, { token: kasirToken });
    ok('query 31 karakter 400', longQuery.status === 400, `status ${longQuery.status}`);

    const missing = await call('/api/users/lookup?query=MBR-9999', { token: kasirToken });
    ok('member tak ada 404', missing.status === 404, `status ${missing.status}`);

    // Uji dual lookup: kode member dan nomor HP menemukan pelanggan sama.
    const byCode = await call('/api/users/lookup?query=MBR-0001', { token: kasirToken });
    ok('cari via member_code 200', byCode.status === 200, `status ${byCode.status}`);

    const byPhone = await call('/api/users/lookup?query=081234567890', { token: kasirToken });
    ok('cari via nomor HP 200 (TC-11)', byPhone.status === 200, `status ${byPhone.status}`);

    ok(
      'kode dan nomor HP mengembalikan orang sama',
      byCode.json?.data?.id === byPhone.json?.data?.id && byCode.json?.data?.id === 2,
      `id ${byCode.json?.data?.id} vs ${byPhone.json?.data?.id}`,
    );

    const lower = await call('/api/users/lookup?query=mbr-0001', { token: kasirToken });
    ok('member_code case-insensitive', lower.json?.data?.id === 2, `id ${lower.json?.data?.id}`);

    const dashed = await call('/api/users/lookup?query=0812-3456-7890', { token: kasirToken });
    ok('nomor HP dengan tanda hubung', dashed.json?.data?.id === 2, `id ${dashed.json?.data?.id}`);

    // Uji normalisasi awalan WhatsApp (+62 dan 62) menemukan nomor 08xx.
    const plus62 = await call('/api/users/lookup?query=%2B6281234567890', { token: kasirToken });
    ok('nomor +62 menemukan pelanggan', plus62.json?.data?.id === 2,
      `status ${plus62.status} id ${plus62.json?.data?.id}`);

    const bare62 = await call('/api/users/lookup?query=6281234567890', { token: kasirToken });
    ok('nomor 62 tanpa plus menemukan pelanggan', bare62.json?.data?.id === 2,
      `status ${bare62.status} id ${bare62.json?.data?.id}`);

    // ---- bentuk respons ----
    const d = byCode.json?.data ?? {};
    ok('data berisi field wajib', ['id', 'name', 'phone', 'member_code', 'points', 'tier', 'vouchers'].every((k) => k in d), Object.keys(d).join(','));
    ok('nama benar', d.name === 'Rina Marlina', d.name);
    ok('tier dari poin', d.tier === 'Gold', `poin=${d.points} tier=${d.tier}`);
    ok('tidak membocorkan email', d.email === undefined);
    ok('tidak membocorkan password', d.password === undefined && !JSON.stringify(byCode.json).includes('$2b$'));

    // ---- voucher aktif ----
    ok('vouchers berupa array', Array.isArray(d.vouchers), typeof d.vouchers);
    ok('rina punya 1 voucher aktif', d.vouchers?.length === 1, `${d.vouchers?.length}`);

    const v = d.vouchers?.[0] ?? {};
    ok('voucher berisi kode & judul', Boolean(v.voucher_code) && Boolean(v.title), `${v.voucher_code} / ${v.title}`);
    ok('voucher berisi discount_amount', typeof v.discount_amount === 'number' && v.discount_amount > 0, `${v.discount_amount}`);
    ok('voucher tidak membocorkan is_used/user_id', v.is_used === undefined && v.user_id === undefined);

    // ---- pelanggan tanpa voucher ----
    const budi = await call('/api/users/lookup?query=MBR-0002', { token: kasirToken });
    ok('budi tanpa voucher -> array kosong', Array.isArray(budi.json?.data?.vouchers) && budi.json.data.vouchers.length === 0, `${budi.json?.data?.vouchers?.length}`);

    // Uji GET /api/users/me membaca poin dan tier terbaru dari database.
    const meNoToken = await call('/api/users/me');
    ok('me tanpa token 401', meNoToken.status === 401, `status ${meNoToken.status}`);

    const mePelanggan = await call('/api/users/me', { token: pelangganToken });
    ok('me pelanggan 200', mePelanggan.status === 200, `status ${mePelanggan.status}`);
    const me = mePelanggan.json?.data ?? {};
    ok('me mengembalikan pengguna yang login', me.id === 2, `id ${me.id}`);
    ok('me berisi poin terbaru', me.points === 150, `poin ${me.points}`);
    ok('me berisi tier dari poin', me.tier === 'Gold', `tier ${me.tier}`);
    ok('me berisi member_code', me.member_code === 'MBR-0001', `${me.member_code}`);
    ok('me tidak membocorkan password', me.password === undefined
      && !JSON.stringify(mePelanggan.json).includes('$2b$'));

    // Kasir juga perlu membaca profilnya sendiri; endpoint ini tanpa checkRole.
    const meKasir = await call('/api/users/me', { token: kasirToken });
    ok('me kasir 200 (tanpa batas role)', meKasir.status === 200, `status ${meKasir.status}`);
    ok('me kasir role kasir', meKasir.json?.data?.role === 'kasir', `${meKasir.json?.data?.role}`);

    // Pastikan perubahan poin langsung terbaca dari /me tanpa login ulang.
    const [[poinAsli]] = await pool.query('select points from users where id = 2');
    try {
      await pool.query('update users set points = 320 where id = 2');
      const meBaru = await call('/api/users/me', { token: pelangganToken });
      ok('me membaca poin terkini, bukan dari token', meBaru.json?.data?.points === 320,
        `poin ${meBaru.json?.data?.points}`);
      ok('tier ikut naik jadi Platinum', meBaru.json?.data?.tier === 'Platinum',
        `tier ${meBaru.json?.data?.tier}`);
    } finally {
      await pool.query('update users set points = ? where id = 2', [poinAsli.points]);
    }
    const [[poinPulih]] = await pool.query('select points from users where id = 2');
    ok('poin rina dikembalikan', poinPulih.points === poinAsli.points, `poin ${poinPulih.points}`);

    // ---- akun kasir tidak muncul di lookup ----
    const staff = await call('/api/users/lookup?query=STF-0001', { token: kasirToken });
    ok('kode staf 404 (hanya pelanggan)', staff.status === 404, `status ${staff.status}`);

    const staffPhone = await call('/api/users/lookup?query=081200000001', { token: kasirToken });
    ok('nomor staf 404 (hanya pelanggan)', staffPhone.status === 404, `status ${staffPhone.status}`);

    // Uji R-5: voucher terpakai (is_used=1) tersaring keluar dari daftar aktif.
    const tmpEmail = `vcr.${Date.now()}@cleano.test`;
    const tmpCode = `TST-${Date.now().toString().slice(-6)}`; // bukan MBR-%: jangan ganggu penomoran
    const [tmp] = await pool.query(
      "insert into users (name, email, password, role, phone, member_code, points) values ('Uji Voucher', ?, '-', 'pelanggan', ?, ?, 200)",
      [tmpEmail, `0895${Date.now().toString().slice(-8)}`, tmpCode],
    );
    const tmpId = tmp.insertId;
    const voucherCode = `CLN-TST-${Date.now().toString().slice(-8)}`;

    // Ambil reward aktif dari DB agar tes kebal perubahan data seeder.
    const [[reward]] = await pool.query(
      'select id from rewards where is_active = 1 order by id limit 1',
    );

    try {
      await pool.query(
        'insert into user_vouchers (voucher_code, user_id, reward_id, is_used) values (?, ?, ?, 0)',
        [voucherCode, tmpId, reward.id],
      );

      const withActive = await call(`/api/users/lookup?query=${tmpCode}`, { token: kasirToken });
      const activeCodes = (withActive.json?.data?.vouchers ?? []).map((x) => x.voucher_code);
      ok('R-5a: voucher aktif muncul di lookup', activeCodes.includes(voucherCode), activeCodes.join(','));

      // transisi sah 0 -> 1 + used_at
      await pool.query('update user_vouchers set is_used = 1, used_at = now() where user_id = ?', [tmpId]);

      const withUsed = await call(`/api/users/lookup?query=${tmpCode}`, { token: kasirToken });
      const usedCodes = (withUsed.json?.data?.vouchers ?? []).map((x) => x.voucher_code);
      ok('R-5b: voucher terpakai tidak ikut', !usedCodes.includes(voucherCode), usedCodes.join(','));
    } finally {
      await pool.query('delete from users where id = ?', [tmpId]).catch(() => {});
    }
    const [[leftTmp]] = await pool.query('select count(*) as n from users where id = ?', [tmpId]);
    ok('R-5c: user uji voucher dibersihkan', leftTmp.n === 0, `sisa ${leftTmp.n}`);

    // ---- PATCH /api/users/me/avatar (kasir & pelanggan) ----
    async function patchAvatar(token, {
      image = PNG_1X1, filename = 'avatar.png', type = 'image/png', field = 'image',
    } = {}) {
      const form = new FormData();
      if (image !== null) form.append(field, new Blob([image], { type }), filename);
      const headers = {};
      if (token) headers.Authorization = `Bearer ${token}`;
      const res = await fetch(`${base}/api/users/me/avatar`, { method: 'PATCH', headers, body: form });
      const json = await res.json().catch(() => null);
      return { status: res.status, json };
    }

    const avtNoToken = await patchAvatar(null);
    ok('avatar tanpa token 401', avtNoToken.status === 401, `status ${avtNoToken.status}`);

    const avtNoFile = await patchAvatar(pelangganToken, { image: null });
    ok('avatar tanpa foto 400', avtNoFile.status === 400, `status ${avtNoFile.status}`);

    const avtWrongField = await patchAvatar(pelangganToken, { field: 'avatar' });
    ok('avatar field salah ditolak 400', avtWrongField.status === 400, `status ${avtWrongField.status}`);

    const avtFakeMime = await patchAvatar(pelangganToken, {
      image: Buffer.from('<html><script>alert(1)</script></html>'),
      filename: 'fake.jpg',
      type: 'image/jpeg',
    });
    ok('avatar magic bytes palsu 400', avtFakeMime.status === 400, `status ${avtFakeMime.status}`);

    const ts = Date.now();
    const avtPrefix = `avt-${ts}`;
    const [pIns] = await pool.query(
      "insert into users (name, email, password, role, phone, member_code, points) values ('Uji Avatar Pelanggan', ?, '-', 'pelanggan', ?, ?, 0)",
      [`${avtPrefix}-pel@cleano.test`, `0896${String(ts).slice(-8)}`, `AVP-${String(ts).slice(-6)}`],
    );
    const [kIns] = await pool.query(
      "insert into users (name, email, password, role, phone, member_code, points) values ('Uji Avatar Kasir', ?, '-', 'kasir', ?, ?, 0)",
      [`${avtPrefix}-ksr@cleano.test`, `0897${String(ts).slice(-8)}`, `AVK-${String(ts).slice(-6)}`],
    );
    const localFilesToDelete = [];
    try {
      const tmpPelToken = jwt.sign(
        { id: pIns.insertId, member_code: `AVP-${String(ts).slice(-6)}`, role: 'pelanggan' },
        process.env.JWT_SECRET,
        { expiresIn: '5m' },
      );
      const tmpKsrToken = jwt.sign(
        { id: kIns.insertId, member_code: `AVK-${String(ts).slice(-6)}`, role: 'kasir' },
        process.env.JWT_SECRET,
        { expiresIn: '5m' },
      );

      const pelUp = await patchAvatar(tmpPelToken);
      const pelUrl = pelUp.json?.data?.avatar_url ?? '';
      if (pelUrl.startsWith('/uploads/')) localFilesToDelete.push(path.join(uploadDir, path.basename(pelUrl)));
      ok('avatar pelanggan sukses 200', pelUp.status === 200 && pelUrl.length > 0,
        pelUrl || `${pelUp.status} ${pelUp.json?.message ?? ''}`);

      const pelMe = await call('/api/users/me', { token: tmpPelToken });
      ok('me mengembalikan avatar_url terbaru', pelMe.json?.data?.avatar_url === pelUrl, pelMe.json?.data?.avatar_url);

      const ksrUp = await patchAvatar(tmpKsrToken);
      const ksrUrl = ksrUp.json?.data?.avatar_url ?? '';
      if (ksrUrl.startsWith('/uploads/')) localFilesToDelete.push(path.join(uploadDir, path.basename(ksrUrl)));
      ok('avatar kasir sukses 200', ksrUp.status === 200 && ksrUrl.length > 0,
        ksrUrl || `${ksrUp.status} ${ksrUp.json?.message ?? ''}`);
    } finally {
      await pool.query('delete from users where email like ?', [`${avtPrefix}%`]).catch(() => {});
      for (const f of localFilesToDelete) {
        try { fs.unlinkSync(f); } catch { /* abaikan bila sudah terhapus */ }
      }
    }
    const [[leftAvt]] = await pool.query('select count(*) as n from users where email like ?', [`${avtPrefix}%`]);
    ok('user uji avatar dibersihkan', leftAvt.n === 0, `sisa ${leftAvt.n}`);
  } catch (err) {
    ok('tes lookup tidak melempar error', false, err.message);
  } finally {
    console.log('');
    for (const r of rows) {
      console.log(`${r.pass ? 'OK  ' : 'GAGAL'} ${r.name.padEnd(42)} ${r.detail}`);
    }
    const failed = rows.filter((r) => !r.pass).length;
    console.log(`\n${rows.length - failed}/${rows.length} lulus`);

    server.close();
    await pool.end().catch(() => {});
    process.exit(failed ? 1 : 0);
  }
})();