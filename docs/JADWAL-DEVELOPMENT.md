# Jadwal Development — Cleano

**Speed run: 2 hari development + 1 hari testing.**

Mulai: Selasa, 17 November 2026
Development: **17–18 Nov 2026**
Testing: **19 Nov 2026**

Task detail: `TASK-backend.md`, `TASK-mobile.md`.
Aturan kerja: `PANDUAN-PENGERJAAN.md`.

---

## Kondisi awal (17 Nov, pagi)

| Lapisan | Selesai | Catatan |
|---|---|---|
| Database | skema v1.4 final | 43 kasus serangan terverifikasi, 0 lubang |
| Backend | ~2 dari 10 paket | B1 auth (3 commit), B2 lookup (belum commit) |
| Flutter | M0 fondasi | analyze bersih, build web lolos |
| Infra | repo, CI, tag v0.1.0, develop | branch protection belum diatur di GitHub |

B1 dan B2 **belum di-merge ke `develop`** — ini pekerjaan pertama hari 1.

---

## Hari 1 — Selasa, 17 Nov 2026

### Blok 1 · 08:00–09:30 — Tutup utang B1/B2 (1,5 jam)

| Jam | Kegiatan | Hasil |
|---|---|---|
| 08:00–08:45 | Review + perbaikan temuan B2: uji mutasi `is_used`, normalisasi `+62`, pindah `tierOf` ke `utils/tier.js` | B2 bersih |
| 08:45–09:15 | Commit B1 + B2, push, merge ke `develop` | `develop` punya auth + lookup |
| 09:15–09:30 | Atur branch protection di GitHub (manual, browser) | `main` & `develop` terlindungi |

**Gerbang:** `npm run test:auth` 28/28, `test:lookup` 28/28, CI hijau.

### Blok 2 · 09:30–12:00 — B3 Master data (2,5 jam)

| Jam | Kegiatan |
|---|---|
| 09:30–10:15 | `serviceController` + routes (GET/POST/PUT/DELETE) |
| 10:15–10:50 | `machineController` + routes (GET/POST/PATCH) |
| 10:50–11:30 | `rewardController` + routes + filter `is_active` untuk pelanggan |
| 11:30–12:00 | `test-master.js`, tangani `ER_ROW_IS_REFERENCED_2` → `409` |

**Gerbang:** pelanggan `POST /api/services` → `403` (TC-04). Hapus service terpakai → `409`.

### Blok 3 · 13:00–17:00 — B4 Order create (4 jam)

Paket terberat. Jangan dipotong.

| Jam | Kegiatan |
|---|---|
| 13:00–13:45 | Multipart + Multer, validasi input |
| 13:45–14:30 | `order_code` per tanggal, transaksi, retry deadlock |
| 14:30–15:30 | Alokasi mesin `FOR UPDATE` + jalur antre + `requires_machine = 0` |
| 15:30–16:15 | Voucher `FOR UPDATE` + Midtrans Snap |
| 16:15–17:00 | `test-orders-create.js`, uji TC-05/06/07 |

**Gerbang:** TC-06 (mesin terisi `MC-01`), TC-07 (antre + `queue_wait_minutes`),
TC-05 (tanpa foto → `400`). **Harga dihitung trigger, bukan backend.**

### Blok 4 · 19:00–21:00 — B5 Order list (2 jam)

| Jam | Kegiatan |
|---|---|
| 19:00–19:45 | `GET /api/orders` dari `vw_order_details`, kolom eksplisit (tanpa `snap_token`) |
| 19:45–20:20 | Filter status + pagination + filter `user_id` untuk pelanggan |
| 20:20–21:00 | `test-orders-list.js` — pelanggan A tidak bisa lihat order B (TC-10) |

**Gerbang hari 1:** B1–B5 hijau. `npm run check` 8/8, `db:smoke` 12/12.

---

## Hari 2 — Rabu, 18 Nov 2026

