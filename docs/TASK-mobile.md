
# Task Mobile — Cleano

Lapisan: Flutter 3.47 / Dart 3.13. Satu aplikasi, dua portal (kasir + pelanggan).
Aturan kerja dan konvensi: `PANDUAN-PENGERJAAN.md`.
Jadwal: `JADWAL-DEVELOPMENT.md`.

Legenda status: `[x]` selesai · `[~]` dikerjakan, belum commit · `[ ]` belum

---

## Ringkasan

| # | Paket | Branch | Status |
|---|---|---|---|
| M0 | Fondasi | `develop` | `[x]` |
| M1 | Model & service | `feature/mobile-core` | `[ ]` |
| M2 | Auth & routing | `feature/mobile-auth` | `[ ]` |
| M3 | Kasir — dashboard | `feature/mobile-dashboard` | `[x]` |
| M4 | Kasir — POS | `feature/mobile-pos` | `[x]` |
| M5 | Kasir — orders & estafet | `feature/mobile-app` | `[x]` |
| M6 | Kasir - master data | `feature/mobile-app` | `[x]` |
| M7 | Pelanggan — tracking | `feature/mobile-tracking` | `[ ]` |
| M8 | Pelanggan — kartu QR | `feature/mobile-qr-card` | `[ ]` |
| M9 | Pelanggan — rewards | `feature/mobile-rewards` | `[ ]` |
| M10 | Ekspor laporan | `feature/mobile-export` | `[ ]` |

Total **11 paket**. M0 selesai, M1–M10 belum.

**Urutan wajib:** M1 → M2 → (M3/M4/M5/M6 paralel dengan M7/M8/M9) → M10.
M10 butuh data dari M3 dan M5.

---

## M0 — Fondasi

Status `[x]` di `develop`

- [x] Scaffold Android/iOS/Web, org `id.cleano`
- [x] 13 dependensi sesuai PRD-03/04 §6
- [x] Tema `#0F4C81`, Material 3
- [x] `ApiService` — Dio + Bearer auto-inject + `ApiException`
- [x] `ApiConstants` — semua path endpoint
- [x] `Formatters` — rupiah, kg, tanggal `id_ID`, sensor WA
- [x] `.env` + `flutter_dotenv`, locale `id_ID` diinisialisasi
- [x] Android `INTERNET`+`CAMERA`+`usesCleartextTraffic`, iOS izin kamera/galeri
- [x] `dart analyze` bersih, 4 tes formatter lulus, `flutter build web` lolos

---

## M1 — Model & service

Branch `feature/mobile-core` · prasyarat semua paket lain

### Model

- [x] `models/user_model.dart` — `id, name, email, phone, role, member_code, points, tier`
- [x] `models/service_model.dart` — `id, name, price_per_kg, wash_duration_minutes, estimated_hours, requires_machine, description`
- [x] `models/machine_model.dart` — `id, machine_code, status, capacity_kg, estimated_finish_at`
- [x] `models/reward_model.dart` — `id, title, description, points_required, discount_amount, is_active`
- [x] `models/voucher_model.dart` — `id, voucher_code, reward_id, title, discount_amount, is_used`
- [x] `models/order_model.dart` — semua kolom `vw_order_details` yang dipakai UI
- [x] `models/dashboard_summary_model.dart`
- [x] `models/next_queue_order_model.dart`

Semua model: `fromJson` manual, tanpa `build_runner`. Tanggal dari API berbentuk string
`DATE`/`DATETIME` — parse ke `DateTime`.

### Service

- [x] `services/auth_service.dart` — `register`, `login`, `logout` (hapus token), `currentUser`
- [x] `services/user_service.dart` — `lookup(query)`
- [x] `services/master_service.dart` — CRUD services/machines/rewards
- [x] `services/order_service.dart` — `create` (multipart), `list`, `updateStatus`, `confirmRelay`, `syncPayment`
- [x] `services/dashboard_service.dart` — `summary`
- [x] `services/reward_service.dart` — `catalog`, `redeem`, `myVouchers`
- [x] `services/session_service.dart` — simpan token + profil user di SharedPreferences

