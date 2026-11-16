# PRD-02: LAPISAN BACKEND REST API & INTEGRASI LAYANAN (`cleano-backend`)

* **ID Dokumen:** PRD-02
* **Lapisan Arsitektur:** Backend Application Layer (Node.js + Express.js + `mysql2/promise`)
* **Target Implementasi:** Antigravity IDE (REST API Controllers, Middlewares & Routes)
* **Integrasi Eksternal:** Aiven Cloud MySQL (SSL), Midtrans Snap Sandbox, Multer Local Storage

---

## 1. Masalah Teknis yang Diselesaikan di Lapisan Backend

1. **Pencegahan Akses Tidak Sah (RBAC):** Memastikan pelanggan tidak dapat memanipulasi pesanan, tarif layanan, status mesin, atau katalog promo melalui manipulasi request API.
2. **Sinkronisasi Status Fisik Mesin & Antrean FIFO:** Mengotomatiskan pemilihan drum mesin yang kosong, menghitung estimasi menit tunggu saat seluruh mesin penuh, serta menyediakan mekanisme konfirmasi 1-ketukan (*1-Tap Relay*) agar timer mesin akurat sesuai waktu pakaian fisik dimasukkan petugas.
3. **Validasi Bukti Foto & Pembayaran Terpusat:** Menjamin setiap pesanan memiliki foto kondisi awal pakaian (maksimal $2\text{ MB}$) dan memproses pembayaran tunai maupun non-tunai (Midtrans Snap QRIS/VA) secara terpusat dari kasir.
4. **Keamanan Transaksi Konkuren:** Mencegah *race condition* saat dua kasir membuat pesanan bersamaan melalui *database transaction* dan *row-level locking* (`FOR UPDATE`).

---

## 2. Struktur Direktori Backend

```text
cleano-backend/
├── .env
├── package.json
├── server.js
├── database_schema.sql
├── uploads/                  # Direktori penyimpanan foto bukti drop-off
└── src/
    ├── config/
    │   ├── database.js       # Connection pool mysql2 dengan SSL Aiven
    │   └── midtrans.js       # Konfigurasi Midtrans Snap Sandbox Client
    ├── middlewares/
    │   ├── authMiddleware.js # verifyToken (JWT) & checkRole(['kasir'])
    │   └── uploadMiddleware.js # Konfigurasi Multer (JPG/PNG/WEBP, max 2MB)
    ├── controllers/
    │   ├── authController.js
    │   ├── userController.js
    │   ├── serviceController.js
    │   ├── machineController.js
    │   ├── orderController.js
    │   ├── rewardController.js
    │   └── dashboardController.js
    └── routes/
        ├── authRoutes.js
        ├── userRoutes.js
        ├── serviceRoutes.js
        ├── machineRoutes.js
        ├── orderRoutes.js
        ├── rewardRoutes.js
        └── dashboardRoutes.js
```

---

## 3. Alur Eksekusi Request & Standar Respons JSON

### 3.1 Pipeline Middleware
`Request` $\rightarrow$ `cors()` $\rightarrow$ `express.json()` $\rightarrow$ `verifyToken` (ekstrak `req.user = { id, member_code, role }`) $\rightarrow$ `checkRole(['kasir'])` (pada rute privat kasir) $\rightarrow$ `upload.single('image')` (khusus `POST /api/orders`) $\rightarrow$ `Controller` $\rightarrow$ `JSON Response`.

### 3.2 Standar Format JSON & HTTP Status Code
* **Sukses (`200 OK` / `201 Created`):**
  ```json
  {
    "success": true,
    "message": "Deskripsi keberhasilan operasi.",
    "data": {}
  }
  ```
