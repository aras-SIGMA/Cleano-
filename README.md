# Cleano

Smart Laundry POS & Order Tracking. Satu sistem, dua portal:

- **Portal Kasir** — dashboard omzet, POS pembuatan order, estafet mesin, kelola
  layanan/mesin/reward, ekspor laporan CSV/PDF.
- **Portal Pelanggan** — pelacakan cucian, kartu QR member, saldo poin, klaim voucher.

| Bagian | Teknologi |
|---|---|
| `cleano_app/` | Flutter/Dart (Android, iOS, Web) — kedua portal dalam satu aplikasi |
| `cleano-backend/` | Node.js >= 20, Express 5, mysql2, zod, Midtrans Snap |
| `cleano-backend/database_schema.sql` | MySQL 8 (Aiven Cloud) — 6 tabel, 3 view, 6 trigger |
| `.github/workflows/ci.yml` | CI: backend (sintaks + boot), Flutter (analyze + test) |

Integritas transaksi ditegakkan di database: harga terkunci, voucher sekali pakai,
order tidak bisa dihapus, poin idempoten, `paid_at` hanya diisi sistem. Backend
tidak mengulang logika itu — lihat `AGENTS.md` §5.

## Mulai cepat

### Backend

```bash
cd cleano-backend
npm install
cp .env.example .env        # Windows: copy .env.example .env
```

Isi `.env` dari dashboard Aiven (MySQL 8, TLS wajib) dan Midtrans Sandbox.
`certs/ca.pem` diunduh dari Aiven > service > Overview > CA Certificate; berkas
ini tidak ikut ter-commit.

```bash
npm run db:load     # buat database, 6 tabel, 3 view, 6 trigger (aman diulang)
npm run check       # env, koneksi Aiven, kelengkapan skema
npm run dev         # http://localhost:3000
```

### Aplikasi

```bash
cd cleano_app
flutter pub get
cp .env.example .env        # Windows: copy .env.example .env
flutter run
```

`.env` aplikasi hanya berisi `API_BASE_URL` dan `MIDTRANS_CLIENT_KEY` (client key
aman di frontend; server key tidak pernah masuk aplikasi). Alamat backend per
target: emulator Android `http://10.0.2.2:3000`, simulator iOS
`http://localhost:3000`, perangkat fisik `http://<IP-LAN>:3000`.

## Verifikasi

Backend (semua butuh `.env` dan koneksi Aiven hidup):

```bash
cd cleano-backend
npm run check
npm run test:auth && npm run test:lookup && npm run test:master
npm run test:orders-create && npm run test:orders-list
npm run test:orders-status && npm run test:sync-payment
npm run test:dashboard && npm run test:rewards && npm run test:hardening
```

Status terakhir: `check` 8/8, 428 asersi lulus di 10 suite.

Aplikasi:

```bash
cd cleano_app
dart analyze lib
flutter test
```

Status terakhir: analyze bersih, 73 uji lulus di 13 berkas.

## Endpoint utama

| Method | Path | Akses |
|---|---|---|
| GET | `/api/health` | publik — 200 sehat, 503 bila database mati |
| POST | `/api/auth/register`, `/api/auth/login` | publik (rate limit) |
| GET | `/api/users/me` | semua login — poin & tier terbaru |
| GET | `/api/users/lookup?query=` | kasir — cari via `member_code` / nomor HP |
| GET | `/api/services`, `/api/machines`, `/api/rewards` | semua login |
| POST/PUT/PATCH | `/api/services`, `/api/machines`, `/api/rewards` | kasir |
| POST | `/api/orders` | kasir — multipart, foto bukti drop-off |
| GET | `/api/orders?status=&page=&pageSize=` | kasir semua, pelanggan miliknya |
| PATCH | `/api/orders/:id/status`, `/api/orders/:id/confirm-relay` | kasir |
| POST | `/api/orders/:id/sync-payment` | kasir — cek status Midtrans |
| GET | `/api/dashboard/summary` | kasir |
| POST | `/api/rewards/redeem`, GET `/api/rewards/my-vouchers` | pelanggan |

Rincian lengkap: [`cleano-backend/README.md`](cleano-backend/README.md).

## Struktur

```
Cleano/
├── cleano-backend/       REST API, skrip uji, database_schema.sql
├── cleano_app/           aplikasi Flutter — layar kasir & pelanggan
├── docs/                 PRD, panduan kerja, task, audit skema
├── .github/workflows/    CI
└── AGENTS.md             aturan kerja yang mengikat
```

Skema berubah **hanya** lewat `cleano-backend/database_schema.sql`, dan versinya
dinaikkan. Jangan menambal skema dari kode backend.

## Dokumentasi

- [`docs/README.md`](docs/README.md) — indeks dokumen
- [`docs/PANDUAN-PENGERJAAN.md`](docs/PANDUAN-PENGERJAAN.md) — aturan kerja, konvensi, Definition of Done
- [`docs/DESIGN.md`](docs/DESIGN.md) — panduan UI/UX
- [`docs/TASK-backend.md`](docs/TASK-backend.md), [`docs/TASK-mobile.md`](docs/TASK-mobile.md) — status task
- [`AGENTS.md`](AGENTS.md) — aturan commit, uji, dan database untuk kontributor

## Kontribusi

Kerja di branch `feature/<nama>`, push ke sana, lalu buka Pull Request ke
`develop`. Jangan push atau merge langsung ke `develop`/`main`.
