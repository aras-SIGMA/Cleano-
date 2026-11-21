# Dokumentasi Desain Sistem & Antarmuka Cleano (Design System & UI/UX Spec)

Dokumen ini mendefinisikan panduan visual, sistem warna (*color palette*), tipografi, komponen antarmuka (*UI components*), dan tata letak layar (*layout specification*) untuk aplikasi **Cleano** (Portal Kasir & Portal Pelanggan).

Acuan desain mengadopsi referensi modern:
- **Header lengkung dinamis (*Curved Hero App Bar*)** dengan nuansa bersih (*clean & airy*).
- **Palet warna "Vibrant Azure & Sky"** sebagai identitas brand utama.
- **Kartu promosi kontras tinggi & tombol aksi (*Claim/Tukar*)** bernuansa emas/amber.
- **Komponen tombol layanan bulat (*Circular Service Icons*)**.
- **Indikator navigasi bawah (*Docked Bottom Bar with Active Indicator Dot*)**.

---

## 1. Filosofi & Karakteristik Desain

| Dimensi | Karakter Visual | Tujuan Emosional & Fungsional |
|:---|:---|:---|
| **Clean & Fresh** | Ruang putih (*whitespace*) luas, aksen es biru (*Ice Blue/Alice Blue*). | Menggambarkan cucian yang bersih, higienis, dan terawat. |
| **Trust & Clarity** | Azure cerah yang tegas, kartu informasi dengan kontras jelas, foto bukti fisik yang besar. | Menghilangkan rasa was-was pelanggan terhadap pakaian tertukar/rusak. |
| **Efficient & Ergonomic** | Tombol aksi primer di zona jangkauan ibu jari (*thumb zone*), input 4-langkah kasir. | Kasir dapat melayani transaksi sibuk di bawah 1 menit per pelanggan. |
| **High Privacy** | Penyensoran nomor telepon (`0812-****-7890`), tanpa tampilan email pada kartu QR. | Pelanggan merasa aman menitipkan cucian melalui keluarga atau kurir. |

---

## 2. Sistem Warna (*Color Palette — Vibrant Azure & Sky*)

Palet warna utama diambil dari referensi **Vibrant Azure (Sky)** dipadukan dengan aksen fungsional status operasional laundry:

```
┌────────────────────────────────────────────────────────────────────────┐
│  VIBRANT AZURE PALETTE                                                 │
│                                                                        │
│   #007FFF        #66CCFF        #F0F8FF        #1E90FF        #FFC107  │
│   Primary       Secondary      Background     Deep Azure      Accent   │
│   (Vibrant)     (Sky Blue)    (Alice Blue)   (Interactive)    (Amber)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Warna Utama (Brand Colors)
- **Primary Brand (Vibrant Azure):** `#007FFF`
  - Penggunaan: Tombol aksi utama (CTA), header aktif, ikon terpilih, border fokus, tab aktif.
- **Secondary / Soft Accent (Sky Blue):** `#66CCFF`
  - Penggunaan: Aksen gradient header, background badge info, progress bar pengisian.
- **Background Tint / Surface (Alice Blue):** `#F0F8FF`
  - Penggunaan: Background utama layar, container icon bulat layanan, latar kartu netral.
- **Deep Azure / Pressed State:** `#1E90FF`
  - Penggunaan: Gradient ujung bawah header, state hover/pressed tombol, teks tautan aktif.

### 2.2 Warna Aksen & Status Operasional
- **Accent Amber / Poin & Reward:** `#FFC107` / `#FFD233`
  - Penggunaan: Tombol "Tukar Poin" / "Claim", bintang rating, ikon promo, badge Member Tier *Gold*.
- **Success / Lunas / Selesai:** `#10B981` (Emerald Green)
  - Penggunaan: Badge status `Lunas`, order `Selesai`, mesin `Tersedia`, indikator checklist.
- **Warning / Menunggu Antrean:** `#F59E0B` (Amber Orange)
  - Penggunaan: Badge status `Antre`, indikator estimasi menit tunggu mesin.
- **Info / Proses Cuci:** `#0284C7` (Sky / Cyan Blue)
  - Penggunaan: Badge status `Proses Cuci` di mesin drum, animasi timer cucian berjalan.
