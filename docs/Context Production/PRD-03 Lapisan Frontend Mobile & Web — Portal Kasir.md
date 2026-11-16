# PRD-03: LAPISAN FRONTEND FLUTTER — PORTAL KASIR (`kasir`)

* **ID Dokumen:** PRD-03
* **Lapisan Arsitektur:** Presentation Layer — Cashier & Admin Module (Flutter Mobile & Web)
* **Target Implementasi:** Antigravity IDE (Flutter UI, State Management, API Integration)
* **Paket Utama:** `dio` / `http`, `shared_preferences`, `image_picker`, `mobile_scanner`, `fl_chart`, `webview_flutter`, `pdf` / `csv`

---

## 1. Masalah Operasional Kasir yang Diselesaikan

1. **Lambatnya Pencatatan Manual di Meja Kasir:** Kasir membutuhkan alur input transaksi di bawah $1\text{ menit}$ menggunakan pemindaian QR Member (`MBR-XXXX`) atau pencarian cepat nomor HP, terutama saat cucian dititipkan oleh keluarga atau kurir.
2. **Kesulitan Memantau Performa Usaha Harian:** Pemilik UMKM membutuhkan visualisasi omzet harian, grafik tren pendapatan 7 hari terakhir, serta fitur ekspor rekap penjualan (PDF/CSV) tanpa harus merekap nota kertas secara manual.
3. **Ketidakakuratan Waktu Putar Mesin Cuci:** Tanpa konfirmasi fisik saat memindahkan antrean berikutnya ke dalam drum mesin, timer mesin sering berjalan lebih cepat daripada proses aktual di lapangan.

---

## 2. Arsitektur Frontend & Struktur Direktori

Aplikasi Flutter menggunakan arsitektur berlapis (*Layered Feature Architecture*) yang memisahkan tampilan UI, pengelolaan sesi/state, dan komunikasi HTTP:

```text
cleano_app/lib/
├── main.dart
├── core/
│   ├── constants/api_constants.dart
│   ├── theme/app_theme.dart          # Warna primer #0F4C81, tipografi bersih
│   └── utils/formatters.dart         # Format Rupiah, sensor nomor WA, tanggal
├── models/
│   ├── user_model.dart
│   ├── service_model.dart
│   ├── machine_model.dart
│   ├── order_model.dart
│   └── reward_model.dart
├── services/
│   ├── api_service.dart              # HTTP client dengan auto-inject Bearer JWT
│   ├── auth_service.dart
│   ├── order_service.dart
│   ├── master_service.dart
│   └── export_service.dart           # Generator laporan CSV & PDF
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    └── kasir/
        ├── kasir_main_nav.dart       # BottomNavigationBar / NavigationRail
        ├── kasir_dashboard_screen.dart
        ├── pos_create_order_screen.dart
        ├── kasir_orders_screen.dart
        └── kasir_master_screen.dart
```

---

## 3. Alur Data & Spesifikasi Layar Portal Kasir

### 3.1 Layar 1: Dashboard Kasir & Analitik Omzet (`kasir_dashboard_screen.dart`)
* **Sumber Data:** `GET /api/dashboard/summary` dan `GET /api/orders?status=aktif`.
* **Komponen UI:**
  1. **Grid Kartu Metrik (4 Kartu):** Omzet Lunas Hari Ini (Rp), Pesanan Aktif (Antre & Proses), Pesanan Siap Diambil, dan Kapasitas Mesin Tersedia (`available_machines / total_operational_machines`).
  2. **Grafik Batang Tren Omzet 7 Hari (`fl_chart`):** Menampilkan sumbu X (tanggal 7 hari terakhir) dan sumbu Y (nominal omzet lunas harian) dengan tooltip interaktif saat batang ditekan.
  3. **Tombol Ekspor Rekap Penjualan:** Tombol aksi cepat untuk mengunduh/membagikan laporan transaksi dalam format **CSV** atau **PDF**.
  4. **Daftar Ringkas Order Aktif:** Menampilkan kartu order yang sedang berjalan lengkap dengan kode mesin (`MC-01`) atau estimasi tunggu antrean.

