# cleano-backend

REST API Cleano — Smart Laundry POS & Order Tracking.
Express.js + mysql2 (Aiven MySQL 8, TLS) + Midtrans Snap + Multer.

Frontend Flutter/Dart berada di repo terpisah; folder ini **hanya** backend.

## Status

Backend selesai untuk seluruh **16 endpoint PRD-02**, ditambah `GET /api/users/me`
(dibutuhkan portal pelanggan PRD-04 §3.1/§3.3) dan `?status=aktif`
(PRD-03 §4). Regresi: **419 asersi** di 10 suite, `npm run check` hijau,
`npm audit` 0 kerentanan.

Yang belum: `certs/ca.pem` dari console Aiven (mekanisme `DB_SSL_VERIFY` sudah
siap menolak jalan tanpa berkas itu), dan celah-celah yang tercatat sebagai
"Terbuka" di `docs/TASK-backend.md`.

## Prasyarat

- Node.js >= 20
- Service MySQL 8 di Aiven Cloud (sudah ter-deploy)
- Akun Midtrans Sandbox

## Setup

```bash
npm install
cp .env.example .env      # Windows: copy .env.example .env
```

Lalu isi `.env`:

| Variabel | Sumber |
|---|---|
| `DB_HOST` | Aiven > service MySQL > Overview (tanpa `https://`) |
| `DB_PORT` | Aiven > Overview (port dinamis, bukan 3306) |
| `DB_USER` | `avnadmin` |
| `DB_PASSWORD` | Aiven > Users > avnadmin |
| `DB_NAME` | `cleano_db` (dibuat otomatis oleh skema) |
| `DB_SSL_CA` | taruh `ca.pem` hasil unduh dari Aiven ke `certs/` |
| `DB_SSL_VERIFY` | `true` di produksi — menolak jalan bila `ca.pem` tidak ada |
| `TRUST_PROXY_HOPS` | jumlah hop proxy (1 untuk Railway/Render/nginx, 0 tanpa proxy) |
| `AUTH_LOGIN_LIMIT` | percobaan login per 15 menit per IP (bawaan 10) |
| `AUTH_REGISTER_LIMIT` | pendaftaran per jam per IP (bawaan 5) |
| `DB_TIMEZONE` | `+07:00` (opsional, default `+07:00`) |
| `JWT_SECRET` | string acak panjang |
| `MIDTRANS_SERVER_KEY` | Midtrans Sandbox > Settings > Access Keys |
| `MIDTRANS_CLIENT_KEY` | idem |

`certs/`, `uploads/`, dan `.env` sudah masuk `.gitignore` — jangan di-commit.

## Muat skema ke Aiven

```bash
npm run db:load
```

Membuat database `cleano_db`, 6 tabel, 3 view, dan 6 trigger memakai kredensial yang sama
dengan aplikasi. Aman dijalankan berulang (semua objek di-`drop if exists` lebih dulu).

## Menjalankan

```bash
npm start      # produksi
npm run dev    # auto-reload (node --watch)
```

## Verifikasi

```bash
npm run check      # env, koneksi Aiven, kelengkapan skema
npm run db:smoke   # buktikan trigger & guard benar-benar bekerja di Aiven
npm run test:auth  # uji register/login lewat HTTP, user uji dihapus lagi
npm run test:lookup # uji users/lookup, tidak mengubah data
npm run test:master # uji CRUD layanan/mesin/reward, transaksi + ROLLBACK
```

`npm run db:smoke` menjalankan seluruh ujinya di dalam satu transaksi dan men-`ROLLBACK`
di akhir, jadi data produksi tidak pernah tersentuh.

`npm run test:auth` membuat user sementara di Aiven, menguji 38 skenario, lalu
menghapus user tersebut. Saldo poin pelanggan seeder tidak berubah.

Contoh keluaran sehat:

```
OK    .env terbaca         .env siap (jangan commit)
OK    variabel env wajib   lengkap
OK    koneksi Aiven (TLS)  db=cleano_db tz=+07:00 mysql=8.4.11
OK    tables (6)           lengkap
OK    views (3)            lengkap
OK    triggers (6)         lengkap
OK    data seeder          users=3
OK    midtrans server key  terkonfigurasi

8/8 cek lulus
```