- **Danger / Batal / Error:** `#EF4444` (Coral Red)
  - Penggunaan: Order `Batal`, notifikasi gagal/stok voucher habis, mesin status `Maintenance`.

### 2.3 Tier Badges (Cleano Loyalty)
- **Platinum Member (≥ 300 Poin):** Gradient `#1E3A8A` ke `#3B82F6` (Deep Royal to Azure) dengan teks putih/perak berkilau.
- **Gold Member (100–299 Poin):** `#F59E0B` (Warm Gold/Amber) dengan ikon mahkota/bintang.
- **Silver Member (< 100 Poin):** `#94A3B8` (Cool Metallic Silver).

### 2.4 Warna Netral & Tipografi
- **Text Primary (Headings & Nominal):** `#0F172A` (Slate 900)
- **Text Secondary (Subtitles & Label Form):** `#475569` (Slate 600)
- **Text Muted / Placeholder:** `#94A3B8` (Slate 400)
- **Surface / Card Background:** `#FFFFFF` (Pure White)
- **Border & Card Outlines:** `#E2E8F0` (Slate 200)

---

## 3. Tipografi (*Typography Scale*)

Font utama: **Plus Jakarta Sans** (atau alternatif bawaan sistem Material: **Inter / Roboto**).

| Tingkat | Ukuran | Bobot (*Weight*) | *Line Height* | Penggunaan |
|:---|:---|:---|:---|:---|
| **Display / Hero** | `26px` | Bold (`700`) | `32px` | Total Omzet di Dashboard Kasir, Header Kartu Member. |
| **Heading 1** | `20px` | Bold (`700`) | `28px` | Judul bagian ("Services", "Riwayat Cucian", "Katalog Reward"). |
| **Heading 2** | `16px` | SemiBold (`600`) | `24px` | Nama pelanggan di kartu, nama paket layanan, nomor kode order. |
| **Subtitle / Subhead**| `14px` | Medium (`500`) | `20px` | Rincian harga per kg, durasi estimasi jam, label tab. |
| **Body Regular** | `14px` | Regular (`400`) | `20px` | Catatan cucian, deskripsi promo, teks dialog informasi. |
| **Caption / Tiny** | `12px` | Regular (`400`) | `16px` | Tanggal/waktu transaksi, nomor WhatsApp tersensor, teks bantuan input. |
| **Badge / Overline** | `11px` | SemiBold (`600`) | `14px` | Badge status `LUNAS`, badge `MC-01`, label `1x Pakai`. |

---

## 4. Sistem Komponen & Pola Interaksi (*Component Specifications*)

### 4.1 Curved Hero App Bar (Header Melengkung)
- **Visual:** Container bagian atas dengan latar gradient `#007FFF` ➔ `#1E90FF`.
- **Sudut Lengkung:** `BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))`.
- **Isi Konten Header:**
  - Baris atas: Profil toko/pengguna ("Cleano Outlet 01" / "Halo, Rina Marlina") + Badge Tier.
  - Sisi kanan: Tombol notifikasi atau tombol refresh data dengan latar transparan putih bulat.
  - Baris bawah: Slot pencarian melayang (*Floating Search Bar*) dengan warna dasar `#FFFFFF` dan bayangan lembut.

### 4.2 Tombol Layanan Bulat (*Circular Service Icon Buttons*)
- Mengikuti pola referensi gambar 1:
  - Container lingkaran diameter `64px` dengan warna latar `#F0F8FF` (Alice Blue).
  - Ikon di tengah dengan warna `#007FFF` (diameter ikon `28px`).
  - Efek saat ditekan: Latar berubah menjadi `#007FFF` dan ikon menjadi putih.
  - Label teks di bawah lingkaran (12px SemiBold, terpusat).
- Item layanan Cleano:
  1. **Cuci Komplit Reguler:** Ikon mesin cuci berputar (`Icons.local_laundry_service_rounded`).
  2. **Express 6 Jam:** Ikon petir/kecepatan (`Icons.bolt_rounded`) dengan badge kecil "2x Poin".
  3. **Cuci Kering Lipat:** Ikon tumpukan pakaian bersih (`Icons.dry_cleaning_rounded`).
  4. **Setrika Saja:** Ikon setrika uap (`Icons.iron_rounded`).

