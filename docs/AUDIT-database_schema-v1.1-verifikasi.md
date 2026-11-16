# VERIFIKASI `database_schema.sql` v1.1 (Cleano)

* **Objek:** `database_schema.sql` patched v1.1
* **Metode:** static review + 1 verifikasi runtime (bcrypt hash seeder)
* **Tanggal:** 2026-11-15
* **Status:** 9 dari 10 fix v1.0 **BENAR**. 2 temuan baru (1 HIGH, 1 MEDIUM), 4 catatan rendah.

---

## Bagian 1 — Verifikasi Fix v1.0

| Fix | Klaim | Status | Bukti |
|---|---|---|---|
| 03 | `set session sql_log_bin = 0` dihapus | ✅ BENAR | baris 12–14 langsung `set foreign_key_checks = 0` |
| 02 | `points_awarded` + trigger idempoten | ✅ BENAR | kolom ada di DDL order setelah `queue_wait_minutes`; `trg_before_update_order_status` BEFORE UPDATE dengan `old.points_awarded = 0` |
| 02b | Trigger lama dibuang | ✅ BENAR | `drop trigger if exists trg_after_update_order_status` ada |
| 01 | `unique (voucher_id)` | ✅ BENAR | `constraint uq_orders_voucher unique (voucher_id)` |
| 05 | `batal` dikecualikan dari omzet | ✅ BENAR | `and status != 'batal'` di kedua view |
| 07 | Guard `NOT FOUND` | ✅ BENAR | guard di trigger 1 (`v_user_points`, `v_req_points`) + trigger 2 (`v_price_per_kg`, `v_vcr_owner`) |
| 10 | `updated_at` | ✅ BENAR | `updated_at timestamp not null default current_timestamp on update current_timestamp` |
| 10 | Seeder `points_awarded` eksplisit | ✅ BENAR | row 1 & 2 = `1`, row 3 = `0` (konsisten dengan status) |
| 04 | Timezone `+07:00` | ⏳ BELUM | nunggu `config/database.js` (di luar file SQL) |
| 01B | `FOR UPDATE` voucher di controller | ⏳ BELUM | nunggu `orderController.js` |

**Jumlah nilai seeder per baris:** 16 kolom / 16 nilai, cocok. Tidak ada syntax error yang saya temukan.

**Catatan:** `delimiter$$` ... `delimiter ;` sudah benar (4 trigger dalam satu blok).

---

## Bagian 2 — Temuan Baru

### R-01 — Hash seeder = `password`, bukan `password123`  `HIGH | SOLID (runtime)`

**Masalah:** komentar v1.1 sudah jujur (`bcrypt untuk kata sandi 'password'`), tapi PRD-02 §4.1, PRD-05 §4.2, dan dokumen audit menyebut `password123` untuk **semua** akun. Login dengan `password123` akan **ditolak**.

**Bukti runtime (dieksekusi):**
```
lib sanity ("password"): true
$2a$10$ -> MATCH: ["password"]
$2b$10$ -> MATCH: ["password"]
$2y$10$ -> MATCH: ["password"]
password123 -> false
```
Hash `$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi` adalah hash Laravel/PHP default untuk string `password`.

**Dampak:** TC-03 (Login & Routing Per Role) gagal di percobaan pertama. Ini blocker demo Hari 7.

**Fix — pilih satu:**

**Opsi A (paling malas, 0 perubahan SQL):** update dokumentasi. Ganti `password123` → `password` di PRD-02 §4.1 dan PRD-05 §4.2.

**Opsi B (seragamkan ke PRD):** ganti 3 hash seeder dengan hash `password123` yang sudah diverifikasi:
```sql
-- $2b$10$dJtvMjnmVcXCSOIKdco5feBtozeOiKSn1VvdkRk9b.ToTI6hhHnaW
-- verified: compareSync('password123', hash) === true
--           compareSync('password',    hash) === false
```
Atau generate sendiri saat seeder jalan (lebih baik, tidak ada hash hardcoded):
```js
const hash = await bcrypt.hash('password123', 10);
```

**Effort:** 2 menit (Opsi A) / 5 menit (Opsi B).

---

### R-02 — Omzet diatribusikan per `created_at`, bukan tanggal bayar  `MEDIUM | SOLID`

**Masalah:** `today_revenue` dan `vw_daily_revenue_7days` mengelompokkan uang berdasarkan **kapan order dibuat**, bukan kapan uang masuk. Tidak ada kolom `paid_at`.

**Bukti:**
```sql
-- vw_dashboard_summary
where payment_status = 'lunas'
  and status != 'batal'
  and date(created_at) = curdate()
```

**Dampak konkret:** order `midtrans` dibuat 23:50, `/sync-payment` sukses 00:10 keesokan hari. Uang masuk hari ini, tapi tercatat sebagai omzet kemarin. Karena PRD-02 §5 sengaja memakai polling `sync-payment` (tanpa webhook), jeda ini **normal**, bukan edge case. Omzet harian jadi bergeser setiap ada pembayaran non-tunai lewat tengah malam.

