# PRD-05: LAPISAN QUALITY ASSURANCE, KEAMANAN & DEPLOYMENT

* **ID Dokumen:** PRD-05
* **Lapisan Arsitektur:** Cross-Cutting Concerns — Security, QA Testing, CI/CD & Cloud Deployment
* **Target Implementasi:** Antigravity IDE (Testing Suite, Git Workflow, Aiven & Vercel/Netlify Deployment)
* **Jadwal Target:** 7 Hari Kerja (16 November 2026 – 22 November 2026)

---

## 1. Masalah Kualitas & Keamanan yang Diselesaikan

1. **Kebocoran Hak Akses Antar-Role:** Mencegah eskalasi hak akses di mana akun `pelanggan` mencoba mengakses endpoint admin/kasir.
2. **Penyalahgunaan Voucher & Konflik Mesin:** Memastikan sistem tahan terhadap *double-submit* saat klaim poin, pemindaian ulang voucher sekali pakai, serta tabrakan alokasi drum mesin cuci saat jam sibuk.
3. **Kegagalan Konfigurasi Cloud Production:** Menjamin transisi dari lingkungan lokal ke Aiven Cloud MySQL (SSL + Trigger permissions) dan hosting API/Web berjalan mulus tanpa error koneksi.

---

## 2. Standar Keamanan Berlapis (*Defense-in-Depth*)

| Lapisan | Mekanisme Pengamanan | Implementasi Teknis |
| :--- | :--- | :--- |
| **Transport & Koneksi DB** | Enkripsi TLS/SSL | Koneksi `mysql2` ke Aiven Cloud wajib menyertakan konfigurasi `ssl: { rejectUnauthorized: false }`. |
| **Autentikasi & Kredensial** | Password Hashing & JWT | Password di-hash menggunakan `bcrypt` ($10\text{ salt rounds}$); sesi dikelola dengan JWT (`expiresIn: '24h'`). |
| **Otorisasi (RBAC)** | Middleware Role Guard | Pemisahan tegas antara `kasir` dan `pelanggan` pada rute mutasi data (`POST`, `PUT`, `PATCH`, `DELETE`). |
| **Validasi Input & Upload** | Multer & SQL Prepared Statements | Seluruh query menggunakan *parameterized statements* (`?`) untuk mencegah *SQL Injection*; upload foto dibatasi maksimal $2\text{ MB}$ (JPG/PNG/WEBP). |
| **Integritas Transaksi** | `FOR UPDATE` & `CHECK` Constraints | Penguncian baris saat alokasi mesin dan validasi voucher; constraint `points >= 0` dan `weight > 0` di level tabel. |
| **Privasi Antarmuka** | Data Masking QR Member | Penyensoran nomor telepon (`0812-****-7890`) dan penghapusan email dari tampilan Kartu QR Member. |

---

## 3. Skenario Pengujian End-to-End (13 Blackbox Test Cases)

Seluruh skenario berikut wajib lulus pengujian sebelum proyek dinyatakan selesai:

| Kode | Skenario Pengujian | Langkah & Input Uji | Hasil yang Diharapkan |
| :--- | :--- | :--- | :--- |
| **TC-01** | Registrasi & Auto-Member ID | Daftar akun pelanggan baru dengan email & nomor HP unik. | Status `201 Created`, password tersimpan dalam hash Bcrypt, dan kode `MBR-XXXX` terbentuk otomatis. |
| **TC-02** | Tolak Duplikasi Email/HP | Daftar menggunakan nomor HP atau email yang sudah terdaftar. | Status `400 Bad Request` dengan pesan penolakan duplikasi. |
| **TC-03** | Login & Routing Per Role | Login menggunakan akun `kasir` dan akun `pelanggan`. | Token JWT diterbitkan; kasir diarahkan ke Dashboard Kasir, pelanggan ke Portal Pelacakan. |
| **TC-04** | Proteksi RBAC Endpoint | Akun `pelanggan` mengirim `POST /api/orders` atau `POST /api/services`. | Server menolak dengan status `403 Forbidden`. |
| **TC-05** | Validasi Upload Foto Drop-Off | Kasir membuat order tanpa foto atau mengunggah file $> 2\text{ MB}$. | Server menolak transaksi dengan status `400 Bad Request`. |
| **TC-06** | Alokasi Mesin Otomatis | Buat order layanan `requires_machine = 1` saat `MC-01` berstatus `tersedia`. | Order berstatus `proses_cuci`, `machine_id` terisi `MC-01`, status mesin berubah menjadi `digunakan`. |
| **TC-07** | Estimasi Antrean Mesin Penuh | Buat order baru saat seluruh mesin aktif berstatus `digunakan`. | Order berstatus `antre`, `machine_id = null`, dan `queue_wait_minutes` terisi selisih menit mesin tercepat. |
| **TC-08** | Pembayaran Tunai & Midtrans Snap | Buat 1 order `tunai` dan 1 order `midtrans` lalu jalankan `/sync-payment`. | Order tunai langsung `lunas`; order Midtrans membuka Snap WebView dan menjadi `lunas` setelah sinkronisasi. |
| **TC-09** | Konfirmasi Estafet Mesin (1-Tap) | Ubah order di `MC-01` ke `siap_diambil` saat ada antrean, lalu konfirmasi pop-up. | Pop-up menampilkan antrean FIFO terdepan; setelah dikonfirmasi, `MC-01` berpindah ke order tersebut dan timer baru aktif. |
| **TC-10** | Pelacakan Real-Time Pelanggan | Pelanggan membuka layar pelacakan order miliknya. | Menampilkan progres tahapan, kode mesin/menit tunggu, dan foto bukti pakaian; order pengguna lain tidak terlihat. |
| **TC-11** | Dual-Lookup Member & Privasi QR | Kasir memindai QR `MBR-0001` atau mencari nomor HP pelanggan. | Data pemilik akun & Tier tampil otomatis; Kartu QR Member menyensor nomor WA dan tidak menampilkan email. |
| **TC-12** | Klaim Poin & Validasi QR Voucher 1x | Pelanggan menukar poin ke `CLN-VCR-XXXX`, dipakai kasir 1x, lalu dipindai lagi. | Scan pertama memotong `total_price` dan set `is_used = 1`; scan kedua ditolak dengan status `400 Bad Request`. |
| **TC-13** | Bonus 2x Poin & Grafik Omzet 7 Hari | Selesaikan (`selesai`) order seberat $6\text{ kg}$ ($\ge 5\text{ kg}$) dan buka Dashboard Kasir. | Poin pelanggan bertambah $2\times$ lipat, Tier ter-update, dan grafik batang omzet 7 hari serta ekspor CSV/PDF terisi akurat. |