### Blok 5 · 08:00–11:00 — B6 Estafet mesin (3 jam)

| Jam | Kegiatan |
|---|---|
| 08:00–08:45 | `PATCH /:id/status` + validasi transisi |
| 08:45–09:45 | Bebaskan mesin + ambil antrean FIFO + `next_queue_order` |
| 09:45–10:30 | `PATCH /:id/confirm-relay` dengan `FOR UPDATE` |
| 10:30–11:00 | `test-orders-status.js` — TC-09 |

**Gerbang:** modal estafet dapat data antrean terdepan yang benar.

### Blok 6 · 11:00–12:00 — B7 + B8 (2 jam)

| Jam | Kegiatan |
|---|---|
| 11:00–11:30 | `POST /:id/sync-payment` (Core API, stub → `503`) |
| 11:30–12:00 | `GET /api/dashboard/summary` + isi 7 tanggal grafik |

**Gerbang:** TC-08 (tunai lunas, midtrans sinkron), TC-13 (grafik 7 hari terisi).

### Blok 7 · 13:00–14:30 — B9 Rewards (1,5 jam)

| Jam | Kegiatan |
|---|---|
| 13:00–13:45 | `POST /api/rewards/redeem` + `voucher_code` unik |
| 13:45–14:30 | `GET /api/rewards/my-vouchers` + `test-rewards.js` |

**Gerbang:** TC-12 backend — poin dipotong trigger, voucher `CLN-VCR-XXXX` terbit.

**Backend selesai di sini (14:30).**

### Blok 8 · 13:00–17:00 — M1 + M2 Flutter (4 jam, paralel)

Dikerjakan bersamaan dengan Blok 6–7 karena tidak bergantung pada endpoint baru.

| Jam | Kegiatan |
|---|---|
| 13:00–14:15 | M1: 8 model `fromJson` |
| 14:15–15:15 | M1: 7 service + `session_service` |
| 15:15–16:00 | M2: login + register screen |
| 16:00–16:30 | M2: router berbasis role + dua `main_nav` |
| 16:30–17:00 | M2: logout + splash cek token |

**Gerbang:** login sebagai kasir → dashboard kasir, sebagai pelanggan → portal pelanggan.

### Blok 9 · 19:00–22:00 — M4 POS + M7 tracking (3 jam)

Dua paket terbesar Flutter.

| Jam | Kegiatan |
|---|---|
| 19:00–20:15 | M4 langkah 1–2: scan QR / input HP, kartu konfirmasi, layanan, berat, foto |
| 20:15–21:00 | M4 langkah 3–4: voucher, metode bayar, submit, WebView Snap |
| 21:00–22:00 | M7: kartu pesanan aktif, stepper, badge mesin/antrean, detail |

**Gerbang hari 2:** backend 10/10 paket, Flutter M0–M2 + M4 + M7.

---

## Hari 3 — Kamis, 19 Nov 2026 — Testing

### Blok 10 · 08:00–10:00 — Sisa Flutter (2 jam)

| Jam | Kegiatan |
|---|---|
| 08:00–08:45 | M3 dashboard kasir (4 kartu + `fl_chart`) |
| 08:45–09:15 | M5 orders + modal estafet |
| 09:15–09:40 | M8 kartu QR pelanggan |
| 09:40–10:00 | M9 rewards pelanggan |

### Blok 11 · 10:00–11:00 — M6 + M10 (1 jam)

| Jam | Kegiatan |
|---|---|
| 10:00–10:35 | M6 master data 3 tab |
| 10:35–11:00 | M10 ekspor CSV/PDF |

**Kalau waktu habis:** M10 dipotong (bukan M6). Ekspor tidak masuk 13 TC wajib —
TC-13 hanya menyebut "fitur ekspor menghasilkan file yang dapat dibuka", dan itu bisa
diverifikasi dengan satu tombol CSV saja.

### Blok 12 · 11:00–12:00 — B10 Pengerasan (1 jam)

