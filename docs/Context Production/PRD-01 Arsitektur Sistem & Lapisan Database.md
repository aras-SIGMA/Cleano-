# PRD-01: ARSITEKTUR SISTEM & LAPISAN DATABASE (`cleano_db`)

* **ID Dokumen:** PRD-01
* **Lapisan Arsitektur:** System Architecture & Data Layer (MySQL 8.0+ / Aiven Cloud)
* **Target Implementasi:** Antigravity IDE (Database Migration & Schema Setup)
* **Nama Database:** `cleano_db` (`utf8mb4` / `utf8mb4_unicode_ci`)

---

## 1. Masalah UMKM yang Diselesaikan & Solusi Arsitektur

Mayoritas UMKM jasa binatu (laundry kiloan maupun satuan) menghadapi empat hambatan operasional utama di meja kasir:
1. **Kesalahan Hitung Nota Manual (10–15%):** Sekitar 60–70% UMKM masih memakai pembukuan kertas sehingga rawan salah hitung tarif dan kehilangan riwayat transaksi.
2. **Sengketa Kerusakan Pakaian (> 40% Kasus):** Ketiadaan dokumentasi kondisi pakaian saat serah terima (*drop-off*) memicu klaim pakaian luntur, robek, atau tertukar.
3. **Waktu Menganggur Mesin Cuci (20–30% *Idle Time*):** Tanpa pelacakan durasi siklus dan antrean digital, drum mesin cuci sering dibiarkan kosong atau tumpang tindih.
4. **Ketergantungan Chat WhatsApp Manual (95,17% Pelaku Usaha):** Pelanggan terus menanyakan status cucian secara manual karena tidak ada portal pelacakan *real-time*.

**Solusi Arsitektur Cleano:**
Cleano mengadopsi arsitektur **3-Tier Client-Server Kasir-Sentris** (*Flutter Client* $\leftrightarrow$ *Express.js REST API* $\leftrightarrow$ *Aiven Cloud MySQL 8.0* + *Midtrans Snap*). Seluruh pencatatan transaksi, pengambilan foto bukti *drop-off*, pembayaran, dan alokasi mesin dipusatkan di perangkat kasir, sementara database `cleano_db` bertindak sebagai *single source of truth* sekaligus pelacak status fisik mesin cuci (*software state-tracker*) tanpa memerlukan sensor perangkat keras (IoT).

---

## 2. Alur Data Lintas Lapisan (*End-to-End Data Flow*)

1. **Alur Identifikasi & Transaksi Kasir:**
   `Flutter Kasir` (Scan QR `MBR-XXXX` / Cari No. HP + Foto Pakaian + Scan QR Voucher `CLN-VCR-XXXX`) $\rightarrow$ `POST /api/orders` (`multipart/form-data`) $\rightarrow$ `Express.js` (Simpan foto via Multer, buka transaksi SQL, kunci voucher & mesin via `FOR UPDATE`) $\rightarrow$ `MySQL Triggers` (Hitung `subtotal_price`, `discount_amount`, `total_price`, tandai voucher `is_used = 1`) $\rightarrow$ `Midtrans Snap` (jika non-tunai) $\rightarrow$ Simpan ke tabel `orders`.
2. **Alur Estafet Mesin FIFO 1-Ketukan:**
   `Flutter Kasir` ubah status order ke `siap_diambil` $\rightarrow$ `Express.js` bebaskan mesin (`status = 'tersedia'`) dan kueri order `antre` terlama (FIFO) $\rightarrow$ Pop-up konfirmasi muncul di layar kasir $\rightarrow$ Kasir menekan tombol konfirmasi setelah pakaian fisik masuk ke drum $\rightarrow$ `PATCH /api/orders/:id/confirm-relay` $\rightarrow$ Mesin dikunci (`status = 'digunakan'`) dan timer `estimated_finish_at` mulai berjalan.
3. **Alur Pelacakan & Loyalti Pelanggan:**
   `Flutter Pelanggan` $\rightarrow$ `GET /api/orders` (membaca dari `vw_order_details` berdasarkan `user_id` di token JWT) $\rightarrow$ Menampilkan progres cucian, nomor mesin, estimasi tunggu, dan foto bukti. Saat kasir menandai order `selesai`, `trg_after_update_order_status` otomatis menambahkan poin ke `users.points` (dikali 2 jika berat $\ge 5\text{ kg}$ atau layanan *Express*).