---

## 4. Alur Git & Pipeline Deployment

### 4.1 Strategi Branching GitHub (`aras-SIGMA/cleano-laundry-system`)
* `main`: Kode produksi stabil yang siap di-deploy.
* `develop`: Cabang integrasi utama selama pengembangan.
* `feat/auth-rbac`: Fitur autentikasi, middleware JWT, dan CRUD master data.
* `feat/order-machine-midtrans`: Fitur transaksi POS, alokasi mesin FIFO, Midtrans Snap, dan Cleano Rewards.
* `feat/flutter-ui`: Implementasi antarmuka Flutter Kasir dan Pelanggan.

### 4.2 Langkah Deployment Production
1. **Database (Aiven Cloud MySQL):**
   * Aktifkan `log_bin_trust_function_creators = ON` pada menu *Advanced Parameters*.
   * Eksekusi `database_schema.sql` dan verifikasi keberadaan 6 tabel, 4 trigger, 3 view, serta akun *seeder* (`kasir@cleano.id` dan `rina@gmail.com`).
2. **Backend API (Vercel / Netlify Functions atau VPS Node.js):**
   * Atur seluruh *Environment Variables* (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL=true`, `JWT_SECRET`, `MIDTRANS_SERVER_KEY`, `MIDTRANS_IS_PRODUCTION=false`).
   * Verifikasi endpoint `GET /api/health` mengembalikan `200 OK`.
3. **Frontend (Flutter Web & Android APK):**
   * Arahkan `baseUrl` pada `api_constants.dart` ke URL deployment backend.
   * Jalankan `flutter build web --release` untuk versi kasir desktop/tablet dan `flutter build apk --release` untuk perangkat mobile.

---

## 5. Jadwal Eksekusi 7 Hari & Definition of Done (DoD)

* **Hari 1 (16 Nov 2026):** Finalisasi SRS, ERD, eksekusi `database_schema.sql` di Aiven, dan inisialisasi repositori GitHub.
* **Hari 2 (17 Nov 2026):** Setup Express.js, koneksi SSL Aiven, modul Auth JWT + `MBR-XXXX`, Role Guard, dan CRUD `services` & `machines`.
* **Hari 3 (18 Nov 2026):** Implementasi `POST /api/orders` (Multer, `FOR UPDATE` mesin, estafet FIFO), integrasi Midtrans Snap, dan Cleano Rewards.
* **Hari 4 (19 Nov 2026):** Pembuatan endpoint `/dashboard/summary` & `/sync-payment`, pengujian seluruh API di Postman, dan inisialisasi proyek Flutter.
* **Hari 5 (20 Nov 2026):** Pengembangan UI Login/Register, routing berbasis role, dan Dashboard Kasir (grafik `fl_chart` & ekspor laporan).
* **Hari 6 (21 Nov 2026):** Pengembangan Form POS Kasir + Midtrans WebView, serta 3 layar utama Portal Pelanggan (Tracking, Kartu QR Member, Rewards).
* **Hari 7 (22 Nov 2026):** Deployment end-to-end, eksekusi 13 skenario Blackbox Testing (`TC-01` s/d `TC-13`), dan finalisasi dokumentasi proyek.

### Definition of Done (DoD)
Proyek **Cleano** dinyatakan selesai apabila seluruh 13 skenario uji Blackbox lulus tanpa error, aplikasi terhubung secara langsung ke Aiven Cloud MySQL, dan seluruh artefak kode serta dokumentasi tersimpan rapi di repositori GitHub.