```
OK    trigger hitung harga     21000/21000
OK    trigger stempel tunai    status=lunas paid_at=2026-11-16 19:44:02
OK    trigger snapshot tier    Gold
OK    guard harga immutable    ditolak trigger
OK    guard paid_at immutable  ditolak trigger
OK    guard hard delete        ditolak trigger
OK    poin masuk saat selesai  150 -> 152
OK    poin idempoten           152 -> 152
OK    guard points_awarded     ditolak trigger
OK    view dashboard           omzet=42000 mesin_tersedia=3
OK    view order details       tier=Gold now=Gold
OK    rollback bersih          orders 3 -> 3

12/12 lulus
```

## Endpoint yang sudah aktif

| Method | Path | Keterangan |
|---|---|---|
| GET | `/api/health` | status server + koneksi database |
| POST | `/api/auth/register` | daftar pelanggan baru, `member_code` otomatis |
| POST | `/api/auth/login` | login, mengembalikan JWT 24 jam + profil |
| GET | `/api/users/me` | profil sendiri: poin & tier terbaru (semua login) |
| GET | `/api/users/lookup?query=` | cari pelanggan via `member_code` atau nomor HP; `+62`/`62`/`08` sama (kasir) |
| GET | `/api/services` | daftar layanan (semua login) |
| POST/PUT/DELETE | `/api/services[/:id]` | kelola layanan (kasir) |
| GET | `/api/machines` | daftar mesin (semua login) |
| POST/PATCH | `/api/machines[/:id]` | tambah mesin, ubah status/kapasitas/estimasi (kasir) |
| GET | `/api/rewards` | daftar reward; pelanggan hanya yang aktif |
| POST/PUT | `/api/rewards[/:id]` | kelola reward (kasir) |
| PATCH | `/api/rewards/:id/toggle` | aktif/nonaktifkan reward (kasir) |
| POST | `/api/orders` | buat order + foto bukti (`multipart/form-data`, kasir) |
| GET | `/api/orders?status=&page=&pageSize=` | daftar order; `status=aktif` = semua yang belum final; pelanggan hanya miliknya sendiri |
| PATCH | `/api/orders/:id/status` | ubah status; melepas mesin + `next_queue_order` (kasir) |
| PATCH | `/api/orders/:id/confirm-relay` | pasang order antre ke mesin, mulai hitung mundur (kasir) |
| POST | `/api/orders/:id/sync-payment` | cek status ke Midtrans Core, tandai lunas bila settlement (kasir) |
| GET | `/api/dashboard/summary` | lima kartu metrik + tren omzet 7 hari (kasir) |
| POST | `/api/rewards/redeem` | klaim voucher; poin dipotong trigger (pelanggan) |
| GET | `/api/rewards/my-vouchers` | voucher milik sendiri, aktif + riwayat (pelanggan) |
| GET | `/uploads/:file` | penyajian statis foto bukti drop-off |

## Struktur

```
cleano-backend/
├── .env / .env.example
├── database_schema.sql        salinan v1.4 final (identik dgn root proyek)
├── server.js                  app, /api/health, error handler, graceful shutdown
├── certs/                     ca.pem Aiven
├── uploads/                   foto bukti drop-off
├── scripts/
│   ├── health-check.js        npm run check
│   ├── load-schema.js         npm run db:load
│   ├── smoke-test.js          npm run db:smoke
│   ├── test-auth.js           npm run test:auth
│   ├── test-lookup.js         npm run test:lookup
│   ├── test-master.js         npm run test:master
│   ├── test-orders-create.js  npm run test:orders-create
│   ├── test-orders-list.js    npm run test:orders-list
│   ├── test-orders-status.js  npm run test:orders-status
│   ├── test-sync-payment.js    npm run test:sync-payment
│   ├── test-dashboard.js       npm run test:dashboard
│   ├── test-rewards.js         npm run test:rewards
│   └── test-hardening.js       npm run test:hardening
└── src/
    ├── config/database.js     pool Aiven, TLS, timezone sesi +07:00
    ├── config/midtrans.js     Snap + Core, mode stub bila key kosong
    ├── middlewares/authMiddleware.js    verifyToken / checkRole
    ├── middlewares/rateLimit.js         batas percobaan login/register
    ├── middlewares/uploadMiddleware.js  Multer 2 MB, JPG/PNG/WEBP
    ├── services/orderAllocation.js      aturan alokasi mesin (dipakai bersama)
    ├── services/orderStatus.js          transisi status + estafet mesin + runTx
    ├── services/paymentSync.js          cek status Midtrans, tandai lunas
    ├── services/rewardRedeem.js         klaim voucher + daftar voucher pelanggan
    ├── utils/logger.js        log satu baris JSON
    ├── utils/response.js      ok/created + HttpError
    ├── utils/validate.js      zod safeParse -> HttpError 400
    ├── validators/authValidator.js     skema register/login
    ├── validators/masterValidator.js   skema layanan/mesin/reward/klaim
    ├── validators/orderValidator.js    skema order: buat, daftar, status, relay
    ├── controllers/authController.js    register, login
    ├── controllers/userController.js    lookup pelanggan
    ├── controllers/serviceController.js layanan
    ├── controllers/machineController.js mesin
    ├── controllers/rewardController.js  reward + klaim voucher pelanggan
    ├── controllers/orderController.js   buat/daftar order, ubah status, estafet, sync bayar
    ├── controllers/dashboardController.js ringkasan kartu + tren omzet 7 hari
    ├── routes/authRoutes.js
    ├── routes/userRoutes.js
    ├── routes/serviceRoutes.js
    ├── routes/machineRoutes.js
    ├── routes/rewardRoutes.js
    ├── routes/orderRoutes.js
    └── routes/dashboardRoutes.js
```