### 4.3 Kartu Promosi Kontras Tinggi (*High-Contrast Promo Card*)
- Mengikuti kartu `#SpecialForYou` pada referensi gambar:
  - Latar kartu gelap elegan (`#1E293B`) atau deep azure (`#0F3E6D`) dengan visual tipis mesin cuci/buih busa.
  - Badge sudut kiri atas: `"Promo Aktif!"` dengan latar putih semi-transparan.
  - Judul besar: `"Bonus 2x Poin Cuci Express!"` / `"Diskon Rp 25.000"`.
  - Tombol CTA sudut kanan bawah: Tombol rounded warna kuning amber (`#FFC107`), teks tebal hitam `"Tukar Poin"` atau `"Gunakan"`.

### 4.4 Kartu Order & Stepper Progres (Portal Pelanggan)
- **Latar:** Kartu putih bersih (`#FFFFFF`) dengan border halus `#E2E8F0` dan `borderRadius: 16`.
- **Header Kartu:** Kode order (`CLN-20261119-0001`), tanggal, dan badge status pembayaran (`LUNAS` hijau).
- **Stepper Horizontal 4 Tahap:**
  ```
  [ Antre ] ──── [ Proses Cuci ] ──── [ Siap Diambil ] ──── [ Selesai ]
  ```
  - Lingkaran tahap aktif: Berwarna `#007FFF` dengan animasi denyut lembut (*subtle pulse*).
  - Garis penghubung: Berubah biru jika tahap telah lewat, abu-abu jika belum.
- **Badge Indikator Mesin & Waktu:**
  - Jika `proses_cuci`: Badge biru cerah berikon drum: `"Sedang Dicuci: Mesin MC-01 (Estimasi Selesai 09:45)"`.
  - Jika `antre`: Badge kuning peringatan: `"Menunggu Mesin Kosong — Estimasi ±25 Menit"`.
- **Aksi Detail:** Saat kartu ditekan, membuka bottom sheet yang menampilkan foto bukti fisik pakaian saat drop-off, catatan pakaian, dan rincian tarif.

### 4.5 Kartu Member QR Berprivasi Tinggi (Portal Pelanggan)
- **Tampilan:** Desain bergaya kartu member digital VIP horizontal (`aspectRatio: 1.58`).
- **Gradient Latar:** Sesuai tier (Silver, Gold, Platinum).
- **Elemen Wajib:**
  1. Logo "Cleano Member".
  2. Badge Tier mencolok di sudut kanan atas.
  3. Kode QR di tengah (hanya mengenkode teks `member_code`, misal `MBR-0001`).
  4. Teks kode member di bawah QR code.
  5. Nama Lengkap Pelanggan.
  6. Nomor WhatsApp tersensor (`0812-****-7890`).
- **Aturan Ketat Privasi:** **Dilarang keras memuat alamat email** pada kartu ini agar aman jika tangkapan layar kartu dibagikan kepada keluarga/ojek online.

### 4.6 Dialog Estafet Mesin 1-Ketukan (*1-Tap Relay Modal*) (Portal Kasir)
- Muncul otomatis saat kasir menandai cucian `siap_diambil` dan sistem mendeteksi antrean berikutnya:
  - Header: Ikon mesin cuci berkedip hijau + Judul `"Mesin MC-01 Kini Kosong!"`.
  - Konten: Kartu antrean terdepan FIFO:
    - Nama pelanggan: *Budi Santoso*
    - Layanan: *Cuci Komplit Reguler (4.50 kg)*
    - Kode: `CLN-20261119-0004`
  - Tombol Primer (Biru Azure): `"Ya, Masukkan ke Mesin Sekarang"` ➔ memicu `confirm-relay`.
  - Tombol Sekunder (Garis Netral): `"Nanti Saja"`.