### 3.2 Layar 2: Form POS Transaksi Baru (`pos_create_order_screen.dart`)
* **Alur Kerja Kasir (4 Langkah Cepat):**
  1. **Identifikasi Pelanggan (*Dual-Lookup*):**
     * Tombol **Scan QR Member** membuka kamera (`mobile_scanner`) untuk membaca payload `MBR-XXXX`, **atau** kasir mengetik nomor HP pelanggan di kolom pencarian.
     * Memanggil `GET /api/users/lookup?query=...` lalu menampilkan kartu konfirmasi identitas pelanggan (Nama, Kode Member, Badge Tier *Silver/Gold/Platinum*, dan Nomor WA tersensor `0812-****-7890`).
  2. **Input Layanan, Berat & Bukti Foto:**
     * Dropdown pilihan paket layanan dari `GET /api/services`.
     * Input berat timbangan desimal (contoh: `4.50` kg).
     * Tombol wajib **Ambil Foto Kondisi Pakaian** (`image_picker` kamera/galeri, dikompresi agar ukuran $< 2\text{ MB}$).
     * Kolom catatan khusus pakaian (opsional).
  3. **Diskon QR Voucher (Opsional):**
     * Tombol **Scan QR Voucher** (atau input teks manual `CLN-VCR-XXXX`) untuk memvalidasi voucher milik pelanggan tersebut dan menampilkan rincian kalkulasi otomatis: *Subtotal*, *Potongan Voucher*, dan *Total Bayar*.
  4. **Pemilihan Metode Bayar & Eksekusi:**
     * Pilihan radio button: **Tunai (Langsung Lunas)** atau **Non-Tunai (Midtrans Snap QRIS / VA)**.
     * Saat menekan tombol **Proses Transaksi**, aplikasi mengirim `POST /api/orders`.
     * Jika `midtrans`, aplikasi otomatis membuka halaman pembayaran `snap_redirect_url` di dalam **Midtrans Snap WebView** langsung di layar kasir. Setelah pelanggan memindai QRIS/membayar, kasir menekan tombol **Cek Status Pembayaran** (`POST /api/orders/:id/sync-payment`) hingga muncul badge `LUNAS`.

### 3.3 Layar 3: Manajemen Pesanan & Estafet Mesin 1-Tap (`kasir_orders_screen.dart`)
* **Sumber Data:** `GET /api/orders` dengan filter tab status (`Semua`, `Antre`, `Proses Cuci`, `Siap Diambil`, `Selesai`).
* **Alur Konfirmasi Estafet Mesin (*Auto-Recommend + 1-Tap Confirmation*):**
  1. Pada pesanan berstatus `proses_cuci`, kasir menekan tombol **Tandai Siap Diambil** (`PATCH /api/orders/:id/status` dengan `{ "status": "siap_diambil" }`).
  2. Jika respons API mengembalikan objek `next_queue_order` (karena ada pesanan lain yang sedang `antre`), aplikasi wajib memunculkan **Modal Dialog Konfirmasi Estafet**:
     * *Judul:* `"Mesin MC-01 Kini Kosong!"`
     * *Isi:* `"Antrean terdepan: [CLN-20261115-0004] atas nama [Budi Santoso] (Cuci Komplit Reguler). Masukkan pakaian ke drum sekarang?"`
     * *Aksi Utama:* Tombol **"Ya, Mulai Cuci Sekarang"** $\rightarrow$ memanggil `PATCH /api/orders/:nextId/confirm-relay` sehingga timer mesin baru mulai menghitung mundur.
     * *Aksi Sekunder:* Tombol **"Nanti Saja"** $\rightarrow$ membiarkan mesin tetap `'tersedia'`.
  3. Pada pesanan berstatus `siap_diambil`, kasir menekan tombol **Selesaikan Pesanan** (`status: 'selesai'`), yang otomatis memicu penambahan poin loyalti pelanggan di database.

### 3.4 Layar 4: Manajemen Master Data (`kasir_master_screen.dart`)
* Tab navigasi untuk mengelola data operasional toko:
  * **Tab Layanan (`services`):** Tambah, edit tarif/durasi, dan hapus paket layanan.
  * **Tab Mesin (`machines`):** Tambah unit mesin baru (`MC-XX`) dan ubah status operasional (`tersedia` / `maintenance`).
  * **Tab Promo Rewards (`rewards`):** Tambah katalog promo tukar poin baru dan aktif/nonaktifkan promo (`is_active`).

---

## 4. Non-Goals & Acceptance Criteria (Portal Kasir)

### Non-Goals
* Tidak mendukung pencetakan struk fisik melalui printer termal Bluetooth pada rilis MVP (bukti transaksi disajikan secara digital dan melalui ekspor PDF/CSV).
* Kasir tidak dapat mengedit nominal poin pelanggan secara manual demi menjaga integritas audit loyalti.

### Acceptance Criteria
* [ ] Kasir tidak dapat menekan tombol simpan transaksi jika bukti foto pakaian belum dilampirkan atau berat bernilai $\le 0$.
* [ ] Pembayaran menggunakan metode `midtrans` berhasil membuka halaman Snap WebView dan memperbarui status menjadi `lunas` setelah tombol sinkronisasi ditekan.
* [ ] Modal konfirmasi estafet mesin muncul otomatis saat order `proses_cuci` diselesaikan ke `siap_diambil` ketika masih terdapat antrean aktif.
* [ ] Grafik batang 7 hari di dashboard merender data pendapatan harian dengan akurat dan fitur ekspor menghasilkan file laporan yang dapat dibuka.