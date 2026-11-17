# Panduan Pengerjaan — Cleano

Dokumen acuan cara kerja. Task per lapisan ada di file terpisah:

| File | Isi |
|---|---|
| `PANDUAN-PENGERJAAN.md` | dokumen ini — aturan, konvensi, verifikasi |
| `JADWAL-DEVELOPMENT.md` | pembagian 2 hari development + 1 hari testing |
| `TASK-backend.md` | task backend Express |
| `TASK-mobile.md` | task aplikasi Flutter |

---

## 1. Gambaran sistem

```
Cleano
├── database_schema.sql     skema v1.4 (6 tabel, 3 view, 6 trigger) — FINAL
├── cleano-backend/         Express + mysql2 + Midtrans + Multer
├── cleano_app/             Flutter (kasir + pelanggan dalam satu app)
└── docs/                   PRD, audit, task
```

| Lapisan | Teknologi | Host |
|---|---|---|
| Database | MySQL 8 (Aiven Cloud, TLS) | Aiven |
| Backend | Node 22, Express 5, mysql2/promise | lokal / VPS |
| Mobile & Web | Flutter 3.47 / Dart 3.13 | Android, iOS, Web |
| Pembayaran | Midtrans Snap (sandbox) | Midtrans |

Data mengalir satu arah: **Flutter → REST API → MySQL → trigger → view → API → Flutter**.
Tidak ada akses DB langsung dari Flutter.

---

## 2. Aturan kerja

### 2.1 Git

| Aturan | Detail |
|---|---|
| Basis branch | Semua fitur dari `develop` |
| Nama branch | `feature/<nama_fitur>` (mis. `feature/master-data`) |
| Commit | **Hanya setelah direview user.** Agent tidak commit sendiri |
| Merge | **Tidak merge ke `develop` otomatis.** Menunggu persetujuan |
| Format pesan | `<type>: <ringkas>` — `feat` `fix` `test` `docs` `ci` `refactor` |
| Atomik | Satu commit satu hal. Jangan campur fitur + refactor + format |

### 2.2 Struktur branch saat ini

```
main    ─── v0.1.0
  └── develop                             53097f3
        ├── feature/auth-register-login   fase 1 (3 commit)
        └── feature/users-lookup          fase 2 (ditumpuk di atas auth)
```

Fase 2 ditumpuk karena `utils/response.js` dan `tierOf` baru ada di fase 1.
Merge berurutan: auth dulu, baru users-lookup.

### 2.3 Integritas data — tanggung jawab trigger

**Aturan paling penting.** Backend tidak boleh menduplikasi logika yang sudah dijaga trigger.

| Yang dijaga DB | Backend tidak boleh |
|---|---|
| `subtotal_price`, `discount_amount`, `total_price` dihitung trigger | menghitung lalu mengirim nilainya |
| `paid_at` & `payment_status` tunai diisi trigger | `UPDATE ... SET payment_status='lunas'` untuk tunai |
| `customer_tier_snapshot` di-snapshot trigger | mengirim `customer_tier_snapshot` |
| Poin dipotong trigger saat voucher dibuat | `UPDATE users SET points = points - ?` |
| Poin ditambah trigger saat order `selesai` | `UPDATE users SET points = points + ?` |
| Voucher ditandai terpakai trigger | `UPDATE user_vouchers SET is_used = 1` |
| Order tidak bisa `DELETE` | menyediakan endpoint hapus order |
| Harga & berat immutable setelah insert | `UPDATE` harga/berat |
| `points_awarded` tidak bisa direset | `UPDATE points_awarded` |

Kalau backend mencoba salah satunya, trigger akan menolak dengan `SQLSTATE 45000`
dan request gagal. Itu perilaku benar, bukan bug.

### 2.4 Timezone

Aiven berjalan UTC. `pool.on('connection')` memaksa `set time_zone='+07:00'` per koneksi.
Jangan pernah menghitung tanggal di backend dengan `new Date()` — pakai `curdate()`,
`now()`, atau `DATE(paid_at)` dari MySQL.

---

## 3. Konvensi backend

### 3.1 Format respons

Sukses:
```json
{ "success": true, "message": "...", "data": {} }
```

Gagal:
```json
{ "success": false, "message": "..." }
```

Gunakan `src/utils/response.js`:

```js
const { ok, created, badRequest, unauthorized, forbidden, notFound, conflict } = require('../utils/response');

return ok(res, { ... });            // 200
return created(res, { ... });       // 201
throw badRequest('Pesan jelas.');   // 400
throw conflict('Sudah terdaftar.'); // 409
```

`HttpError` dibaca error handler di `server.js` — tidak perlu `try/catch` di controller
kecuali untuk menerjemahkan error MySQL.

### 3.2 Struktur file

```
src/
├── config/       database.js, midtrans.js
├── middlewares/  authMiddleware.js, uploadMiddleware.js
├── utils/        response.js
├── controllers/  <nama>Controller.js
└── routes/       <nama>Routes.js
```

Controller berisi logika, route hanya pemetaan + middleware. Tidak ada logika di route.

### 3.3 Query

- Selalu parameterisasi (`?`). Tidak ada string concat.
- **Sebutkan kolom eksplisit.** `SELECT *` dilarang di jalur yang responsnya keluar ke klien —
  `vw_order_details` memuat `snap_token`, jangan sampai ikut terkirim ke pelanggan.
- Operasi yang mengubah stok/status: `SELECT ... FOR UPDATE` di dalam transaksi.
- Retry `ER_LOCK_DEADLOCK` (1213) maksimal 3×.

### 3.4 Otorisasi

