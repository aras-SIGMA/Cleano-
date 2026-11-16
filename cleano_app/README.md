# cleano_app

Aplikasi Flutter Cleano — satu aplikasi, dua portal:

- **Portal Kasir** (PRD-03): dashboard omzet, POS transaksi, estafet mesin 1-ketukan.
- **Portal Pelanggan** (PRD-04): pelacakan cucian, kartu QR member, tukar poin.

Backend berada di repo `cleano-backend/` (Express + Aiven MySQL + Midtrans).

## Status

**Tahap inisiasi.** Fondasi siap, fitur belum dibuat:

| Sudah ada | Belum ada |
|---|---|
| Scaffold Android/iOS/Web | Seluruh layar & navigasi |
| Dependensi terpasang | Model (`user_model`, `order_model`, dst.) |
| Tema `#0F4C81` | `auth_service`, `order_service`, `master_service` |
| `ApiService` + auto-inject JWT | Widget QR scanner & WebView Snap |
| Konstanta endpoint | Ekspor laporan CSV/PDF |
| Formatter Rupiah/tanggal/sensor WA | State management |
| `.env` reader | — |

`main.dart` saat ini menampilkan layar bootstrap yang hanya memperlihatkan `API_BASE_URL`
terbaca, sebagai bukti konfigurasi bekerja.

## Setup

```bash
flutter pub get
cp .env.example .env      # Windows: copy .env.example .env
```

Isi `.env`:

| Variabel | Nilai |
|---|---|
| `API_BASE_URL` | `http://10.0.2.2:3000` (emulator Android)<br>`http://localhost:3000` (iOS/Web)<br>`http://<IP-LAN>:3000` (perangkat fisik) |
| `MIDTRANS_CLIENT_KEY` | Client Key Midtrans **Sandbox** (aman di frontend) |

`.env` sudah masuk `.gitignore` — jangan di-commit.

## Menjalankan

```bash
flutter run -d chrome     # web
flutter run -d emulator-5554   # android
```

Butuh backend jalan di `cleano-backend` (`npm run dev`).

## Verifikasi

```bash
dart analyze lib   # harus: No issues found!
flutter test       # 4 tes formatter
```

## Struktur

Sesuai PRD-03 §2 dan PRD-04 §2.

```
lib/
├── main.dart
├── core/
│   ├── constants/api_constants.dart   path endpoint + pembacaan .env
│   ├── theme/app_theme.dart           primer #0F4C81, Material 3
│   └── utils/formatters.dart           Rupiah, tanggal id_ID, sensor WA
└── services/
    └── api_service.dart                Dio + Bearer JWT + ApiException
```

Folder yang akan menyusul: `models/`, `screens/auth/`, `screens/kasir/`,
`screens/pelanggan/`, dan sisa `services/`.

## Catatan teknis

- **`.env` dibaca via `flutter_dotenv`** dan didaftarkan sebagai asset di `pubspec.yaml`.
  Kalau menambah variabel, tambahkan juga di `.env.example`.
- **`Intl` perlu `initializeDateFormatting('id_ID')`** — sudah dipanggil di `main()`
  sebelum `runApp`. Tanpa ini `DateFormat` melempar error saat runtime.
- **Android**: `usesCleartextTraffic=true` agar backend `http://` lokal bisa diakses.
  Hapus/ketatkan ini saat backend sudah HTTPS.
- **iOS**: izin kamera & galeri sudah dideklarasikan di `Info.plist`.
- **`flutter build web` gagal di path ini** karena folder proyek mengandung `#`
  (`AAS#1`) — karakter itu diperlakukan sebagai URI fragment oleh kompiler web Dart.
  `dart analyze`, `flutter test`, dan build Android/iOS tidak terdampak. Kalau suatu saat
  perlu build web, pindahkan proyek ke path tanpa `#`.
- **Server Key Midtrans tidak boleh masuk aplikasi ini.** Hanya Client Key.