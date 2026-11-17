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
| B5 | Order list | `feature/orders-list` | `[~]` belum commit | TC-10 |
| B6 | Order status & estafet | `feature/orders-status` | `[ ]` | TC-09,13 |
| B7 | Sync payment | `feature/orders-sync-payment` | `[ ]` | TC-08 |
| B8 | Dashboard | `feature/dashboard-summary` | `[ ]` | TC-13 |
| B9 | Rewards redeem | `feature/rewards-redeem` | `[ ]` | TC-12 |
| B10 | Pengerasan | `feature/hardening` | `[ ]` | — |

Total **10 paket**. B1–B9 fitur, B10 sebelum deploy.

---

## B1 — Auth

Branch `feature/auth-register-login` · 4 commit lokal, belum merge

- [x] `POST /api/auth/register` — validasi, bcrypt 10 round, `member_code` `MBR-XXXX` berurutan
- [x] `POST /api/auth/login` — JWT 24 jam, payload `{id, member_code, role}`
- [x] `utils/response.js` — `ok`/`created`/`HttpError`
- [x] `server.js` tidak bind port saat di-`require`
- [x] `src/validators/authValidator.js` — skema zod, batas mengikuti kolom v1.4
- [x] `src/utils/validate.js` — hasil zod → `HttpError` 400
- [x] `scripts/test-auth.js` — 38 asersi

**Terbuka:**
- [ ] Pesan duplikat masih dibedakan dari teks `err.message` (`msg.includes('email')`). Format pesan driver bergantung versi; cabang `uk_users_member` sudah jadi bukti. Ganti dengan `SELECT` cek duplikat di dalam transaksi yang sama. Pindah ke B10.
- [ ] Batas 128 karakter password mencegah CPU terbuang, tapi bcrypt tetap memotong di 72 byte — dua password yang hanya berbeda di ekor dianggap sama. Tidak masalah untuk POS; jangan dianggap jaminan keamanan.

---

## B2 — Users lookup

Branch `feature/users-lookup` · ditumpuk di atas B1 · 2 commit

- [x] `GET /api/users/lookup?query=` — `checkRole(['kasir'])`
- [x] Cari via `member_code` (case-insensitive) atau `phone` (toleran spasi/strip)
- [x] Respons: `id, name, phone, member_code, points, tier, vouchers[]`
- [x] Voucher aktif saja (`is_used = 0`), JOIN `rewards`
- [x] `scripts/test-lookup.js` — 30 asersi

**Terbuka:**
- [ ] Nomor `+62...` dan `62...` → `404`. Normalisasi ke `08...` sebelum query.
- [ ] `created_at` voucher tidak dipakai siapa pun — hapus.
- [ ] `tierOf` diimpor dari `authController` — pindah ke `src/utils/tier.js`.

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
- [x] `scripts/test-master.js` — 59 asersi

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
- [x] `scripts/test-orders-create.js` — 51 asersi

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
- [ ] `queue_wait_minutes` dihitung saat order dibuat dan tidak dihitung ulang ketika
      antrean berubah. B6 yang akan memperbaruinya.
- [ ] Kegagalan Midtrans setelah INSERT mengembalikan 502 dan order ikut ter-rollback —
      transaksi Midtrans yang sudah terlanjur dibuat menjadi yatim di sisi gateway.
      Belum ada rekonsiliasi.

---

## B5 — Order list

Branch `feature/orders-list`

- [x] `GET /api/orders` membaca `vw_order_details`
- [x] Filter `?status=` (validasi terhadap enum)
- [x] Role `pelanggan` → `WHERE user_id = req.user.id`
- [x] **`SELECT` kolom eksplisit** — `snap_token` & `snap_redirect_url` tidak boleh terkirim
      ke pelanggan
- [x] Pagination `?page=&pageSize=` default 20, maks 100
- [x] `scripts/test-orders-list.js` — 34 asersi, termasuk pelanggan A tidak bisa melihat order B

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

- [ ] `PATCH /api/orders/:id/status` — validasi transisi yang sah
- [ ] `proses_cuci` → `siap_diambil`: bebaskan mesin (`tersedia`, `estimated_finish_at=NULL`)
- [ ] Ambil antrean terdepan `ORDER BY created_at ASC, id ASC LIMIT 1`
- [ ] Respons sertakan `next_queue_order` untuk modal 1-ketukan
- [ ] `PATCH /api/orders/:id/confirm-relay` — kunci mesin `FOR UPDATE`, set `digunakan` +
      `estimated_finish_at`, order → `proses_cuci`
- [ ] `siap_diambil` → `selesai` memicu poin (dikerjakan trigger, backend tidak menyentuh)
- [ ] `scripts/test-orders-status.js` (transaksi + `ROLLBACK`)

**Jebakan:** `trg_before_update_order` menjaga sebagian field. Transisi status yang tidak sah
harus ditolak backend — trigger tidak memvalidasi semuanya.

---

## B7 — Sync payment

Branch `feature/orders-sync-payment`

- [ ] `POST /api/orders/:id/sync-payment` — `checkRole(['kasir'])`
- [ ] Panggil Midtrans Core `transaction.status(order_code)`
- [ ] `settlement`/`capture` → `UPDATE payment_status='lunas', paid_at=now()`
- [ ] Mode stub (server key kosong) → `503` dengan pesan jelas, bukan sukses palsu
- [ ] `scripts/test-sync-payment.js`

---

## B8 — Dashboard

Branch `feature/dashboard-summary`

- [ ] `GET /api/dashboard/summary` — `checkRole(['kasir'])`
- [ ] Gabung `vw_dashboard_summary` + `vw_daily_revenue_7days`
- [ ] **Isi 7 tanggal** — view tidak memunculkan hari tanpa transaksi
- [ ] `scripts/test-dashboard.js`

---

## B9 — Rewards redeem

Branch `feature/rewards-redeem`

- [ ] `POST /api/rewards/redeem` — `checkRole(['pelanggan'])`, body `reward_id`
- [ ] `voucher_code` `CLN-VCR-` + 4 alfanumerik acak, ulang 3× bila `ER_DUP_ENTRY`
- [ ] **Jangan potong poin manual** — trigger memotong
- [ ] Tangkap `SQLSTATE 45000` dari trigger → `400` dengan `err.message`
- [ ] `GET /api/rewards/my-vouchers` — JOIN `rewards`, pisahkan aktif vs terpakai
- [ ] `scripts/test-rewards.js` (transaksi + `ROLLBACK`, poin dipulihkan)

---

## B10 — Pengerasan

Branch `feature/hardening` · sebelum deploy

- [ ] Rate limit `POST /api/auth/login` dan `/register`
- [ ] Helmet / header keamanan
- [ ] `certs/ca.pem` + `rejectUnauthorized: true`
- [ ] Batas ukuran body `express.json()`
- [ ] Log terstruktur (sekarang hanya `console.error`)
- [ ] `npm audit` bersih

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