### 4.7 Bottom Navigation Bar (Docked with Active Dot)
- Mengikuti pola referensi gambar 1:
  - Container latar putih murni dengan bayangan elevasi halus.
  - Ikon tidak aktif berwarna `#94A3B8`.
  - Ikon aktif berwarna `#007FFF` dengan **titik lingkaran kecil (*dot indicator*)** tepat di bawahnya.
  - **Navigasi Kasir (4 Menu):**
    1. `Dashboard` (Analitik omzet & performa mesin)
    2. `POS Kasir` (Input drop-off & transaksi baru)
    3. `Pesanan` (Daftar antrean & estafet mesin)
    4. `Kelola Toko` (Master layanan, mesin, promo)
  - **Navigasi Pelanggan (3 Menu):**
    1. `Lacak Cucian` (Beranda & pelacakan progress real-time)
    2. `Kartu Member` (QR Member berprivasi tinggi)
    3. `Rewards` (Katalog tukar poin & dompet voucher QR)

---

## 5. Rencana Layout per Layar (Wireframe Conceptual)

### 5.1 Portal Pelanggan

#### Layar 1: Lacak Cucian (`pelanggan_tracking_screen.dart`)
```
┌───────────────────────────────────────────────┐
│ [Logo Cleano]  Halo, Rina!  [Badge Platinum]  │ (Curved Hero Header #007FFF)
│ Poin Aktif: 150 Poin    [Lihat Promo Reward]  │
├───────────────────────────────────────────────┤
│ #SpecialForYou                                │ (Promo Card Carousel)
│ ┌───────────────────────────────────────────┐ │
│ │ Bonus 2x Poin Cuci Express! [Tukar Poin] │ │
│ └───────────────────────────────────────────┘ │
│                                               │
│ Cucian Aktif (1)                              │
│ ┌───────────────────────────────────────────┐ │
│ │ CLN-20261119-0001             [LUNAS]     │ │
│ │ Cuci Komplit Reguler (4.00 kg)            │ │
│ │ ──●─────────●─────────○─────────○───────  │ │ (Horizontal Stepper)
│ │ Antre   Proses Cuci  Siap Ambil Selesai   │ │
│ │ ┌───────────────────────────────────────┐ │ │
│ │ │ 🔄 Sedang Dicuci: Mesin MC-01         │ │ │ (Active Drum Badge)
│ │ └───────────────────────────────────────┘ │ │
│ └───────────────────────────────────────────┘ │
│                                               │
│ Riwayat Selesai                               │
│ [Kartu Riwayat 1] [Kartu Riwayat 2]           │
└───────────────────────────────────────────────┘
```

#### Layar 2: Kartu QR Member (`pelanggan_qr_card_screen.dart`)
```
┌───────────────────────────────────────────────┐
│ < Kembali        Kartu Member Cleano          │
├───────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────┐  │
│  │ CLEANO VIP MEMBER       [TIER PLATINUM] │  │
│  │                                         │  │
│  │           ┌───────────┐                 │  │
│  │           │  [  QR  ] │                 │  │
│  │           │  [ CODE ] │                 │  │
│  │           └───────────┘                 │  │
│  │             MBR-0001                    │  │
│  │                                         │  │
│  │ RINA MARLINA                            │  │
│  │ No. WhatsApp: 0812-****-7890            │  │ (Tanpa Alamat Email!)
│  └─────────────────────────────────────────┘  │
│                                               │
│ ℹ️ Tunjukkan kartu ini kepada kasir saat drop │
│    off pakaian untuk klaim poin transaksi.    │
└───────────────────────────────────────────────┘
```

#### Layar 3: Cleano Rewards & Voucher (`pelanggan_rewards_screen.dart`)
```
┌───────────────────────────────────────────────┐
│ Cleano Rewards              Saldo: 150 Poin   │
│ Progress ke Platinum: [████████░░] 150/300     │
├───────────────────────────────────────────────┤
│ [ Tab: Katalog Promo ]   [ Tab: Voucher Saya ]│
│                                               │
│ ┌───────────────────────────────────────────┐ │
│ │ Potongan Hemat Rp 5.000      [50 Poin]    │ │
│ │ Diskon langsung semua paket  [TUKAR POIN] │ │
│ └───────────────────────────────────────────┘ │
│ ┌───────────────────────────────────────────┐ │
│ │ QR Voucher Aktif: CLN-VCR-8821            │ │ (Pada Tab Voucher Saya)
│ │ Potongan Rp 5.000            [1x Pakai]   │ │
│ └───────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘
```