---

## 3. Batasan Sistem (*Non-Goals*) & Target Keberhasilan (KPI)

### Non-Goals (Di Luar Ruang Lingkup)
* **Tanpa Integrasi IoT Fisik:** Aplikasi tidak terhubung ke mikrokontroler atau saklar listrik mesin cuci; status drum dikelola melalui *state machine* database dan konfirmasi 1-ketukan kasir.
* **Tanpa WhatsApp Gateway Otomatis:** Sistem tidak mengirimkan pesan blast WhatsApp; status cucian dipantau langsung melalui aplikasi Flutter pelanggan.
* **Single-Outlet Architecture:** Skema database dirancang untuk operasional satu cabang UMKM (belum mendukung *multi-branch inventory*).

### Key Performance Indicators (KPI)
* Waktu respons kueri database dan REST API rata-rata $< 2\text{ detik}$.
* Tingkat akurasi transaksi dan kalkulasi tagihan mencapai $100\%$ (nol selisih hitung).
* Nol insiden *double-claim* pada QR Voucher sekali pakai dan nol *race condition* pada penguncian drum mesin cuci.

---

## 4. Spesifikasi Skema Database (`cleano_db`)

Seluruh objek database wajib ditulis dalam huruf kecil (*lowercase*) menggunakan engine `InnoDB`.

### 4.1 Daftar 6 Tabel Utama & Aturan Integritas
1. **`users`**: `id` (PK), `name`, `email` (`UNIQUE`), `password` (Bcrypt hash), `role` (`enum('kasir','pelanggan')`, default `'pelanggan'`), `phone` (`UNIQUE`), `created_at`, `member_code` (`UNIQUE`, format `MBR-XXXX`), `points` (`INT`, default `0`, `CHECK (points >= 0)`).
2. **`services`**: `id` (PK), `name`, `price_per_kg` (`CHECK > 0`), `wash_duration_minutes` (default `45`), `estimated_hours` (default `24`), `requires_machine` (`TINYINT(1)`, default `1`), `description`, `created_at`.
3. **`machines`**: `id` (PK), `machine_code` (`UNIQUE`, format `MC-01`), `status` (`enum('tersedia','digunakan','maintenance')`, default `'tersedia'`), `capacity_kg` (`DECIMAL(4,2)`, default `7.00`), `estimated_finish_at` (`DATETIME NULL`).
4. **`rewards`**: `id` (PK), `title`, `description`, `points_required` (`CHECK > 0`), `discount_amount` (`CHECK > 0`), `is_active` (`TINYINT(1)`, default `1`), `created_at`.
5. **`user_vouchers`**: `id` (PK), `voucher_code` (`UNIQUE`, format `CLN-VCR-XXXX`), `user_id` (FK $\rightarrow$ `users.id` `ON DELETE CASCADE`), `reward_id` (FK $\rightarrow$ `rewards.id` `ON DELETE RESTRICT`), `is_used` (`TINYINT(1)`, default `0`), `used_at` (`DATETIME NULL`), `created_at`.
6. **`orders`**: `id` (PK), `order_code` (`UNIQUE`, format `CLN-YYYYMMDD-XXXX`), `user_id` (FK $\rightarrow$ `users.id` `ON DELETE RESTRICT`), `service_id` (FK $\rightarrow$ `services.id` `ON DELETE RESTRICT`), `machine_id` (FK $\rightarrow$ `machines.id` `ON DELETE SET NULL`), `weight` (`DECIMAL(4,2)`, `CHECK > 0`), `subtotal_price` (`INT`), `discount_amount` (`INT`, default `0`), `total_price` (`INT`, `CHECK >= 0`), `payment_method` (`enum('tunai','midtrans')`), `payment_status` (`enum('belum_bayar','lunas')`, default `'belum_bayar'`), `snap_token`, `snap_redirect_url`, `status` (`enum('antre','proses_cuci','sedang_diproses','siap_diambil','selesai','batal')`, default `'antre'`), `queue_wait_minutes` (`INT`, default `0`), `image_url` (`NOT NULL`), `notes`, `created_at`, `voucher_id` (FK $\rightarrow$ `user_vouchers.id` `ON DELETE SET NULL`).

