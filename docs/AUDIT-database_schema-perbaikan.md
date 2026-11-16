# LAPORAN PERBAIKAN — `database_schema.sql` (Cleano)

* **Objek:** `database_schema.sql` — 6 tabel, 4 trigger, 3 view, seeder
* **Metode:** static code review. **Belum dieksekusi di Aiven** — tidak ada kredensial di workspace. Semua temuan = analisis kode, bukan reproduksi runtime.
* **Tanggal:** 2026-11-15
* **Total temuan:** 12 (1 CRITICAL, 4 HIGH, 2 MEDIUM, 2 LOW, 3 INFO)
* **Total patch wajib:** 4 (Fix 01–04), estimasi ~31 menit

Verdict: struktur skema sehat (FK, CHECK, index, contract locking sudah benar untuk lapisan DB). Yang bocor bukan sintaks — tapi **dua jalur kehilangan/duplikasi poin** dan **satu race condition voucher** yang hanya aman kalau backend benar-benar menepati `FOR UPDATE` di PRD-01 §5.3.

---

## Ringkasan Status

| Fix | Temuan | Severity | File yang disentuh | Status |
|---|---|---|---|---|
| 01 | C-01 Double-claim voucher | CRITICAL | `database_schema.sql` + `orderController.js` | BELUM |
| 02 | H-01 + H-02 Poin dobel / poin hilang | HIGH | `database_schema.sql` | BELUM |
| 03 | H-03 `sql_log_bin = 0` gagal di Aiven | HIGH | `database_schema.sql` | BELUM |
| 04 | H-04 Batas hari omzet salah 7 jam | HIGH | `config/database.js` + `.env` | BELUM |
| 05 | M-01 Order `batal` masuk omzet | MEDIUM | `database_schema.sql` | BELUM |
| 06 | M-02 Dua order satu mesin | MEDIUM | dokumentasi + test case | BELUM |
| 07 | L-01 Guard `NOT FOUND` di trigger | LOW | `database_schema.sql` | BELUM |
| 08 | L-02 Berat vs kapasitas mesin | LOW | `orderController.js` | BELUM |
| 09 | I-01 `snap_token` bocor lewat view | INFO | `orderController.js` | BELUM |
| 10 | I-02/I-03/I-04 Catatan kecil | INFO | `database_schema.sql` + seeder | BELUM |

---

## Fix 01 — Double-claim voucher  `CRITICAL`

**Masalah:** `trg_before_insert_order` memvalidasi `is_used = 0` tanpa row lock, sedangkan penandaan `is_used = 1` baru terjadi di `AFTER INSERT`. Dua transaksi konkuren membaca snapshot sama, keduanya lolos, diskon diberikan dua kali. Melanggar KPI PRD-01 §3 ("nol insiden double-claim").

**Bukti (kode asli):**
```sql
select uv.is_used, uv.user_id, r.discount_amount into v_vcr_used, v_vcr_owner, v_discount
from user_vouchers uv join rewards r on uv.reward_id = r.id
where uv.id = new.voucher_id;      -- tanpa FOR UPDATE, tanpa transaksi eksplisit
```

### Patch A — backstop di level DDL

Tambahkan setelah `create table orders (...)`. MySQL mengizinkan multiple `NULL` pada unique index, jadi order tanpa voucher tetap aman.

```sql
alter table orders
  add constraint uq_orders_voucher unique (voucher_id);
```

### Patch B — backend wajib lock

Di `orderController.js`, sebelum `INSERT INTO orders`, **di dalam** transaksi yang sama:

```js
const conn = await pool.getConnection();
try {
  await conn.beginTransaction();

  if (voucher_code) {
    const [[vcr]] = await conn.query(
      `select id, user_id, is_used from user_vouchers
       where voucher_code = ? for update`, [voucher_code]
    );
    if (!vcr) throw new AppError('Kode voucher tidak ditemukan.', 400);
    if (vcr.user_id !== userId) throw new AppError('Voucher bukan milik pelanggan ini.', 400);
    if (vcr.is_used === 1) throw new AppError('Voucher sudah pernah digunakan (1x pakai).', 400);
    voucherId = vcr.id;
  }

  // ... alokasi mesin juga FOR UPDATE, lalu INSERT ...
  await conn.commit();
} catch (e) {
  await conn.rollback();
  throw e;
} finally {
  conn.release();   // WAJIB — tanpa ini pool habis dalam beberapa menit
}
```

### Verifikasi

