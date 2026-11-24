# Task Backend — Cleano

Lapisan: Express 5 + mysql2 (Aiven MySQL 8) + Midtrans Snap + Multer.
Aturan kerja dan konvensi: `PANDUAN-PENGERJAAN.md`.
Jadwal: `JADWAL-DEVELOPMENT.md`.

Legenda status: `[x]` selesai · `[~]` dikerjakan, belum commit · `[ ]` belum

---

## Ringkasan

| # | Paket | Branch | Status | TC |
|---|---|---|---|---|
| B1 | Auth | `feature/auth-register-login` | `[x]` selesai, 4 commit | TC-01,02,03 |
| B2 | Users lookup | `feature/users-lookup` | `[x]` selesai, 2 commit | TC-11 |
| B3 | Master data | `feature/master-data` | `[x]` selesai, di `develop` | TC-04 |
| B4 | Order create | `feature/orders-create` | `[x]` selesai, di `develop` | TC-05,06,07 |
| B5 | Order list | `feature/orders-list` | `[x]` selesai, di `develop` | TC-10 |
| B6 | Order status & estafet | `feature/orders-status` | `[x]` selesai, PR #4 | TC-09,13 |
| B7 | Sync payment | `feature/orders-sync-payment` | `[x]` selesai, PR #5 | TC-08 |
| B8 | Dashboard | `feature/dashboard-summary` | `[x]` selesai, PR #6 | TC-13 |
| B9 | Rewards redeem | `feature/rewards-redeem` | `[x]` selesai, PR #7 | TC-12 |
| B10 | Pengerasan | `feature/hardening` | `[x]` selesai, PR #8 | - |
| B11 | Penutup BE (profil, filter aktif, antrean, normalisasi HP) | `feature/auth-duplicate-check` | `[x]` selesai, belum merge | TC-01,02,03,11 |

Total **10 paket** + B11. B1–B10 sudah di `develop`; B11 menunggu merge.
Yang tersisa di bawah setiap paket adalah **celah yang diketahui**, bukan
deliverable yang belum dikerjakan.

Cakupan akhir: **16/16 endpoint PRD-02** + `GET /api/users/me` (dibutuhkan
PRD-04 §3.1/§3.3, tidak ada di PRD-02) + `?status=aktif` (PRD-03 §4).

---

## B1 — Auth

