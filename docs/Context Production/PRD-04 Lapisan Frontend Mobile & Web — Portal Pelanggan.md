# PRD-04: LAPISAN FRONTEND FLUTTER — PORTAL PELANGGAN (`pelanggan`)

* **ID Dokumen:** PRD-04
* **Lapisan Arsitektur:** Presentation Layer — Customer Tracking & Loyalty Module (Flutter Mobile & Web)
* **Target Implementasi:** Antigravity IDE (Flutter Customer UI, QR Rendering, Read-Only Tracking)
* **Paket Utama:** `qr_flutter` (render QR Member & QR Voucher), `shared_preferences`, `dio` / `http`

---

## 1. Masalah Pelanggan yang Diselesaikan

1. **Ketidakpastian Progres Cucian:** Pelanggan tidak perlu lagi mengirim pesan WhatsApp berulang kali untuk menanyakan apakah cucian sudah dicuci atau siap diambil.
2. **Kekhawatiran Keamanan & Transparansi Barang:** Pelanggan dapat melihat langsung foto bukti kondisi awal pakaian yang diambil kasir saat *drop-off*, nomor mesin cuci yang memproses pakaiannya, atau sisa menit tunggu antrean.
3. **Risiko Kebocoran Akun Saat Titip Cucian:** Pelanggan sering menitipkan pakaian kotor melalui anggota keluarga atau kurir ojek online. Kartu QR Member Cleano dirancang tanpa menampilkan alamat email login agar kredensial akun tetap aman.
4. **Minimnya Insentif Pelanggan Tetap:** Sistem Cleano Rewards memberikan poin otomatis (termasuk *Bonus 2x Poin*) yang dapat ditukar menjadi QR Voucher potongan harga sekali pakai.

---

## 2. Arsitektur Modul Pelanggan & Alur Data

Portal Pelanggan beroperasi dengan prinsip **Read-Only pada Transaksi + Self-Service pada Loyalti**. Identitas pelanggan diambil sepenuhnya dari *payload* token JWT yang tersimpan di `shared_preferences`, sehingga pelanggan tidak pernah bisa mengakses data pesanan maupun voucher milik pengguna lain.

```text
cleano_app/lib/screens/pelanggan/
├── pelanggan_main_nav.dart           # BottomNavigationBar (3 Tab Utama)
├── pelanggan_tracking_screen.dart    # Tab 1: Pelacakan Order Aktif & Riwayat
├── pelanggan_qr_card_screen.dart     # Tab 2: Kartu QR Member Berprivasi Tinggi
└── pelanggan_rewards_screen.dart     # Tab 3: Katalog Tukar Poin & Dompet QR Voucher
```

---

## 3. Spesifikasi Fitur & Layar Portal Pelanggan

### 3.1 Tab 1: Beranda & Pelacakan Cucian Real-Time (`pelanggan_tracking_screen.dart`)
* **Sumber Data:** `GET /api/orders` (API otomatis memfilter berdasarkan `user_id` di token JWT).
* **Komponen UI:**
  1. **Header Sambutan & Ringkasan Poin:** Menampilkan sapaan nama pelanggan, badge **Tier Member** (*Silver* / *Gold* / *Platinum*), dan saldo poin aktif saat ini.
  2. **Kartu Pesanan Aktif (Highlight):**
     * Kode Pesanan (`CLN-YYYYMMDD-XXXX`) dan nama paket layanan + berat (`kg`).
     * **Visual Progress Stepper (4 Tahap):** `Antre` $\rightarrow$ `Proses Cuci / Diproses` $\rightarrow$ `Siap Diambil` $\rightarrow$ `Selesai`.
     * **Indikator Mesin / Antrean:**
       * Jika status `proses_cuci`: Menampilkan badge hijau **"Sedang Dicuci di Mesin [MC-01]"** beserta estimasi jam selesai (`machine_finish_at`).
       * Jika status `antre`: Menampilkan badge kuning **"Menunggu Antrean — Estimasi $\pm$ [queue_wait_minutes] Menit"**.
     * **Status Pembayaran:** Badge `LUNAS` atau `BELUM BAYAR`.
  3. **Detail Transparansi & Bukti Foto *Drop-Off*:**
     * Saat kartu pesanan ditekan, muncul halaman/bottom-sheet detail yang menampilkan **foto kondisi awal pakaian** (`image_url`), catatan khusus, rincian harga (*Subtotal*, *Diskon Voucher*, *Total Bayar*), serta tombol muat ulang (*Pull-to-Refresh*).
  4. **Tab Riwayat Selesai:** Daftar pesanan berstatus `selesai` beserta informasi jumlah poin yang diperoleh dari transaksi tersebut.