```sql
-- harus gagal dengan duplicate entry 1062
insert into orders (order_code, user_id, service_id, voucher_id, weight,
                    subtotal_price, discount_amount, total_price,
                    payment_method, image_url)
values ('CLN-TEST-1', 2, 1, 1, 2.00, 0, 0, 0, 'tunai', '/x.jpg');
insert into orders (order_code, user_id, service_id, voucher_id, weight,
                    subtotal_price, discount_amount, total_price,
                    payment_method, image_url)
values ('CLN-TEST-2', 2, 1, 1, 2.00, 0, 0, 0, 'tunai', '/x.jpg');
-- baris kedua: ERROR 1062 Duplicate entry '1' for key 'orders.uq_orders_voucher'
```

---

## Fix 02 — Poin dobel & poin hilang  `HIGH`

**Dua bug di satu trigger:**

1. **Poin dobel.** Kondisi `old.status != 'selesai'` tidak menandai bahwa order sudah pernah diberi poin. Alur `selesai → proses_cuci → selesai` memberi poin berulang, tak terbatas.
2. **Poin hilang.** Order `midtrans` yang di-set `selesai` saat masih `belum_bayar`, lalu `/sync-payment` mengubah `payment_status = 'lunas'` — saat update itu `old.status` sudah `'selesai'`, kondisi `false`, poin **tidak pernah** diberikan selamanya. Ini jalur pembayaran non-tunai utama, jadi kerugiannya sistematis.

**Bukti (kode asli):**
```sql
if old.status != 'selesai' and new.status = 'selesai' and new.payment_status = 'lunas' then
```

### Patch — urutan eksekusi WAJIB seperti ini

**(1) Tambah kolom flag:**
```sql
alter table orders
  add column points_awarded tinyint(1) not null default 0 after queue_wait_minutes;
```

**(2) Hapus trigger lama:**
```sql
drop trigger if exists trg_after_update_order_status;
```

**(3) Pasang trigger idempoten `BEFORE UPDATE`** (harus BEFORE, karena perlu menulis `NEW.points_awarded`):
```sql
delimiter $$

create trigger trg_before_update_order_status
before update on orders
for each row
begin
    declare v_service_name varchar(100);
    declare v_base_points int;
    declare v_multiplier int default 1;

    if new.status = 'selesai'
       and new.payment_status = 'lunas'
       and old.points_awarded = 0 then

        select name into v_service_name from services where id = new.service_id;
        set v_base_points = floor(new.total_price / 10000);

        if new.weight >= 5.00
           or lower(coalesce(v_service_name, '')) like '%express%' then
            set v_multiplier = 2;
        end if;

        if v_base_points > 0 then
            update users
               set points = points + (v_base_points * v_multiplier)
             where id = new.user_id;
        end if;

        set new.points_awarded = 1;
    end if;
end$$

delimiter ;
```

**Efek:** bayar-dulu-baru-selesai ✅, selesai-dulu-baru-bayar ✅, rollback→`selesai` lagi ✅ (flag sudah `1`), klik ganda ✅.

**Batasan yang harus dipatuhi backend:** `POST /api/orders` **tidak boleh** meng-`INSERT` order langsung dengan `status = 'selesai'`. Trigger di atas hanya menangkap transisi UPDATE. Backend wajib insert dengan `antre` / `proses_cuci` / `sedang_diproses`, lalu ubah ke `selesai` lewat `PATCH`. *(ponytail: kalau nanti butuh insert-langsung-selesai, tambah trigger BEFORE INSERT dengan logika sama — belum perlu sekarang.)*

### Patch seeder

Baris seeder yang di-insert langsung `selesai` harus ditandai sudah diberi poin, agar tidak tiba-tiba dapat poin retroaktif saat ada UPDATE lain:

```sql
insert into orders (..., points_awarded, ...) values
  ('CLN-20261113-0001', ..., 1, ...),
  ('CLN-20261114-0001', ..., 1, ...),
  ('CLN-20261115-0001', ..., 0, ...);   -- masih siap_diambil, belum selesai
```

### Verifikasi

```sql
-- siapkan order uji: id 2 punya 150 poin
select id, points from users where id = 2;              -- 150

update orders set status = 'selesai' where id = 3;      -- total 21000, 3kg, non-express
select points from users where id = 2;                  -- 152 (+2)
select points_awarded from orders where id = 3;         -- 1

update orders set status = 'proses_cuci' where id = 3;
update orders set status = 'selesai'      where id = 3;
select points from users where id = 2;                  -- TETAP 152, tidak dobel

-- uji poin hilang (H-02): order midtrans belum_bayar -> selesai -> lunas
update orders set status = 'selesai' where id = 3 and payment_status = 'belum_bayar';
update orders set payment_status = 'lunas' where id = 3;
select points from users where id = 2;                  -- bertambah sekali, bukan nol
```