**Aturan:** setiap service memakai `ApiService.instance`. Tidak membuat `Dio` baru.
Error dilempar sebagai `ApiException` yang sudah ada.

- [x] `test/models_test.dart` — `fromJson` untuk order & user
- [x] `dart analyze lib` bersih

---

## M2 — Auth & routing

Branch `feature/mobile-auth`

- [x] `screens/auth/login_screen.dart` — email + password, validasi, loading, error inline
- [x] `screens/auth/register_screen.dart` — nama, email, password, phone
- [x] `core/router/app_router.dart` — routing berbasis role
- [x] Splash/bootstrap: cek token tersimpan → arahkan ke portal yang sesuai
- [x] `kasir_main_nav.dart` — `NavigationRail` di layar lebar, `BottomNavigationBar` di sempit
- [x] `pelanggan_main_nav.dart` — `BottomNavigationBar` 3 tab
- [x] Logout dari kedua portal (hapus token + kembali ke login)

**Aturan:** UI bukan pengaman. Menyembunyikan tombol tidak menggantikan `403` dari API.

---

## M3 — Kasir: dashboard

Branch `feature/mobile-dashboard`

- [x] `screens/kasir/kasir_dashboard_screen.dart`
- [x] 4 kartu metrik: omzet hari ini, pesanan aktif, siap diambil, kapasitas mesin
- [x] Grafik batang `fl_chart` tren omzet 7 hari + tooltip
- [x] Daftar ringkas order aktif dengan kode mesin atau estimasi tunggu
- [x] Pull-to-refresh
- [x] Tombol ekspor (memanggil M10)

---

## M4 — Kasir: POS

Branch `feature/mobile-pos` · **paket terberat**

- [x] `screens/kasir/pos_create_order_screen.dart` — 4 langkah
- [x] Langkah 1: scan QR member (`mobile_scanner`) **atau** input nomor HP → `user_service.lookup`
- [x] Kartu konfirmasi pelanggan: nama, `MBR-XXXX`, badge tier, WA tersensor
- [x] Langkah 2: dropdown layanan, input berat desimal, foto wajib (`image_picker`), catatan
- [x] Kompresi foto agar `< 2 MB` sebelum kirim
- [x] Langkah 3: scan/input voucher, tampilkan subtotal/potongan/total
- [x] Langkah 4: radio tunai / midtrans, tombol **Proses Transaksi** nonaktif bila foto belum ada
      atau berat `<= 0`
- [x] `widgets/` — `member_card.dart`, `service_dropdown.dart`, `weight_input.dart`,
      `photo_picker_field.dart`, `voucher_field.dart`
- [x] Midtrans: `webview_flutter` membuka `snap_redirect_url`
- [x] Tombol **Cek Status Pembayaran** → `syncPayment`, badge `LUNAS`

---

## M5 — Kasir: orders & estafet

Branch `feature/mobile-app`

- [x] `screens/kasir/kasir_orders_screen.dart`
- [x] Tab filter: Semua, Antre, Proses Cuci, Sedang Diproses, Siap Diambil, Selesai
- [x] Tombol **Tandai Siap Diambil** (`proses_cuci`/`sedang_diproses` → `siap_diambil`)
- [x] Pencarian kode order / nama / HP lewat `GET /api/orders?search=` (server-side, debounce 350 ms)
- [x] Modal konfirmasi estafet bila respons memuat `next_queue_order`
      ("Mesin MC-01 Kini Kosong!") dengan aksi **Ya, Mulai Cuci** / **Nanti Saja**
- [x] Tombol **Selesaikan Pesanan** (`siap_diambil` → `selesai`)
- [x] Pagination / infinite scroll

---

## M6 — Kasir: master data