* **Gagal (`400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `500 Internal Server Error`):**
  ```json
  {
    "success": false,
    "message": "Pesan error yang informatif untuk ditampilkan di UI Flutter."
  }
  ```

---

## 4. Kontrak Endpoint REST API Lengkap

### 4.1 Autentikasi & Dual-Lookup Member
* **`POST /api/auth/register`** (Public)
  * **Body:** `{ "name": "Rina", "email": "rina@gmail.com", "password": "password123", "phone": "081234567890" }`
  * **Logika:** Validasi `email` & `phone` unik, hash password Bcrypt (10 rounds), generate `member_code` berurutan (`MBR-XXXX`), simpan dengan `role = 'pelanggan'`. Mengembalikan `201 Created`.
* **`POST /api/auth/login`** (Public)
  * **Body:** `{ "email": "kasir@cleano.id", "password": "password123" }`
  * **Response (`200 OK`):** Mengembalikan `token` (JWT 24 jam) dan objek `user` lengkap dengan properti `tier` (`Silver` / `Gold` / `Platinum`).
* **`GET /api/users/lookup?query=MBR-0001`** (Role: `kasir`)
  * **Logika:** Mencari pelanggan berdasarkan `member_code = ? OR phone = ?`. Mengembalikan `id`, `name`, `phone`, `member_code`, `points`, `tier`, serta daftar voucher aktif milik pelanggan (`is_used = 0`).

### 4.2 Manajemen Master Data (`services`, `machines`, `rewards`)
* **`GET /api/services`** (All authenticated) | **`POST`, `PUT /:id`, `DELETE /:id`** (Role: `kasir`)
* **`GET /api/machines`** (All authenticated) | **`POST`, `PATCH /:id`** (Role: `kasir`)
* **`GET /api/rewards`** (All authenticated — filter `is_active = 1` jika role `pelanggan`) | **`POST`, `PUT /:id`, `PATCH /:id/toggle`** (Role: `kasir`)

### 4.3 Transaksi Order, Alokasi Mesin & Pembayaran (`orders`)
* **`POST /api/orders`** (Role: `kasir`, `multipart/form-data`)
  * **Fields:** `user_id`, `service_id`, `weight`, `payment_method` (`tunai` | `midtrans`), `voucher_code` (opsional), `notes` (opsional), dan file `image` (wajib, maks $2\text{ MB}$).
  * **Alur Transaksi SQL (`beginTransaction`):**
    1. Generate `order_code` format `CLN-YYYYMMDD-XXXX`.
    2. Jika `voucher_code` dikirim, kunci dan validasi `id` dari `user_vouchers` (`FOR UPDATE`).
    3. Cek `services.requires_machine`:
       * Jika `1`: Kueri `SELECT id FROM machines WHERE status = 'tersedia' ORDER BY id ASC LIMIT 1 FOR UPDATE`. Jika ada, set `machine_id`, `status = 'proses_cuci'`, dan update `machines` menjadi `'digunakan'` dengan `estimated_finish_at = DATE_ADD(NOW(), INTERVAL wash_duration_minutes MINUTE)`. Jika penuh, set `machine_id = NULL`, `status = 'antre'`, dan hitung `queue_wait_minutes` dari `MIN(estimated_finish_at)` mesin yang sedang `'digunakan'`.
       * Jika `0`: Set `machine_id = NULL`, `status = 'sedang_diproses'`, `queue_wait_minutes = 0`.
    4. Eksekusi `INSERT INTO orders` (biarkan trigger SQL menghitung harga dan menandai voucher terpakai).
    5. Jika `payment_method === 'midtrans'`, panggil `snap.createTransaction()` untuk mendapatkan `snap_token` dan `snap_redirect_url`, lalu update baris order tersebut.
    6. `COMMIT` transaksi dan kembalikan `201 Created`.
* **`GET /api/orders`** (All authenticated)
  * **Logika:** Membaca dari `vw_order_details`. Jika `req.user.role === 'pelanggan'`, tambahkan filter `WHERE user_id = ?`. Mendukung query filter `?status=...`.
* **`PATCH /api/orders/:id/status`** (Role: `kasir`)
  * **Body:** `{ "status": "siap_diambil" }` (atau `sedang_diproses`, `selesai`, `batal`).
  * **Logika Estafet:** Jika status diubah dari `'proses_cuci'` ke `'siap_diambil'` dan order memiliki `machine_id`, bebaskan mesin (`status = 'tersedia'`, `estimated_finish_at = NULL`), lalu kueri 1 order `'antre'` terdepan (`ORDER BY created_at ASC, id ASC LIMIT 1`). Sertakan objek `next_queue_order` pada respons JSON agar UI kasir memunculkan pop-up konfirmasi 1-ketukan.
* **`PATCH /api/orders/:id/confirm-relay`** (Role: `kasir`)
  * **Body:** `{ "machine_id": 1 }`
  * **Logika:** Dalam transaksi `FOR UPDATE`, kunci mesin `id = machine_id` yang berstatus `'tersedia'`, set menjadi `'digunakan'` dengan `estimated_finish_at` baru, dan ubah status order antrean menjadi `'proses_cuci'` dengan `machine_id` tersebut.
* **`POST /api/orders/:id/sync-payment`** (Role: `kasir`)
  * **Logika:** Mengecek status transaksi ke Midtrans Core API (`snap.transaction.status(order_code)`). Jika `settlement` atau `capture`, update `payment_status = 'lunas'` di tabel `orders`.

### 4.4 Cleano Rewards & Dashboard Summary
* **`POST /api/rewards/redeem`** (Role: `pelanggan`)
  * **Body:** `{ "reward_id": 1 }`
  * **Logika:** Generate `voucher_code` unik format `CLN-VCR-XXXX` (4 karakter alfanumerik acak), jalankan `INSERT INTO user_vouchers` (trigger otomatis mengecek kecukupan poin dan memotong saldo).
* **`GET /api/rewards/my-vouchers`** (Role: `pelanggan`)
  * **Logika:** Mengambil daftar `user_vouchers` milik `req.user.id` di-join dengan `rewards` untuk menampilkan katalog voucher aktif (`is_used = 0`) maupun riwayat terpakai.
* **`GET /api/dashboard/summary`** (Role: `kasir`)
  * **Logika:** Menggabungkan hasil `SELECT * FROM vw_dashboard_summary` dan `SELECT * FROM vw_daily_revenue_7days` ke dalam satu respons JSON.

---

## 5. Non-Goals & Acceptance Criteria (Lapisan Backend)

### Non-Goals
* Tidak menggunakan Webhook publik Midtrans (karena backend berjalan di lingkungan development/serverless tanpa IP statis khusus webhook); sinkronisasi pembayaran menggunakan mekanisme aktif `POST /api/orders/:id/sync-payment`.
* Tidak menggunakan penyimpanan object cloud pihak ketiga (seperti AWS S3); file foto bukti pakaian disimpan di direktori lokal `/uploads` dan disajikan secara statis oleh Express.js.

### Acceptance Criteria
* [ ] Semua endpoint yang dilindungi `checkRole(['kasir'])` mengembalikan status `403 Forbidden` jika diakses menggunakan token JWT milik `pelanggan`.
* [ ] Upload file gambar di atas $2\text{ MB}$ atau selain format JPG/PNG/WEBP ditolak dengan status `400 Bad Request`.
* [ ] Pengiriman 2 request `POST /api/orders` secara bersamaan saat hanya tersisa 1 mesin `'tersedia'` menghasilkan 1 order berstatus `'proses_cuci'` dan 1 order berstatus `'antre'` tanpa bentrok mesin.