---

## Fix 03 — `sql_log_bin = 0` gagal di Aiven  `HIGH`

**Masalah:** baris 14 script mematikan binary logging level sesi. Butuh `SUPER` atau `SYSTEM_VARIABLES_ADMIN`; akun `avnadmin` Aiven umumnya tidak memegang `SUPER`. Script mati sebelum satu tabel pun terbuat. Baris ini **tidak diperlukan** — PRD-05 §4.2 sudah menyuruh `log_bin_trust_function_creators = ON`, itu cara resmi Aiven.

### Patch

Hapus baris:
```sql
set session sql_log_bin = 0;   -- HAPUS
```

### Verifikasi sebelum eksekusi script

```sql
select @@log_bin, @@log_bin_trust_function_creators, current_user(), version();
```
`@@log_bin_trust_function_creators` harus `1`. Kalau `0`, aktifkan lewat Aiven Console → *Advanced Parameters* (perlu restart service).

---

## Fix 04 — Batas hari omzet salah 7 jam  `HIGH`

**Masalah:** `date(created_at) = curdate()` dievaluasi memakai timezone sesi. Kolom `TIMESTAMP` disimpan UTC; Aiven default `time_zone = SYSTEM` (UTC). Toko beroperasi WIB (UTC+7), sehingga "Omzet Hari Ini" baru reset pukul **07:00 pagi**, dan transaksi 00:00–07:00 masuk ke hari sebelumnya. Omzet harian salah setiap pagi — kelas bug yang merusak kepercayaan pada seluruh laporan.

**Bukti:** `vw_dashboard_summary` (`date(created_at) = curdate()`) dan `vw_daily_revenue_7days` (`created_at >= date_sub(curdate(), interval 6 day)`).

### Patch — pilih SATU, jangan campur

**Opsi A (disarankan) — set timezone per koneksi pool:**

`.env`
```
DB_TIMEZONE=+07:00
```

`src/config/database.js`
```js
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: { rejectUnauthorized: false },
  timezone: process.env.DB_TIMEZONE || '+07:00',
  connectionLimit: 10,
  dateStrings: false,
});
```

**Opsi B — murni SQL di view** (kalau timezone koneksi tidak bisa diatur):
```sql
date(convert_tz(created_at, '+00:00', '+07:00')) = date(convert_tz(now(), '+00:00', '+07:00'))
```
Butuh `mysql.time_zone_name` terisi. Di Aiven biasanya tersedia; verifikasi dulu.

### Verifikasi

```sql
select @@global.time_zone, @@session.time_zone, now(), curdate();
-- sesi harus +07:00 dan curdate() harus tanggal WIB
```

---

## Fix 05 — Order `batal` masuk hitungan omzet  `MEDIUM`

**Masalah:** filter omzet hanya `payment_status = 'lunas'`. Order yang dibatalkan **setelah** dibayar (`status = 'batal'`, `payment_status = 'lunas'`) tetap dihitung sebagai pendapatan.

### Patch

`vw_dashboard_summary` — ganti `today_revenue`:
```sql
coalesce((
  select sum(total_price) from orders
  where payment_status = 'lunas'
    and status != 'batal'
    and date(created_at) = curdate()
), 0) as today_revenue,
```

`vw_daily_revenue_7days` — ganti klausa WHERE:
```sql
where payment_status = 'lunas'
  and status != 'batal'
  and created_at >= date_sub(curdate(), interval 6 day)
```

### Verifikasi

```sql
update orders set status = 'batal' where id = 1;   -- id 1 lunas 28000
select today_revenue from vw_dashboard_summary;    -- harus turun 28000
```

---

## Fix 06 — Dua order bisa menempati mesin yang sama  `MEDIUM`

**Masalah:** tidak ada constraint yang mencegah dua baris `orders` aktif memakai `machine_id` identik. Lapisan DB sepenuhnya bergantung pada `SELECT ... FOR UPDATE` di backend. Kalau `confirm-relay` dipanggil dua kali paralel dan backend lupa mengunci, dua order berbagi satu drum — timer jadi fiktif, pelanggan melihat "Sedang Dicuci di MC-01" bersamaan.

MySQL **tidak punya partial unique index**, jadi tidak bisa `unique(machine_id) where status in (...)`.