### 4.2 Strategi Composite Indexing
* `idx_machines_status_finish (status, estimated_finish_at)` pada `machines`.
* `idx_rewards_active (is_active)` pada `rewards`.
* `idx_uv_user_used (user_id, is_used)` pada `user_vouchers`.
* `idx_orders_status_created (status, created_at)`, `idx_orders_payment_created (payment_status, created_at)`, dan `idx_orders_user_created (user_id, created_at)` pada `orders`.

---

## 5. Otomatisasi Logika Bisnis (Triggers, Views & Concurrency)

### 5.1 Database Triggers (4 Trigger Aktif)
1. **`trg_before_insert_user_voucher`**: Memvalidasi `rewards.is_active = 1` dan kecukupan `users.points >= points_required`, lalu otomatis mengurangi saldo poin pelanggan saat klaim voucher.
2. **`trg_before_insert_order`**: Mengambil `price_per_kg` dari `services`, menghitung `subtotal_price = ROUND(weight * price_per_kg)`, memvalidasi kepemilikan serta status `is_used = 0` jika `voucher_id` diisi, menghitung `total_price = GREATEST(0, subtotal_price - discount_amount)`, dan mengatur `payment_status = 'lunas'` jika `payment_method = 'tunai'`.
3. **`trg_after_insert_order`**: Otomatis memperbarui `user_vouchers` menjadi `is_used = 1` dan `used_at = NOW()` apabila transaksi menggunakan voucher.
4. **`trg_after_update_order_status`**: Ketika `old.status != 'selesai'` berubah menjadi `new.status = 'selesai'` dengan `payment_status = 'lunas'`, menghitung poin dasar $\lfloor \text{total\_price} / 10.000 \rfloor$ dan mengalikan $2\times$ jika `weight >= 5.00` atau nama layanan mengandung `'express'`, lalu menambahkannya ke `users.points`.

### 5.2 Database Views (3 View Laporan & Relasi)
1. **`vw_order_details`**: Menggabungkan `orders`, `users`, `services`, `machines`, dan `user_vouchers`, serta menghitung kolom turunan `customer_tier` (`Platinum` $\ge 300$, `Gold` $100\text{--}299$, `Silver` $< 100$).
2. **`vw_dashboard_summary`**: Menyediakan agregasi 1 baris untuk kartu dashboard kasir (`today_revenue`, `active_orders`, `ready_orders`, `available_machines`, `total_operational_machines`).
3. **`vw_daily_revenue_7days`**: Mengelompokkan omzet lunas dan total berat cucian per tanggal selama 7 hari terakhir untuk grafik batang `fl_chart`.

### 5.3 Aturan Transaksi & Row-Level Locking
Setiap operasi penulisan yang berpotensi diakses bersamaan oleh lebih dari satu kasir atau klik ganda pengguna **wajib** dibungkus dalam `START TRANSACTION` ... `COMMIT` dengan klausa `FOR UPDATE` pada:
* Pencarian unit mesin `'tersedia'` saat pembuatan order dan konfirmasi estafet mesin.
* Validasi baris `user_vouchers` dan pemotongan `users.points` saat klaim reward.

---

## 6. Acceptance Criteria (Lapisan Database)

* [ ] Skrip `database_schema.sql` dapat dieksekusi bersih di Aiven Cloud MySQL 8.0 (`log_bin_trust_function_creators = ON`) tanpa error sintaks atau privilege.
* [ ] Keenam tabel, 4 trigger, dan 3 view terbentuk dengan karakter set `utf8mb4_unicode_ci`.
* [ ] Percobaan `INSERT` ke `orders` menggunakan `voucher_id` yang sudah bernilai `is_used = 1` ditolak langsung oleh MySQL dengan `SQLSTATE '45000'`.
* [ ] Perubahan status order seberat $6\text{ kg}$ menjadi `'selesai'` otomatis menggandakan perolehan poin pelanggan di tabel `users`.