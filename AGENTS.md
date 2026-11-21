# AGENTS.md — aturan kerja Cleano

Dokumen ini mengikat setiap agen (dan manusia) yang menyentuh repositori ini.

## 1. Commit dan push hanya ke branch fitur

**Dilarang** `git push origin develop`, `git push origin main`, dan merge ke
keduanya. Pemilik repositori yang melakukan merge lewat GitHub.

Alur yang benar:

```
git checkout develop && git pull --ff-only
git checkout -b feature/<nama>
# kerja, uji, lapor
git add … && git commit
git push -u origin feature/<nama>
# berhenti. Jangan merge. Beri tahu pemilik untuk membuka PR.
```

Konsekuensi yang harus diterima: branch tidak boleh ditumpuk lebih dari satu
lapis. Kalau pekerjaan berikutnya bergantung pada branch yang belum di-merge,
tunggu merge-nya atau tanyakan pemilik — jangan bercabang dari branch fitur lain
tanpa izin, karena PR akan memuat commit PR sebelumnya.

## 2. Jangan commit sebelum diminta

Selesai kerja → jalankan uji → laporkan hasil → **berhenti**. Commit hanya
setelah ada instruksi eksplisit. Pesan commit ditulis dalam bahasa Indonesia,
bentuk `tipe(lingkup): ringkasan`, dengan badan yang menjelaskan *mengapa*.

## 3. Bahasa

Laporan, komentar kode, pesan galat API, dan pesan commit: **Indonesia**.
Pengenal kode (nama variabel, fungsi, tabel, kolom, rute) tetap bahasa Inggris.

## 4. Uji sebelum melapor

Tidak ada laporan "selesai" tanpa bukti. Minimal:

```
cd cleano-backend
npm run check
npm run test:auth && npm run test:lookup && npm run test:master
npm run test:orders-create && npm run test:orders-list
npm run test:orders-status && npm run test:sync-payment
npm run test:dashboard && npm run test:rewards && npm run test:hardening
```

Sertakan jumlah asersi per suite di laporan. Suite baru wajib disertai uji
mutasi: rusak sengaja satu baris, pastikan suite gagal, kembalikan berkasnya.

## 5. Database

- **Aiven MySQL 8 adalah satu-satunya database.** Tidak ada MySQL lokal, tidak
  ada SQLite, tidak ada data palsu di memori.
- Skema berubah **hanya** lewat `database_schema.sql`, dan versi di berkas itu
  dinaikkan. Jangan menambal skema dari kode backend.
- **Jangan pernah menduplikasi logika trigger dengan `UPDATE` manual.** Harga,
  diskon, total, `paid_at`, poin, dan penandaan voucher milik trigger
  (`trg_before_insert_order`, `trg_before_insert_user_voucher`,
  `trg_before_update_order`). Backend yang menulis ulang nilai itu akan
  berbeda pendapat dengan trigger dan kalah diam-diam.
- Order dan voucher **tidak bisa dihapus** (`L-07`, `L-02`). Setiap uji tulis
  harus berjalan di dalam transaksi lalu `ROLLBACK`, atau menghapus berdasarkan
  awalan data uji di blok `finally`.

## 6. Sisa data uji

Skrip uji tidak boleh meninggalkan baris maupun berkas. Hapus berdasarkan
**awalan** (mis. `email like 'b10-%'`), bukan daftar id yang "seharusnya"
dibuat — mutasi yang mematikan penjaga mengubah jumlah baris yang lahir.
Verifikasi di akhir: hitung ulang dan laporkan `sisa 0`.

## 7. Berkas yang tidak perlu

Repositori ini bukan tempat eksperimen. Jangan menambah berkas yang tidak
diminta: tidak ada skrip sekali pakai yang tertinggal, tidak ada `*.bak`,
tidak ada folder `tmp/`. Skrip probe sementara dihapus setelah dipakai.

## 8. Rahasia

`.env` tidak pernah di-commit. Nilai rahasia tidak ditulis di dokumen, laporan,
pesan commit, atau log. `describe()` di `src/utils/logger.js` hanya mengambil
field yang aman — jangan menyalin objek error utuh ke log.

## 9. Karpathy Guidelines (Selalu Aktif Saat Menulis Kode)

Pedoman perilaku wajib yang selalu dieksekusi saat menulis, mengubah, atau me-refactor kode:

1. **Think Before Coding (Pikirkan Sebelum Menulis Kode):**
   - Jangan berasumsi diam-diam. Jangan menyembunyikan kebingungan.
   - Ungkapkan asumsi secara eksplisit sebelum implementasi; tanyakan jika ragu.
   - Jika ada beberapa interpretasi, sampaikan opsi — jangan memilih diam-diam.
   - Jika ada pendekatan yang lebih sederhana, utarakan. Tolak kompleksitas yang tidak perlu.
   - Jika ada yang ambigu atau kurang jelas, berhenti dan tanyakan terlebih dahulu.

2. **Simplicity First (Utamakan Kesederhanaan):**
   - Tulis kode seminimal mungkin yang menyelesaikan masalah. Jangan berspekulasi.
   - Tidak menambah fitur di luar yang diminta.
   - Tidak membuat abstraksi untuk kode yang hanya dipakai sekali.
   - Tidak menambah fleksibilitas atau konfigurasi berlebihan yang tidak diminta.
   - Jika menulis 200 baris padahal bisa 50 baris, sederhanakan dan tulis ulang.

3. **Surgical Changes (Perubahan Presisi & Terisolasi):**
   - Sentuh hanya baris/berkas yang wajib diubah untuk tugas tersebut.
   - Jangan "memperbaiki" kode, komentar, atau format di sekitarnya yang tidak rusak.
   - Selaraskan dengan gaya kode yang ada.
   - Bersihkan dependensi/variabel/fungsi yang menjadi tidak terpakai akibat perubahan kita.
   - Setiap baris yang diubah harus dapat ditelusuri langsung ke permintaan pengguna.

4. **Goal-Driven Execution (Eksekusi Berbasis Verifikasi):**
   - Tentukan kriteria sukses sebelum mulai. Verifikasi secara berulang (*loop*) sampai terbukti berhasil.
   - Setiap tugas multi-tahap harus diawali rencana ringkas beserta langkah verifikasinya:
     ```
     1. [Langkah] → verifikasi: [uji]
     2. [Langkah] → verifikasi: [uji]
     ```
   - Tidak menandai selesai tanpa bukti pengujian konkret.