**Keputusan: terima dan dokumentasikan.** PRD-01 §5.3 sudah mewajibkan lock. Cukup tambahkan test case khusus TC-09b.

### Patch test case (tambahkan ke PRD-05 §3)

| Kode | Skenario | Langkah | Hasil |
|---|---|---|---|
| **TC-09b** | Klik ganda `confirm-relay` | Kirim `PATCH /api/orders/:id/confirm-relay` dengan `machine_id` sama, 2 request paralel | Hanya 1 sukses; request kedua `400` ("Mesin tidak tersedia"); hanya 1 order aktif per mesin |

*(ponytail: kalau nanti muncul bug nyata, tambah trigger BEFORE INSERT/UPDATE yang `SIGNAL` bila ada order aktif lain dengan `machine_id` sama — 20 menit.)*

---

## Fix 07 — Guard `NOT FOUND` hilang di trigger  `LOW`

**Masalah:** `SELECT ... INTO` tanpa baris tidak melempar error; variabel tetap `NULL`. Perbandingan `NULL != x` dan `NULL = 1` keduanya `NULL` → semua validasi terlewati. INSERT akhirnya gagal di constraint dengan pesan `1048 Column cannot be null` atau `1452 FK`, bukan pesan bisnis. Risiko rendah karena FK sudah menutup jalur ini; nilainya kualitas pesan error.

### Patch `trg_before_insert_order`

Sisipkan setelah blok `select uv.is_used, uv.user_id, r.discount_amount into ...`:
```sql
if v_vcr_owner is null then
    signal sqlstate '45000' set message_text = 'Kode voucher tidak ditemukan.';
end if;
```

### Patch `trg_before_insert_user_voucher`

Sisipkan setelah kedua `select into`:
```sql
if v_user_points is null then
    signal sqlstate '45000' set message_text = 'Pelanggan tidak ditemukan.';
end if;

if v_req_points is null then
    signal sqlstate '45000' set message_text = 'Reward tidak ditemukan.';
end if;
```

Tambahkan juga `default 0` agar perbandingan tidak pernah menyentuh `NULL`:
```sql
declare v_user_points int default 0;
declare v_req_points  int default 0;
```

---

## Fix 08 — Berat tidak divalidasi terhadap kapasitas mesin  `LOW`

**Masalah:** `machines.capacity_kg` (7.00–10.00) tidak pernah dibandingkan dengan `orders.weight` (maks 99.99). Order 20 kg bisa dialokasikan ke mesin 7 kg. Ini masalah operasional (pakaian tidak tercuci bersih), bukan keamanan. PRD tidak mewajibkan — keputusan produk.

### Patch (opsional) di `orderController.js`

Saat memilih mesin:
```sql
select id, capacity_kg from machines
 where status = 'tersedia' and capacity_kg >= ?
 order by id asc limit 1 for update
```
Kalau berat melebihi **semua** kapasitas mesin tersedia, kembali `400` dengan pesan "Berat melebihi kapasitas mesin yang tersedia."

---

## Fix 09 — `snap_token` bocor lewat view  `INFO`

**Masalah:** `vw_order_details` mengirim `snap_token` dan `snap_redirect_url`. View ini dipakai `GET /api/orders` yang juga diakses role `pelanggan`. `snap_token` adalah kredensial sesi pembayaran Midtrans.

**Dampak:** terbatas — pelanggan hanya bisa membuka sesi pembayaran order miliknya sendiri. Tapi melanggar semangat PRD-04 (portal pelanggan read-only, pembayaran terpusat di kasir) dan permukaan serangan yang tidak perlu.

### Patch — controller wajib kolom eksplisit

```js
// orderController.js — JANGAN pakai SELECT *
const CUSTOMER_COLS = `id, order_code, service_name, weight, subtotal_price,
  discount_amount, total_price, payment_method, payment_status, status,
  queue_wait_minutes, machine_code, machine_finish_at, image_url, notes,
  voucher_code, created_at`;

const CASHIER_COLS = `${CUSTOMER_COLS}, user_id, customer_name, customer_phone,
  member_code, customer_tier, service_id, machine_id, snap_redirect_url`;
```

`snap_token` jangan dikirim ke siapa pun lewat `GET` — hanya dipakai internal untuk membuat `snap_redirect_url`.

*(ponytail: kalau butuh isolasi lebih keras, buat `vw_order_details_customer` terpisah — belum perlu selama controller disiplin.)*

---

## Fix 10 — Catatan kecil  `INFO`