**Fix:**
```sql
alter table orders add column paid_at datetime null after payment_status;
```
Isi saat lunas:
```sql
update orders set paid_at = now() where id = ? and payment_status = 'belum_bayar';
```
Lalu view pakai `paid_at`:
```sql
where payment_status = 'lunas'
  and status != 'batal'
  and date(paid_at) = curdate()
```
Backfill data lama: `update orders set paid_at = created_at where payment_status = 'lunas' and paid_at is null;`

**Effort:** 15 menit (kolom + 3 view + 1 baris di `sync-payment`).

*(ponytail: kalau tidak mau tambah kolom, terima selisihnya dan dokumentasikan — tapi ini laporan keuangan, jadi lebih baik benar.)*

---

## Bagian 3 — Catatan Rendah

### R-03 — Grafik 7 hari bisa bolong  `LOW | SOLID`
`vw_daily_revenue_7days` hanya mengembalikan tanggal yang **ada** transaksi. Hari tanpa order = tidak ada baris. `fl_chart` akan menampilkan grafik dengan hari hilang, bukan batang nol.
**Fix (backend, bukan SQL):** petakan 7 tanggal di JS, isi `0` untuk tanggal yang tidak ada di hasil query.

### R-04 — Duplikat voucher menghasilkan error 1062, bukan pesan bisnis  `LOW | SOLID`
`uq_orders_voucher` menutup double-claim ✅, tapi penyerang/klik-ganda menerima `ER_DUP_ENTRY (1062)`, bukan `400 Voucher sudah dipakai`.
**Fix:** di `orderController.js`, tangkap `err.code === 'ER_DUP_ENTRY'` → `400` dengan pesan ramah.

### R-05 — `DELIMITER` tidak jalan di Aiven Console / GUI tertentu  `LOW | PLAUSIBLE`
`DELIMITER` adalah perintah *client* MySQL, bukan server. Query editor Aiven, DBeaver mode tertentu, dan phpMyAdmin bisa gagal di blok trigger.
**Fix:** eksekusi via `mysql` CLI (`mysql -h ... -u avnadmin -p < database_schema.sql`) atau Workbench. Bukan masalah SQL-nya.

### R-06 — `ORDER BY` di dalam view tidak dijamin  `INFO`
`vw_daily_revenue_7days` punya `order by order_date asc` di dalam definisi view. MySQL mengizinkan, tapi optimizer boleh mengabaikannya. Backend wajib `ORDER BY` sendiri.

### R-07 — Race redeem poin ditahan `CHECK`, bukan pesan bisnis  `INFO`
Dua redeem paralel: keduanya lolos cek saldo di trigger, lalu `update users set points = points - ?` kedua melanggar `chk_users_points (points >= 0)` → error `3819`.
Uang/poin **aman** (tidak bisa minus), tapi pesannya jelek.
**Fix:** `SELECT ... FOR UPDATE` pada baris `users` sebelum insert voucher di `POST /api/rewards/redeem` (PRD-01 §5.3 sebenarnya sudah mewajibkan ini).

---

## Bagian 4 — Masih Terbuka (bukan salah SQL)

| Item | Kenapa belum tertutup |
|---|---|
| Fix 04 timezone `+07:00` | ada di `src/config/database.js`, bukan file SQL |
| Fix 01B `FOR UPDATE` voucher | ada di `orderController.js` |
| Fix 08 `weight <= capacity_kg` | keputusan produk + validasi backend |
| Fix 09 `snap_token` di view | `vw_order_details` **masih** memuat `snap_token` & `snap_redirect_url` — aman hanya jika controller `SELECT` kolom eksplisit |
| M-02 dua order satu mesin | menerima risiko; TC-09b belum ditambahkan ke PRD-05 |
| File `/uploads/sample1..3.jpg` | belum ada, gambar demo rusak |

---

## Checklist

```
[x] Fix 03  sql_log_bin dihapus
[x] Fix 02  points_awarded + trg_before_update_order_status
[x] Fix 02b trg_after_update_order_status dibuang
[x] Fix 01  unique (voucher_id)
[x] Fix 05  omzet exclude batal
[x] Fix 07  guard NOT FOUND (trigger 1 & 2)
[x] Fix 10  updated_at
[x] Fix 10  seeder points_awarded eksplisit
[ ] R-01     hash seeder = 'password', PRD minta 'password123'  -> BLOCKER TC-03
[ ] R-02     tambah paid_at, ubah 2 view
[ ] R-03     map 7 hari kosong di backend
[ ] R-04     map ER_DUP_ENTRY -> 400
[ ] R-06     ORDER BY di query backend, jangan andalkan view
[ ] R-07     FOR UPDATE di redeem
[ ] Fix 04   timezone +07:00 di pool
[ ] Fix 01B  FOR UPDATE voucher di orderController
[ ] Fix 08   weight <= capacity_kg
[ ] Fix 09   kolom eksplisit di GET /api/orders
[ ] Fix 06   TC-09b confirm-relay ganda
[ ] Re-run schema dari nol di Aiven
[ ] TC-01 s/d TC-13
```