| Role | Akses |
|---|---|
| publik | `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/health` |
| `kasir` | master data CRUD, orders, dashboard, `users/lookup` |
| `pelanggan` | `GET /api/orders` (otomatis terfilter `user_id`), `rewards/redeem`, `rewards/my-vouchers`, `GET /api/services`, `GET /api/rewards` (aktif saja), `GET /api/machines` |

Pola rute:

```js
router.post('/', verifyToken, checkRole(['kasir']), create);
```

Pelanggan **tidak boleh** melihat data pengguna lain. Filter selalu dari `req.user.id`,
tidak pernah dari parameter yang dikirim klien.

---

## 4. Konvensi Flutter

### 4.1 Struktur

```
lib/
├── main.dart
├── core/
│   ├── constants/api_constants.dart
│   ├── theme/app_theme.dart
│   └── utils/formatters.dart
├── models/                       (belum ada)
├── services/                     api_service.dart + service per domain
└── screens/
    ├── auth/
    ├── kasir/
    └── pelanggan/
```

### 4.2 Aturan

- **Semua HTTP lewat `ApiService`.** Token otomatis disisipkan dari SharedPreferences.
  Jangan membuat `Dio()` baru di layar.
- **Nominal uang lewat `Formatters.rupiah()`**, tanggal lewat `Formatters.tanggal()`.
  Jangan `toString()` mentah di UI.
- **Nomor HP pelanggan selalu disensor** di tampilan: `Formatters.sensorTelepon()`.
- **Email tidak pernah ditampilkan** di Kartu QR Member (PRD-04 §3.2).
- **Tier ditampilkan dari API**, jangan dihitung ulang di klien.
- **Server Key Midtrans tidak boleh ada di app.** Hanya Client Key di `.env`.
- Tombol aksi disembunyikan untuk role yang tidak berhak, dan API tetap menolak (`403`) —
  UI bukan pengaman.

### 4.3 Base URL

| Target | `API_BASE_URL` |
|---|---|
| Emulator Android | `http://10.0.2.2:3000` |
| iOS simulator / Web | `http://localhost:3000` |
| Perangkat fisik | `http://<IP-LAN>:3000` |

---

## 5. Verifikasi

### Backend

```bash
cd cleano-backend
npm run check       # env, koneksi Aiven, kelengkapan skema (8 cek)
npm run db:smoke    # trigger & guard (12 cek, rollback)
npm run test:auth   # register/login (28 asersi)
npm run test:lookup # users/lookup (28 asersi)
```

### Flutter

```bash
cd cleano_app
dart analyze lib    # harus: No issues found!
flutter test        # unit test formatter
flutter build web --release
```

### Aturan skrip uji

1. Setiap fitur wajib punya skrip uji di `scripts/`.
2. Skrip harus **membersihkan dirinya sendiri** — hapus data uji di blok `finally`.
3. Data yang tidak bisa dihapus (order, karena `trg_before_delete_order`) diuji di dalam
   transaksi lalu `ROLLBACK`. Pola ada di `scripts/smoke-test.js`.
4. Uji harus **bisa gagal**. Sebelum menyerahkan, balikkan satu kondisi di kode dan pastikan
   suite jadi merah. Suite yang tetap hijau saat logikanya dirusak tidak menguji apa pun.

---

## 6. Definition of Done

Sebuah task selesai bila seluruh baris ini terpenuhi:

- [ ] Endpoint berjalan sesuai kontrak PRD
- [ ] Otorisasi role terpasang dan diuji (pelanggan → `403` pada endpoint kasir)
- [ ] Validasi input di batas sistem, pesan error dalam bahasa Indonesia
- [ ] Tidak menduplikasi logika trigger
- [ ] Query parameterized, kolom eksplisit
- [ ] Skrip uji ada, lulus, dan membersihkan dirinya sendiri
- [ ] Uji mutasi membuktikan suite bisa gagal
- [ ] `npm run check` + `npm run db:smoke` masih hijau
- [ ] README backend diperbarui (tabel endpoint + struktur)
- [ ] Direview user sebelum commit

---

## 7. Jebakan yang sudah terbukti

| Jebakan | Akibat | Pencegahan |
|---|---|---|
| Menghitung harga di backend | ditolak trigger, atau harga salah | serahkan ke trigger |
| `UPDATE payment_status` untuk tunai | `paid_at` tidak terisi, laporan harian salah | biarkan trigger |
| `SELECT *` dari `vw_order_details` | `snap_token` bocor ke pelanggan | sebut kolom |
| `DELETE` order | ditolak trigger | pakai `status='batal'` |
| Menghitung tanggal dengan `new Date()` | transaksi >17:00 WIB masuk tanggal berikutnya | `curdate()` dari MySQL |
| `SELECT` lalu `INSERT` tanpa `FOR UPDATE` | dua kasir dapat mesin yang sama | kunci dalam transaksi |
| Import `tierOf` antar controller | arah dependensi salah | pindah ke `utils/tier.js` saat pemakai ke-3 muncul |
| Suite uji tanpa mutasi | hijau padahal logika rusak | uji mutasi manual |

---

## 8. Status saat ini

| Lapisan | Selesai | Belum |
|---|---|---|
| Database | skema v1.4 final, 43 kasus serangan terverifikasi | `certs/ca.pem` untuk verifikasi TLS |
| Backend | health, auth, users/lookup | master data, orders, dashboard, rewards, pengerasan |
| Flutter | scaffold, tema, ApiService, formatter | seluruh layar, model, service domain |

Detail per task: `TASK-backend.md` dan `TASK-mobile.md`.
Jadwal: `JADWAL-DEVELOPMENT.md`.