### I-02 — tidak ada `updated_at` di `orders`
Tidak bisa diaudit kapan order diselesaikan, padahal trigger poin bergantung pada waktu.
```sql
alter table orders
  add column updated_at timestamp not null
  default current_timestamp on update current_timestamp;
```

### I-03 — hash seeder belum diverifikasi
Hash `$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi` harus benar-benar cocok dengan `password123`. **Kalau tidak, TC-03 (Login & Routing Per Role) gagal di menit pertama demo.**
```bash
node -e "const b=require('bcrypt');console.log(b.compareSync('password123','$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'))"
# harus: true
```
Kalau `false`, regenerate:
```bash
node -e "console.log(require('bcrypt').hashSync('password123',10))"
```

### I-04 — akun kasir ber-`member_code` `STF-0001`
Format di luar `MBR-XXXX`. Tidak melanggar constraint (`unique` saja), tapi `GET /api/users/lookup?query=...` mencari `member_code = ? OR phone = ?` — kalau kasir mengetik `STF-0001` atau nomor kasir, akun kasir sendiri ikut terembalikan ke form POS.
```sql
-- di userController.lookup
where (member_code = ? or phone = ?) and role = 'pelanggan'
```

### I-05 — file sampel hilang
`/uploads/sample1.jpg` s/d `sample3.jpg` tidak ada → gambar rusak di UI demo lewat `image_url`. Sediakan 3 file placeholder di `cleano-backend/uploads/` atau ganti seed ke URL eksternal sementara.

---

## Urutan Eksekusi yang Disarankan

```
1. Fix 03  (hapus sql_log_bin)              → script bisa jalan sama sekali
2. Fix 02  (alter + trigger poin)           → CRITICAL jalur poin
3. Fix 01  (unique voucher_id)              → backstop double-claim
4. Fix 05  (view omzet)                     → laporan benar
5. Fix 07  (guard NOT FOUND)                → pesan error layak
6. Fix 10  (updated_at, verifikasi hash)    → sebelum demo
7. Fix 04  (timezone backend)               → saat scaffolding backend
8. Fix 01B (FOR UPDATE di controller)       → saat tulis orderController
9. Fix 09  (kolom eksplisit)                → saat tulis orderController
10. Fix 06, 08 (test case + kapasitas)      → setelah API jalan
```

Patch 1–6 murni SQL, bisa langsung diterapkan ke `database_schema.sql` dan dieksekusi ulang dari nol (script sudah `DROP ... IF EXISTS`).

---

## Yang Belum Terverifikasi

Seluruh temuan di atas berasal dari pembacaan kode, **bukan reproduksi**. Tidak ada satu pun yang saya klaim terbukti runtime.

| Temuan | Butuh apa |
|---|---|
| H-03 privilege `sql_log_bin` | `select @@log_bin, @@log_bin_trust_function_creators` di Aiven |
| H-04 timezone aktual | `select @@global.time_zone, @@session.time_zone` di Aiven |
| C-01 race condition | 2 sesi MySQL paralel, `BEGIN` + insert bersamaan |
| I-03 hash seeder | runtime `bcrypt.compareSync` |
| Penegakan `CHECK` MySQL 8.0 | `select version()` — MariaDB mengabaikan `CHECK` |
| Semua temuan | eksekusi bersih `database_schema.sql` di Aiven |

---

## Checklist Perbaikan

```
[ ] Fix 03  hapus `set session sql_log_bin = 0`
[ ] Fix 02  add column points_awarded
[ ] Fix 02  drop trg_after_update_order_status
[ ] Fix 02  create trg_before_update_order_status
[ ] Fix 02  seeder orders isi points_awarded eksplisit
[ ] Fix 01  add constraint uq_orders_voucher unique (voucher_id)
[ ] Fix 05  view omzet exclude status = 'batal'
[ ] Fix 07  guard NOT FOUND di trigger 1 & 2
[ ] Fix 10  add column updated_at
[ ] Fix 10  verifikasi hash seeder dengan bcrypt.compareSync
[ ] Fix 10  lookup tambah role = 'pelanggan'
[ ] Fix 10  sediakan 3 file placeholder /uploads
[ ] Fix 04  set timezone +07:00 di connection pool
[ ] Fix 01B FOR UPDATE user_vouchers di orderController
[ ] Fix 06  tambah TC-09b klik ganda confirm-relay
[ ] Fix 08  validasi weight <= capacity_kg
[ ] Fix 09  kolom eksplisit di GET /api/orders
[ ] Re-run database_schema.sql di Aiven dari nol, verifikasi 6 tabel + 3 view + 4 trigger
[ ] Jalankan TC-01 s/d TC-13
```