## Catatan teknis

- **Timezone sesi dipaksa `+07:00` pada setiap koneksi.** Aiven berjalan UTC. Opsi
  `timezone` milik mysql2 tidak mengubah `@@session.time_zone` di server, sehingga
  `now()`/`curdate()`/`DATE(paid_at)` tetap UTC dan semua transaksi setelah pukul 17:00 WIB
  tercatat di tanggal berikutnya. Karena itu `pool.on('connection')` men-`set time_zone`.
- **`DB_SSL=true` wajib untuk Aiven.** Bila `certs/ca.pem` belum ada, koneksi tetap TLS
  tetapi sertifikat tidak diverifikasi (muncul peringatan di log). Set `DB_SSL_VERIFY=true`
  di produksi supaya aplikasi **menolak jalan** tanpa CA — mode longgar tidak bisa ikut
  terbawa diam-diam.
- **Header keamanan dari `helmet`.** CSP dimatikan karena API ini hanya mengirim JSON.
- **Rate limit hanya di `/auth/login` dan `/auth/register`** (`src/middlewares/rateLimit.js`),
  bawaan 10/15 menit dan 5/jam per IP. Disimpan di memori proses; bila nanti berjalan lebih
  dari satu instance, ganti store ke Redis agar batasnya tidak terbagi per proses.
- **`TRUST_PROXY_HOPS` wajib diisi saat di belakang reverse proxy.** Tanpa itu `req.ip`
  berisi IP proxy dan semua pengguna berbagi satu ember — satu penyerang mengunci seluruh
  pengguna. Isi jumlah hop, bukan `true`: `true` mempercayai `X-Forwarded-For` apa adanya
  sehingga klien bisa memalsukan IP dan melewati batas.
- **Batas body JSON 1 MB** (`JSON_BODY_LIMIT`). Upload foto memakai jalur multipart terpisah
  yang dibatasi `MAX_IMAGE_MB`.
- **Log satu baris JSON** (`src/utils/logger.js`). Semua `console.*` di `src/` sudah diganti,
  supaya baris log bisa dibaca mesin dan tidak bercampur dengan output framework.
- **Upload dibatasi** 2 MB, hanya JPG/PNG/WEBP.
- **Integritas transaksi ditegakkan di level database** (harga tidak bisa diubah, voucher
  sekali pakai, order tidak bisa dihapus, poin idempoten). Backend tidak perlu — dan tidak
  boleh — mengulang logika itu dengan `UPDATE` manual.
- **Order tidak bisa di-`DELETE`.** Trigger `trg_before_delete_order` menolaknya, termasuk
  untuk data uji. Script uji wajib memakai transaksi + `ROLLBACK`.

## Kewajiban backend berikutnya (dari audit skema)

1. `SELECT ... FOR UPDATE` pada `machines` dan `user_vouchers` di `orderController.js`.
2. Retry otomatis pada `ER_LOCK_DEADLOCK` (kode 1213).
3. `SELECT` kolom eksplisit pada `vw_order_details` — `snap_token` tidak boleh ikut terekspos
   ke endpoint pelanggan.
4. Isi sendiri 7 tanggal pada grafik omzet (view tidak memunculkan hari tanpa transaksi).