Branch `feature/mobile-app`

- [x] `screens/kasir/kasir_master_screen.dart` — 3 tab
- [x] Tab Layanan: list, tambah, edit, hapus (tangani `409`)
- [x] Tab Mesin: list, tambah `MC-XX`, ubah status `tersedia`/`maintenance`
- [x] Tab Rewards: list, tambah, edit, toggle `is_active`

---

## M7 — Pelanggan: tracking

Branch `feature/mobile-tracking`

- [ ] `screens/pelanggan/pelanggan_tracking_screen.dart`
- [ ] Header: sapaan, badge tier, saldo poin
- [ ] Kartu pesanan aktif + stepper 4 tahap
- [ ] Badge mesin (`Sedang Dicuci di Mesin MC-01` + jam selesai) atau antrean
      (`Menunggu Antrean ± N Menit`)
- [ ] Badge `LUNAS` / `BELUM BAYAR`
- [ ] Bottom-sheet detail: foto drop-off, catatan, rincian harga, pull-to-refresh
- [ ] Tab riwayat `selesai` + poin yang diperoleh

---

## M8 — Pelanggan: kartu QR

Branch `feature/mobile-qr-card`

- [ ] `screens/pelanggan/pelanggan_qr_card_screen.dart`
- [ ] QR `qr_flutter` hanya berisi `member_code`
- [ ] Nama lengkap, badge tier berwarna (Silver/Gold/Platinum), `MBR-XXXX` teks di bawah QR
- [ ] Nomor WA tersensor via `Formatters.sensorTelepon`
- [ ] **Email tidak ditampilkan sama sekali**
- [ ] Kecerahan layar dinaikkan saat kartu dibuka (opsional, demi scan)

---

## M9 — Pelanggan: rewards

Branch `feature/mobile-rewards`

- [ ] `screens/pelanggan/pelanggan_rewards_screen.dart`
- [ ] Banner poin + progress bar ke tier berikutnya (100 Gold, 300 Platinum)
- [ ] Info bonus 2x poin (≥5 kg atau Express)
- [ ] Sub-tab katalog: tombol **Tukar Poin** aktif bila `points >= points_required`
- [ ] Dialog konfirmasi → `POST /api/rewards/redeem`
- [ ] Sub-tab voucher saya: QR `CLN-VCR-XXXX` + kode teks + nominal + badge `1x Pakai`
- [ ] Voucher terpakai pindah ke riwayat dengan tampilan redup `Sudah Terpakai`

---

## M10 — Ekspor laporan

Branch `feature/mobile-export`

- [ ] `services/export_service.dart`
- [ ] Export CSV (`csv` + `path_provider`)
- [ ] Export PDF (`pdf` + `printing`) — header toko, tabel transaksi, total
- [ ] Dialog pilihan format dari dashboard kasir
- [ ] Berbagi file via `printing` share sheet

---

## Pemetaan TC → paket

| TC | Paket |
|---|---|
| TC-03 | M2 |
| TC-04 | M2 (tombol tersembunyi) + backend |
| TC-05 | M4 |
| TC-06, TC-07 | M4 |
| TC-08 | M4 |
| TC-09 | M5 |
| TC-10 | M7 |
| TC-11 | M4 (scan) + M8 (kartu) |
| TC-12 | M9 (klaim) + M4 (pakai) |
| TC-13 | M3 + M10 |

---

## Batasan yang perlu diingat

| Hal | Catatan |
|---|---|
| `image_picker` di Web | Bekerja, tapi tidak bisa akses kamera native — pakai galeri |
| `mobile_scanner` di Web | Terbatas; uji di perangkat |
| `webview_flutter` di Web | Punya `webview_flutter_web` terbatas; Midtrans Snap bisa dibuka di tab baru |
| Build web | Path proyek tidak boleh mengandung `#` (sudah diperbaiki) |
| Server Key Midtrans | **Tidak boleh** masuk app — hanya Client Key |