| Jam | Kegiatan |
|---|---|
| 11:00–11:20 | Rate limit login/register |
| 11:20–11:35 | Helmet |
| 11:35–11:50 | `certs/ca.pem` + `rejectUnauthorized: true` |
| 11:50–12:00 | `npm audit`, log terstruktur |

### Blok 13 · 13:00–16:00 — 13 TC Blackbox (3 jam)

Eksekusi berurutan. Catat lulus/gagal per TC di tabel hasil.

| TC | Skenario | Butuh |
|---|---|---|
| TC-01 | Registrasi & auto-member ID | M2 |
| TC-02 | Tolak duplikasi email/HP | M2 |
| TC-03 | Login & routing per role | M2 |
| TC-04 | Proteksi RBAC | M6 + backend |
| TC-05 | Validasi upload foto | M4 |
| TC-06 | Alokasi mesin otomatis | M4 |
| TC-07 | Estimasi antrean mesin penuh | M4 |
| TC-08 | Tunai & Midtrans + sync | M4 |
| TC-09 | Estafet 1-ketukan | M5 |
| TC-10 | Pelacakan pelanggan | M7 |
| TC-11 | Dual-lookup & privasi QR | M4 + M8 |
| TC-12 | Tukar poin & voucher 1x | M9 + M4 |
| TC-13 | Bonus 2x poin & grafik 7 hari | M3 + M10 |

### Blok 14 · 16:00–17:00 — Perbaikan & serah terima (1 jam)

| Jam | Kegiatan |
|---|---|
| 16:00–16:40 | Perbaikan TC yang gagal |
| 16:40–17:00 | Tag rilis `v1.0.0`, changelog, merge semua branch ke `develop` lalu `main` |

**DoD:** 13/13 TC lulus, app terhubung ke Aiven, artefak tersimpan di GitHub.

---

## Beban per hari

| Hari | Backend | Mobile | Total |
|---|---|---|---|
| 1 | 10 jam (B1–B5) | — | 10 jam |
| 2 | 6,5 jam (B6–B9) | 7 jam (M1, M2, M4, M7) | 13,5 jam |
| 3 | 1 jam (B10) | 3 jam (M3, M5, M6, M8, M9, M10) | 12 jam (termasuk 3 jam TC) |

Hari 2 adalah hari terberat. Kalau harus memotong, potong **M3 dan M10** — dashboard dan
ekspor bukan penghalang alur transaksi, dan hanya menyentuh TC-13.

---

## Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| B4 melewati 4 jam | seluruh hari 1 bergeser | potong Midtrans ke hari 2, kerjakan tunai dulu |
| Midtrans sandbox lambat / gagal | TC-08 gagal | siapkan mode stub, verifikasi tunai lebih dulu |
| `mobile_scanner` bermasalah di perangkat uji | TC-11 gagal | sediakan input manual `MBR-XXXX` sebagai jalur cadangan |
| `webview_flutter` Snap di Android | TC-08 gagal | fallback: buka `snap_redirect_url` di browser eksternal |
| Mesin hanya 3 tersedia | TC-07 sulit diuji | ubah 1 mesin ke `maintenance` sementara, atau buat order berurutan |
| Aiven kena rate limit / koneksi putus | semua uji gagal | uji dengan data seeder, jangan load test |

---

## Definisi selesai proyek

- [ ] 13/13 TC blackbox lulus
- [ ] Backend 10/10 paket merged
- [ ] Flutter 10/10 paket merged
- [ ] `npm run check` 8/8, `db:smoke` 12/12
- [ ] `dart analyze lib` bersih, `flutter test` lulus, `flutter build web` lolos
- [ ] Semua branch fitur merge ke `develop` → `main`
- [ ] Tag `v1.0.0` + changelog
- [ ] `.env` tidak masuk repo, `certs/ca.pem` terpasang
- [ ] README backend & mobile diperbarui