Branch `feature/auth-register-login` · sudah di `develop` (PR #1). Perbaikan
lanjutan deteksi duplikat ada di `feature/auth-duplicate-check`.

- [x] `POST /api/auth/register` — validasi, bcrypt 10 round, `member_code` `MBR-XXXX` berurutan
- [x] `POST /api/auth/login` — JWT 24 jam, payload `{id, member_code, role}`
- [x] `utils/response.js` — `ok`/`created`/`HttpError`
- [x] `server.js` tidak bind port saat di-`require`
- [x] `src/validators/authValidator.js` — skema zod, batas mengikuti kolom v1.4
- [x] `src/utils/validate.js` — hasil zod → `HttpError` 400
- [x] `test/test-auth.js` — 44 asersi
- [x] Deteksi duplikat membaca tabel (`select … where email = ? or phone = ?`), tidak
      lagi menebak kolom dari teks `err.message`. Perbaikan lanjutan di
      `feature/auth-duplicate-check`; pesan driver memuat *nilai* yang didaftarkan,
      jadi alamat seperti `member_code@gmail.com` dulu membuat bentrok email
      dijawab "Gagal membuat kode member, coba lagi."

**Terbuka:**
- [ ] Batas 128 karakter password mencegah CPU terbuang, tapi bcrypt tetap memotong di 72 byte — dua password yang hanya berbeda di ekor dianggap sama. Tidak masalah untuk POS; jangan dianggap jaminan keamanan.

---

## B2 — Users lookup

Branch `feature/users-lookup` · ditumpuk di atas B1 · 2 commit

- [x] `GET /api/users/lookup?query=` — `checkRole(['kasir'])`
- [x] Cari via `member_code` (case-insensitive) atau `phone` (toleran spasi/strip)
- [x] Respons: `id, name, phone, member_code, points, tier, vouchers[]`
- [x] Voucher aktif saja (`is_used = 0`), JOIN `rewards`
- [x] `test/test-lookup.js` — 44 asersi

**Terbuka:**
- [x] ~~Nomor `+62...` dan `62...` → `404`.~~ Selesai: `src/utils/phone.js`
      menormalkan ketiga awalan ke `08...` sebelum query.
- [ ] `created_at` voucher tidak dipakai siapa pun — hapus.
- [ ] `tierOf` hidup di `authController`; `userController` mengimpornya balik.
      Pindahkan ke `src/utils/tier.js` bila controller auth mulai dipecah.

---

## B3 — Master data

Branch `feature/master-data` · **prasyarat B4**

| Endpoint | Akses |
|---|---|
| `GET /api/services` | semua login |
| `POST /api/services`, `PUT /:id`, `DELETE /:id` | kasir |
| `GET /api/machines` | semua login |
| `POST /api/machines`, `PATCH /:id` | kasir |
| `GET /api/rewards` | semua login (pelanggan: `is_active = 1`) |
| `POST /api/rewards`, `PUT /:id`, `PATCH /:id/toggle` | kasir |

- [x] `serviceController.js` + `serviceRoutes.js`
- [x] `machineController.js` + `machineRoutes.js`
- [x] `rewardController.js` + `rewardRoutes.js`
- [x] Tangkap `ER_ROW_IS_REFERENCED_2` → `409` (FK `on delete restrict`)
- [x] `GET /api/rewards` memfilter `is_active = 1` bila `role === 'pelanggan'`
- [x] `test/test-master.js` — 59 asersi

**Catatan:** tidak ada `DELETE /api/machines` di PRD — jangan ditambahkan.
Mesin dinonaktifkan lewat `status = 'maintenance'`.

**Keputusan yang mengikat:**
- `status = 'digunakan'` **tidak bisa** ditulis lewat API (baik POST maupun PATCH). Status itu milik alur order; mesin yang disetel manual akan tampak terpakai tanpa order dan tidak pernah dilepas.
- `capacity_kg` hanya boleh diisi saat POST. Spesifikasi unit fisik, bukan kondisi sesaat.
- `PUT /api/services/:id` mewajibkan semua field. Default hanya berlaku di POST; kalau default dipakai di PUT, field yang tidak dikirim ditimpa diam-diam (mis. layanan tanpa mesin jadi butuh mesin).
- `PUT /api/rewards/:id` tidak menyentuh `is_active`; status aktif hanya lewat `PATCH /:id/toggle`.
- Semua route ber-`:id` memakai `parseId()` — `:id` non-angka dibalas 400, bukan 500 yang membocorkan SQL.

**Terbuka:**
- [ ] `DELETE /api/services/:id` tidak punya padanan "nonaktifkan". Layanan yang sudah dipakai order akan selalu 409 dan tidak bisa disembunyikan dari POS. Pertimbangkan kolom `is_active` bila ini jadi masalah nyata — ubah skema dulu, jangan tambal di backend.
- [ ] Belum ada paginasi di ketiga endpoint GET. Jumlah layanan/mesin/reward kecil dan terbatas, jadi ditunda.
- [ ] `capacity_kg` dikembalikan MySQL sebagai string (`"8.00"`), bukan angka. Klien Flutter harus mengonversi. Belum diuji dampaknya ke UI.

---

## B4 — Order create

Branch `feature/orders-create` · **paket terberat**

- [x] `POST /api/orders` multipart, `upload.single('image')` wajib
- [x] Validasi `user_id`, `service_id`, `weight > 0`, `payment_method`
- [x] `order_code` `CLN-YYYYMMDD-XXXX` dari `MAX` per tanggal, di dalam transaksi
- [x] Voucher: `SELECT ... FOR UPDATE` pada `user_vouchers` milik `user_id`, `is_used = 0`
- [x] Mesin: `SELECT id FROM machines WHERE status='tersedia' ORDER BY id LIMIT 1 FOR UPDATE`
- [x] Mesin penuh → `status='antre'`, `queue_wait_minutes` dari `MIN(estimated_finish_at)`
- [x] `requires_machine = 0` → `status='sedang_diproses'`, `machine_id=NULL`, `queue=0`
- [x] INSERT — **trigger** mengisi `subtotal/discount/total`, `paid_at`, `customer_tier_snapshot`,
      `points_awarded`, dan menandai voucher terpakai
- [x] Midtrans: `snap.createTransaction()` → `UPDATE snap_token, snap_redirect_url`
- [x] Retry `ER_LOCK_DEADLOCK` (1213) maksimal 3×
- [x] Respons `201` berisi `order_code`, `total_price`, `status`, `snap_redirect_url`
- [x] `test/test-orders-create.js` — 51 asersi

**Jebakan:** jangan kirim `subtotal_price`/`discount_amount`/`total_price` — trigger menolak.
Sudah diuji: trigger menimpa nilai kiriman klien.

**Keputusan yang mengikat:**
- Voucher diterima sebagai `voucher_code` (sesuai PRD-02 §4.3), bukan `voucher_id`.
  Kode dicari dan dikunci di dalam transaksi, lalu `voucher_id` yang di-INSERT.
- `snap_token` **tidak pernah** masuk respons. Hanya `snap_redirect_url`. Aturan yang
  sama berlaku untuk B5 — kolom eksplisit, bukan `select *`.
- `attemptOrder(conn, input)` dipisah dari `placeOrder(input)` supaya skrip uji bisa
  menjalankannya di dalam transaksi sendiri lalu `ROLLBACK`. Order tidak bisa dihapus
  (trigger L-07), jadi rollback satu-satunya cara membersihkan hasil uji.
- Aturan alokasi mesin tinggal di `src/services/orderAllocation.js` karena
  `confirm-relay` (B6) memakai aturan yang sama. Menyalinnya ke dua controller akan
  membuat dua versi yang cepat atau lambat berbeda.
- Retry hanya untuk `ER_LOCK_DEADLOCK` / `ER_LOCK_WAIT_TIMEOUT` / `ER_DUP_ENTRY` pada
  `order_code`. `ER_DUP_ENTRY` dari `uq_orders_voucher` tidak diulang — itu berarti
  voucher sudah dipakai order lain.
- Foto yang sudah tersimpan di disk dihapus kembali bila request ditolak.

**Terbuka:**
- [ ] `for update` pada SELECT voucher belum diuji balapan. Membuktikannya butuh satu
      transaksi yang COMMIT, dan order yang sudah commit tidak bisa dihapus. Penjaga
      nyata jalur ini adalah `uq_orders_voucher` + trigger AFTER INSERT.
- [ ] Panggilan HTTP Midtrans berjalan **di dalam** transaksi (mengikuti PRD-02 §4.3
      langkah 5), sehingga lock voucher/mesin ditahan selama round-trip gateway. Kalau
      latensi Midtrans mulai menahan kasir lain, pindahkan ke pola outbox.
- [x] ~~`queue_wait_minutes` dihitung saat order dibuat dan tidak dihitung ulang.~~
      Selesai di B11: `refreshQueueWaits` dipanggil saat mesin dilepas dan saat
      `confirm-relay` memakai mesin.
- [ ] Kegagalan Midtrans setelah INSERT mengembalikan 502 dan order ikut ter-rollback —
      transaksi Midtrans yang sudah terlanjur dibuat menjadi yatim di sisi gateway.
      Belum ada rekonsiliasi.

---

## B5 — Order list

Branch `feature/orders-list`

- [x] `GET /api/orders` membaca `vw_order_details`
- [x] `?status=` — validasi terhadap enum, plus grup `aktif`
      (`antre` + `proses_cuci` + `sedang_diproses` + `siap_diambil`) untuk dashboard
      kasir (PRD-03 §4)
- [x] Role `pelanggan` → `WHERE user_id = req.user.id`
- [x] **`SELECT` kolom eksplisit** — `snap_token` & `snap_redirect_url` tidak boleh terkirim
      ke pelanggan
- [x] Pagination `?page=&pageSize=` default 20, maks 100
- [x] `test/test-orders-list.js` — 40 asersi, termasuk pelanggan A tidak bisa melihat order B

**Keputusan yang mengikat:**
- `user_id` **selalu** diambil dari token, tidak pernah dari query string. Kalau dari query,
  pelanggan cukup mengubah angkanya untuk membaca order orang lain. Sudah diuji dengan
  `?user_id=<milik budi>` memakai token rina.
- Dua daftar kolom terpisah: `LIST_COLS_KASIR` dan `LIST_COLS_PELANGGAN`. Pelanggan tidak
  menerima `snap_redirect_url`, `customer_name`, `customer_phone`, `member_code`,
  `price_per_kg`, `requires_machine`, `voucher_id`. `snap_token` tidak pernah dikirim ke
  siapa pun, termasuk kasir.
- Urutan `created_at desc, id desc`. `id` ikut diurutkan supaya paginasi stabil ketika dua
  order punya `created_at` identik — tanpa itu ada baris yang terlewat atau muncul dua kali.
- Hitung total memakai `vw_order_details` dengan `where` yang sama seperti query datanya.
  Menghitung dari tabel `orders` tanpa filter membuat `total`/`totalPages` membocorkan
  jumlah order pelanggan lain.
- Respons berbentuk `{ items, page, pageSize, total, totalPages }`, bukan array telanjang,
  supaya UI bisa menampilkan "halaman 1 dari N" tanpa menebak.

**Terbuka:**
- [ ] Belum ada filter `?search=` untuk kode order atau nama pelanggan. Ditunda.
- [ ] `GET /api/orders` memakai `offset`, jadi halaman tinggi makin lambat pada data besar.
      Cukup untuk volume satu outlet; ganti ke keyset pagination bila perlu.

---

## B6 — Order status & estafet mesin

Branch `feature/orders-status`

- [x] `PATCH /api/orders/:id/status` — validasi transisi yang sah
- [x] `proses_cuci` → `siap_diambil`: bebaskan mesin (`tersedia`, `estimated_finish_at=NULL`)
- [x] Ambil antrean terdepan `ORDER BY created_at ASC, id ASC LIMIT 1`
- [x] Respons sertakan `next_queue_order` untuk modal 1-ketukan
- [x] `PATCH /api/orders/:id/confirm-relay` — kunci mesin `FOR UPDATE`, set `digunakan` +
      `estimated_finish_at`, order → `proses_cuci`
- [x] `siap_diambil` → `selesai` memicu poin (dikerjakan trigger, backend tidak menyentuh)
- [x] `test/test-orders-status.js` — 41 asersi (transaksi + `ROLLBACK`)
- [x] `queue_wait_minutes` dihitung ulang setiap kali mesin dilepas **atau** dipakai
      lewat `confirm-relay` (`refreshQueueWaits` di `orderStatus.js`)

**Jebakan:** `trg_before_update_order` menjaga sebagian field. Transisi status yang tidak sah
harus ditolak backend — trigger tidak memvalidasi semuanya.

**Keputusan yang mengikat:**
- `TRANSITIONS` menutup keenam nilai enum: `antre → batal`, `proses_cuci → siap_diambil|batal`,
  `sedang_diproses → siap_diambil|batal`, `siap_diambil → selesai|batal`, `selesai` dan `batal`
  final. Status yang tidak ada di tabel tidak pernah lolos.
- **`proses_cuci` tidak bisa jadi tujuan `PATCH /:id/status`.** Endpoint itu tidak membawa
  `machine_id`, jadi order tidak boleh masuk drum tanpa mesin. Hanya `confirm-relay` yang
  menetapkannya. Dijaga dua lapis: validator `z.enum` dan `TRANSITIONS` (tidak ada `proses_cuci`
  sebagai tujuan di status mana pun).
- **Mesin hanya dilepas bila `order.status === 'proses_cuci' && order.machine_id`.** Tanpa syarat
  status, `siap_diambil → selesai` ikut membebaskan mesin yang sudah dipakai order lain, dan order
  itu kehilangan drumnya. Sudah diuji dengan mesin yang sengaja `digunakan` oleh order lain.
- `machine_id` **dipertahankan** di order setelah mesin dilepas — riwayat "dicuci di MC-01" masih
  dibaca portal pelanggan.
- Urutan kunci selalu order dulu, baru mesin, di kedua endpoint. Urutan sebaliknya membuka
  deadlock melingkar antara `status` dan `confirm-relay`.
- `next_queue_order` hanya terisi saat transisi ini benar-benar melepas mesin; `null` berarti
  "tidak ada estafet", sehingga UI tidak perlu membedakan objek kosong.
- `attemptStatusChange`/`attemptConfirmRelay` dipisah dari transaksinya (pola sama dengan B4)
  supaya skrip uji bisa `ROLLBACK`. Order tidak bisa dihapus (trigger L-07).

**Terbuka:**
- [ ] `queue_wait_minutes` hanya dihitung ulang saat ada order yang memicu perubahan
      lewat API. Kalau mesin dibiarkan `digunakan` melewati `estimated_finish_at`
      tanpa ada transisi status, angkanya tetap basi sampai ada order berikutnya.
      Pembersih terjadwal di luar jam kerja adalah jalan keluarnya, bukan backend.
- [ ] Estafet tidak memeriksa `services.requires_machine` — **sudah diperbaiki di B11**:
      `confirm-relay` menolak order yang layanannya `requires_machine = 0`.
- [ ] `selesai` untuk order `midtrans` yang belum lunas tetap diizinkan. Trigger poin mensyaratkan
      `lunas`, jadi poin tidak masuk, tapi statusnya sudah final dan tidak bisa dikembalikan.
      Bergantung pada B7.

---

## B7 — Sync payment

Branch `feature/orders-sync-payment`

- [x] `POST /api/orders/:id/sync-payment` — `checkRole(['kasir'])`
- [x] Panggil Midtrans Core `transaction.status(order_code)`
- [x] `settlement`/`capture` → `UPDATE payment_status='lunas', paid_at=now()`
- [x] Mode stub (server key kosong) → `503` dengan pesan jelas, bukan sukses palsu
- [x] `test/test-sync-payment.js` — 37 asersi (transaksi + `ROLLBACK`)

**Keputusan yang mengikat:**
- **`capture` hanya lunas bila `fraud_status = 'accept'`.** Kartu kredit bisa
  `capture` lalu ditahan pemeriksaan fraud. `capture + challenge` berarti uang belum
  tentu sampai, jadi order tetap `belum_bayar`. `settlement` selalu lunas.
- **`paid_at` tidak pernah ditulis backend.** Trigger `BEFORE UPDATE` yang menstempelnya;
  menulisnya sendiri ditolak L-04. Sudah diuji dengan mutasi yang menambahkan `paid_at = now()`
  — seluruh kasus lunas langsung gagal.
- **`enabled` diperiksa sebelum transaksi dibuka.** Tanpa server key, `503`, bukan sukses palsu.
- **Order sudah lunas tidak memanggil gateway.** Dua klik tombol tidak menghasilkan dua
  round-trip dan dua pesan berbeda.
- **Order tunai ditolak `400`**, bukan 404 — ordernya ada, transaksi Midtrans-nya yang tidak.
- **Order `batal` tidak bisa dilunasi.** Statusnya final dan uangnya tidak punya transaksi
  yang bisa dipertanggungjawabkan.
- **`WHERE payment_status = 'belum_bayar'`** pada UPDATE menutup balapan dua sinkronisasi
  bersamaan tanpa menahan kunci selama round-trip gateway. Baris order sengaja dibaca tanpa
  `FOR UPDATE` karena panggilan HTTP berjalan di antaranya.
- Midtrans `404` (transaksi tidak pernah dibuat) → `409`. Gangguan lain → `502`.

**Terbuka:**
- [ ] Tidak ada rekonsiliasi untuk order `midtrans` yang `snap.createTransaction` gagal setelah
      INSERT: ordernya ada di DB, transaksinya tidak ada di gateway, dan `sync-payment`
      akan selamanya `409`.
- [ ] `expire`/`deny`/`cancel` dari gateway tidak mengubah apa pun di order. Order tetap
      `belum_bayar` dan status order tidak ikut batal — keputusan bisnis belum ada.
- [ ] `refund` tidak ditangani. L-05 melarang `lunas → belum_bayar`, jadi refund harus
      lewat kolom terpisah bila nanti dibutuhkan.

---

## B8 — Dashboard

Branch `feature/dashboard-summary`

- [x] `GET /api/dashboard/summary` — `checkRole(['kasir'])`
- [x] Gabung `vw_dashboard_summary` + `vw_daily_revenue_7days`
- [x] **Isi 7 tanggal** — view tidak memunculkan hari tanpa transaksi
- [x] `test/test-dashboard.js` — 27 asersi

**Keputusan yang mengikat:**
- **Tujuh tanggal dihitung MySQL, bukan Node.** Sesi database berjalan `+07:00`; kalau
  rentang tanggal disusun dengan `Date` di Node, zona waktu mesin server bisa menggeser
  hasilnya satu hari dan grafik menampilkan hari yang salah. Sudah diuji dengan membandingkan
  tanggal terakhir terhadap `curdate()` milik MySQL sendiri.
- **`with recursive` + `left join`** supaya hari tanpa transaksi tetap muncul bernilai 0.
  Tanpa ini grafik batang akan bolong — `vw_daily_revenue_7days` hanya memuat tanggal yang
  punya order lunas.
- **Tanpa `coalesce`.** Kolom yang tidak punya pasangan bernilai `NULL`, dan `Number(null)`
  sudah `0`. `coalesce` di SQL hanya duplikasi. Mutasi yang mengembalikan `null` membuktikan
  tesnya menangkap, bukan mutasi yang sia-sia.
- Semua angka dikonversi ke `number` di controller. `SUM()`/`COUNT()` kembali sebagai string
  desimal, dan `fl_chart` butuh angka — konversi di klien berarti setiap layar mengulanginya.
- Bentuk respons datar: lima kartu di akar objek, tren di `revenue_7_days`. Tidak ada
  pembungkus `summary`/`trend` tambahan yang hanya menambah satu lapis akses.

**Terbuka:**
- [ ] Tidak ada parameter tanggal. Dashboard selalu 7 hari terakhir; laporan rentang bebas
      belum diminta.
- [ ] `today_revenue` memakai `date(paid_at) = curdate()`, jadi `idx_orders_payment_paid`
      tidak terpakai penuh (fungsi pada kolom). Cukup untuk volume satu outlet.

---

## B9 — Rewards redeem

Branch `feature/rewards-redeem`

- [x] `POST /api/rewards/redeem` — `checkRole(['pelanggan'])`, body `reward_id`
- [x] `voucher_code` `CLN-VCR-` + 4 alfanumerik acak, ulang 3× bila `ER_DUP_ENTRY`
- [x] **Jangan potong poin manual** — trigger memotong
- [x] Tangkap `SQLSTATE 45000` dari trigger → `400` dengan `err.message`
- [x] `GET /api/rewards/my-vouchers` — JOIN `rewards`, pisahkan aktif vs terpakai
- [x] `test/test-rewards.js` — 50 asersi (transaksi + `ROLLBACK`)

**Keputusan yang mengikat:**
- **Backend tidak memeriksa dan tidak memotong poin.** `trg_before_insert_user_voucher`
  yang membaca `is_active` dan saldo, menolak dengan `SIGNAL 45000`, lalu memotong poinnya.
  Duplikasi berarti dua tempat memutuskan hal yang sama dan yang kedua bisa berbeda pendapat.
  Mutasi M1 yang menambahkan potongan poin kedua menggagalkan tes (150 → 95, seharusnya 100).
- **`SQLSTATE 45000` dipetakan ke `400` di error handler global**, bukan per-controller.
  Sebelumnya semua penolakan trigger jadi `500` — pelanggan melihat "kesalahan server" untuk
  hal yang sebenarnya salah input. `err.sqlMessage` adalah pesan yang ditulis trigger dan
  sudah berbahasa Indonesia. Mutasi M7 mengembalikannya ke 500 dan tes menangkapnya.
- **Baris user dikunci `FOR UPDATE`** sebelum INSERT. Tanpa itu dua klaim bersamaan
  sama-sama membaca saldo lama, keduanya lolos pemeriksaan trigger, lalu potongan kedua
  membuat `points` negatif dan ditolak `chk_users_points` dengan pesan SQL yang tidak berguna.
  Diuji tanpa `COMMIT`: koneksi lain menahan kunci, klaim kedua harus menunggu.
- **`user_id` selalu dari token**, baik di `redeem` maupun `my-vouchers`. `user_id` di body
  dan di query string diabaikan — sudah diuji dengan keduanya.
- **Kode voucher dibuat backend.** Format `CLN-VCR-XXXX`, alfabet tanpa `0/O/1/I/L` karena
  kode ini dibaca dan diketik manual dari kartu pelanggan.
- **`rute /my-vouchers` didaftarkan sebelum `/:id`** supaya "my-vouchers" tidak dibaca sebagai id.
- `active`/`history` dipisah di service, sesuai PRD-04 §3.3 yang menampilkan dua sub-bagian.

**Terbuka:**
- [ ] `my-vouchers` mengembalikan seluruh riwayat tanpa paginasi. Pelanggan lama bisa
      mengumpulkan ratusan voucher terpakai.
- [ ] QR code voucher digambar di klien dari string `CLN-VCR-XXXX`; backend tidak mengirim
      `png`. Cukup, karena PRD-04 §3.3 memang menampilkan kode teks di bawah QR.
- [ ] Tidak ada endpoint pembatalan klaim. Salah klaim = poin hangus (sesuai L-02).

---

## B10 — Pengerasan

Branch `feature/hardening` · sebelum deploy

- [x] Rate limit `POST /api/auth/login` dan `/register` — 10/15 menit dan 5/jam per IP,
      diatur `AUTH_LOGIN_LIMIT` / `AUTH_REGISTER_LIMIT`
- [x] Helmet / header keamanan — CSP dimatikan karena API hanya mengirim JSON
- [ ] `certs/ca.pem` + `rejectUnauthorized: true` — **mekanisme siap, berkas belum ada**
- [x] Batas ukuran body `express.json()` — `JSON_BODY_LIMIT`, bawaan `1mb`
- [x] Log terstruktur — `src/utils/logger.js`, satu baris JSON, semua `console.*` diganti
- [x] `npm audit` bersih — 0 kerentanan
- [x] `TRUST_PROXY_HOPS` — ember rate limit terpisah per IP di belakang proxy
- [x] `test/test-hardening.js` — 26 asersi

**Keputusan yang mengikat:**
- **`DB_SSL_VERIFY=true` menolak jalan tanpa CA.** Tanpa penanda ini, koneksi tetap
  terenkripsi tapi sertifikat server tidak diverifikasi — penyadap dengan sertifikat
  karangan bisa menyamar sebagai database. Larangan berhenti (fail-closed) lebih baik
  daripada peringatan di log yang tidak dibaca.
- **Rate limit per IP di memori proses.** Cukup untuk satu instance. Bila nanti
  berjalan lebih dari satu, store harus diganti ke Redis — kalau tidak, batasnya
  terbagi per proses dan efektif menjadi N kali lipat.
- **`TRUST_PROXY_HOPS` berisi jumlah hop, bukan `true`.** Di belakang proxy, `req.ip`
  berisi IP proxy; tanpa setting ini semua pengguna berbagi satu ember dan satu
  penyerang mengunci seluruhnya. `true` juga salah: Express mengambil entri paling
  kiri `X-Forwarded-For` yang ditulis klien sendiri, sehingga IP bisa dipalsukan
  untuk mendapat ember baru tiap permintaan.
- **Limiter ikut menghitung permintaan yang ditolak validasi.** Kalau tidak, penyerang
  cukup mengirim body salah agar tebakannya tidak dihitung.
- **Batas bisa dinaikkan lewat env** karena `test-auth` memanggil login/register puluhan
  kali dari IP yang sama; `test-hardening` menurunkannya ke 2 untuk menguji penolakan.
- **Log tidak menyalin seluruh objek error.** `describe()` mengambil nama, pesan, kode,
  `sqlState`, `errno`, `status`, dan stack saja. Error MySQL membawa properti `sql`,
  `sqlMessage`, dan kadang parameter query — menyalin objeknya utuh berisiko menuliskan
  isi tabel ke log.

**Terbuka:**
- [ ] `certs/ca.pem` harus diunduh manual dari dashboard Aiven
      (service → Overview → CA Certificate) dan disimpan di `cleano-backend/certs/`.
      Tidak ada URL publik; CA bersifat per-project dan butuh login.
- [ ] Rate limit masih in-memory. Belum perlu sampai ada lebih dari satu instance.
- [ ] `npm audit` hanya melihat kerentanan yang sudah punya CVE. Tidak menggantikan
      tinjauan dependensi saat menambah paket baru.
- [ ] Belum ada rotasi `JWT_SECRET`; token lama tetap sah sampai kedaluwarsa (24 jam).

---

## B11 — Penutup backend

Branch `feature/auth-duplicate-check` · perbaikan temuan audit + celah yang
memblokir Flutter.

- [x] Deteksi duplikat email/phone dibaca dari tabel, bukan ditebak dari teks
      `err.message` (pesan driver memuat *nilai* yang didaftarkan, sehingga alamat
      seperti `member_code@gmail.com` dulu dijawab "Gagal membuat kode member")
- [x] `GET /api/users/me` — `id, name, phone, email, role, member_code, points, tier`
- [x] `?status=aktif` — grup `antre + proses_cuci + sedang_diproses + siap_diambil`
- [x] Normalisasi nomor `+62…` / `62…` / `08…` → satu bentuk sebelum lookup
- [x] `confirm-relay` menolak order yang layanannya `requires_machine = 0`
- [x] `queue_wait_minutes` dihitung ulang saat mesin dilepas dan saat dipakai
- [x] `test/test-auth.js` 44 · `test-lookup.js` 44 · `test-orders-list.js` 40 ·
      `test-orders-status.js` 41 asersi

**Keputusan yang mengikat:**
- **`/api/users/me` tidak memakai JWT untuk poin.** Token hanya membawa
  `{id, member_code, role}`. Poin dan tier berubah tanpa login ulang (order
  `selesai` menambah poin), jadi keduanya dibaca dari DB setiap permintaan.
  Menaruhnya di token berarti pelanggan melihat saldo lama sampai 24 jam.
  Diuji dengan mengubah `points` di DB lalu memanggil `/me` dengan token lama.
- **`aktif` adalah nama grup di lapisan API, bukan nilai enum.** Kolom `orders.status`
  tetap enam nilai. Pemetaan grup → `IN (...)` ada di controller, bukan di
  validator, supaya validator tetap berisi daftar nilai yang benar-benar sah.
- **`refreshQueueWaits` dipanggil di dua tempat**, bukan satu: pelepasan mesin
  (`status` → `siap_diambil`) dan pemakaian mesin (`confirm-relay`). Keduanya
  mengubah `MIN(estimated_finish_at)` sehingga estimasi antrean berubah.
- **Normalisasi nomor hanya untuk pencarian.** `normalizePhone` mengembalikan
  masukan apa adanya bila bukan angka, supaya pencarian `member_code` tidak
  ikut diubah. Validator registrasi tetap jadi penjaga bentuk nomor yang disimpan.
- **`confirm-relay` memeriksa `requires_machine` sebelum mengunci mesin**, dan
  pemeriksaan status `antre` tetap lebih dulu. Urutan ini membuat pesan galat
  menunjuk alasan yang benar.

**Terbuka:**
- [ ] `queue_wait_minutes` hanya segar saat ada transisi lewat API. Mesin yang
      melewati `estimated_finish_at` tanpa transisi membuat angkanya basi sampai
      order berikutnya. Butuh pembersih terjadwal, bukan perubahan backend.

---

## Pemetaan TC → paket

| TC | Paket |
|---|---|
| TC-01, TC-02, TC-03 | B1 |
| TC-04 | B3, B5 |
| TC-05, TC-06, TC-07 | B4 |
| TC-08 | B4 + B7 |
| TC-09 | B6 |
| TC-10 | B5 |
| TC-11 | B2 |
| TC-12 | B4 + B9 |
| TC-13 | B6 + B8 |