### 3.2 Tab 2: Kartu QR Member Berprivasi Tinggi (`pelanggan_qr_card_screen.dart`)
* **Tujuan Desain:** Memudahkan proses *drop-off* di kasir, baik dibawa langsung oleh pemilik akun maupun dikirim berupa *screenshot* ke keluarga/kurir pengantar.
* **Spesifikasi Visual & Aturan Privasi (Wajib Diterapkan):**
  1. **Kode QR Utama (`qr_flutter`):** Hanya mengenkode string murni **`member_code`** (contoh: `MBR-0001`).
  2. **Informasi Teks di Kartu:**
     * **Nama Lengkap Pemilik Akun** (contoh: *Rina Marlina*).
     * **Badge Tier Member** dengan warna berbeda (*Silver*: Abu-abu metalik, *Gold*: Emas, *Platinum*: Biru gelap/biru kristal).
     * **Kode Teks Member** (`MBR-0001`) di bawah gambar QR sebagai cadangan jika kamera kasir sulit memindai.
     * **Nomor WhatsApp Tersensor:** Diformat otomatis di sisi klien menjadi **`0812-****-7890`** (4 digit awal dan 4 digit akhir).
  3. **Larangan Privasi:** **DILARANG** menampilkan alamat `email` pada layar Kartu QR Member untuk mencegah penyalahgunaan kredensial login apabila gambar kartu dibagikan kepada pihak ketiga.

### 3.3 Tab 3: Cleano Rewards & Dompet QR Voucher (`pelanggan_rewards_screen.dart`)
* **Sumber Data:** `GET /api/rewards` dan `GET /api/rewards/my-vouchers`.
* **Komponen UI:**
  1. **Banner Informasi Poin & Bonus 2x:**
     * Menampilkan saldo poin aktif, progress bar menuju Tier berikutnya (*Gold* di $100\text{ poin}$, *Platinum* di $300\text{ poin}$), serta info promo *"Dapatkan Bonus 2x Poin untuk cucian $\ge 5\text{ kg}$ atau paket Express!"*.
  2. **Sub-Tab Katalog Tukar Poin:**
     * Menampilkan daftar promo aktif (`is_active = 1`) beserta judul, deskripsi, nominal diskon (Rp), dan biaya poin (`points_required`).
     * Tombol **Tukar Poin** aktif jika `user.points >= points_required`. Saat ditekan, muncul dialog konfirmasi lalu memanggil `POST /api/rewards/redeem`.
  3. **Sub-Tab Voucher Saya (Hybrid QR + Teks):**
     * Menampilkan daftar voucher hasil klaim yang masih aktif (`is_used = 0`).
     * Setiap kartu voucher menampilkan **Gambar QR Code (`CLN-VCR-XXXX`)**, **Kode Teks Vouchernya** di bawah QR (untuk input manual jika diperlukan), nominal potongan diskon, dan badge mencolok **`1x Pakai`**.
     * Voucher yang sudah dipakai (`is_used = 1`) berpindah ke bagian riwayat dengan tampilan redup dan label **`Sudah Terpakai`**.

---

## 4. Non-Goals & Acceptance Criteria (Portal Pelanggan)

### Non-Goals
* Pelanggan tidak dapat membuat pesanan mandiri dari aplikasi (alur transaksi murni kasir-sentris agar penimbangan berat dan pengambilan foto fisik pakaian tetap terverifikasi di meja kasir).
* Pelanggan tidak melakukan pembayaran Midtrans langsung dari HP pelanggan; seluruh pembayaran diproses terpusat di perangkat kasir.

### Acceptance Criteria
* [ ] Aplikasi pelanggan tidak menampilkan tombol tambah, edit, atau hapus pada daftar pesanan maupun master layanan/mesin.
* [ ] Layar Kartu QR Member menampilkan Nama, Badge Tier, Kode `MBR-XXXX`, dan Nomor HP tersensor (`0812-****-7890`), serta dipastikan **tidak mengandung** teks alamat email.
* [ ] Penukaran poin berhasil mengurangi saldo poin secara instan dan memunculkan QR Voucher baru (`CLN-VCR-XXXX`) pada tab *Voucher Saya*.
* [ ] Voucher yang telah dipindai kasir pada transaksi otomatis berubah status menjadi `Sudah Terpakai` saat halaman dimuat ulang.