---

### 5.2 Portal Kasir

#### Layar 1: Dashboard Kasir (`kasir_dashboard_screen.dart`)
```
┌───────────────────────────────────────────────┐
│ Cleano Kasir — Outlet 01      [Status: Online]│ (Curved Hero Header)
│ Tanggal: 19 Nov 2026                          │
├───────────────────────────────────────────────┤
│ Ringkasan Hari Ini (4 Kartu Metrik)           │
│ ┌───────────────────┐ ┌───────────────────┐   │
│ │ Omzet Hari Ini    │ │ Pesanan Aktif     │   │
│ │ Rp 1.450.000      │ │ 8 Pesanan         │   │
│ └───────────────────┘ └───────────────────┘   │
│ ┌───────────────────┐ ┌───────────────────┐   │
│ │ Siap Diambil      │ │ Mesin Tersedia    │   │
│ │ 3 Pesanan         │ │ 2 / 3 Mesin       │   │
│ └───────────────────┘ └───────────────────┘   │
│                                               │
│ Tren Omzet 7 Hari Terakhir (fl_chart)         │
│ ┌───────────────────────────────────────────┐ │
│ │  Rp  |      █                             │ │
│ │      |  █   █   █                         │ │
│ │      └──┴───┴───┴───┴───┴───┴───          │ │
│ │        13  14  15  16  17  18  19 (Nov)   │ │
│ └───────────────────────────────────────────┘ │
│ [ 📥 Ekspor Laporan Penjualan (CSV / PDF) ]   │
└───────────────────────────────────────────────┘
```

#### Layar 2: Form POS Transaksi Baru (`pos_create_order_screen.dart`)
```
┌───────────────────────────────────────────────┐
│ Transaksi Baru Kasir                          │
├───────────────────────────────────────────────┤
│ 1. Identifikasi Member                        │
│ [ 📷 Scan QR Member ] atau [ Cari No. HP... ] │
│ ┌───────────────────────────────────────────┐ │
│ │ Rina Marlina (MBR-0001)   [Tier: Gold]    │ │ (Kartu Identitas Terverifikasi)
│ │ WA: 0812-****-7890 | Poin: 150            │ │
│ └───────────────────────────────────────────┘ │
│                                               │
│ 2. Detail Pakaian & Layanan                   │
│ [Cuci Komplit Reguler v]  Berat: [ 4.50 ] kg  │
│ [ 📷 Wajib Ambil Foto Bukti Pakaian (Drop-off)]│
│ Catatan: [ Kemeja putih dipisah...          ] │
│                                               │
│ 3. Diskon Voucher                             │
│ [ Scan / Pilih Voucher: CLN-VCR-8821 (-5000) ]│
│ Subtotal: Rp 31.500 | Diskon: Rp 5.000        │
│ Total Bayar: Rp 26.500                        │
│                                               │
│ 4. Metode Pembayaran                          │
│ (•) Tunai (Langsung Lunas)  ( ) Midtrans Snap │
│ [ PROSES TRANSAKSI (Rp 26.500) ]              │
└───────────────────────────────────────────────┘
```

---

## 6. Standar Asset & Micro-Interactions
1. **Elevasi & Bayangan (*Shadows*):**
   - Kartu: `BoxShadow(color: Color(0x0A007FFF), blurRadius: 16, offset: Offset(0, 6))`.
   - Floating Button / Bar: `BoxShadow(color: Color(0x14007FFF), blurRadius: 20, offset: Offset(0, 8))`.
2. **Durasi Animasi:**
   - Transisi halaman: `300ms` kurva `Curves.easeInOutCubic`.
   - Perubahan tab/dot indicator: `200ms` kurva `Curves.fastOutSlowIn`.
   - Stepper update: `400ms`.
3. **Empty & Loading States:**
   - Shimmer placeholder dengan nuansa Alice Blue (`#F0F8FF` ke `#E2E8F0`).
   - Ilustrasi kosong bertema mesin cuci bersih & gelembung busa (*clean laundry illustration*).
