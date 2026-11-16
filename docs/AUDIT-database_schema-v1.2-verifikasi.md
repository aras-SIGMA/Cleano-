# VERIFIKASI `database_schema.sql` v1.2 (Cleano) — RUNTIME

* **Objek:** `database_schema.sql` final v1.2
* **Metode:** **eksekusi nyata** di MySQL 8.4.3 (Laragon, datadir terpisah, port 3399). Bukan lagi static review.
* **Tanggal:** 2026-11-15
* **Hasil:** schema load bersih (exit 0). **6 tabel, 3 view, 4 trigger** terbentuk. 9/9 fix v1.0 & v1.1 **LULUS**. 4 temuan baru (2 HIGH), semuanya **terbukti via query**, bukan dugaan.

---

## Bagian 1 — Hasil Load

```
schema load exit code: 0
tables    6
views     3
triggers  4     trg_after_insert_order        AFTER  INSERT
                trg_before_insert_order       BEFORE INSERT
                trg_before_insert_user_voucher BEFORE INSERT
                trg_before_update_order_status BEFORE UPDATE
```

Satu-satunya warning: `Code 1681 Integer display width is deprecated` (5×, dari `tinyint(1)`). Kosmetik, tidak berpengaruh di MySQL 8.4.

Seed state benar: `orders.total_price` terisi otomatis (28000 / 66000 / 21000), `paid_at` terisi, Rina 200→150 (voucher 50 poin dipotong trigger 1).

---

## Bagian 2 — Regression: seluruh temuan lama

### R-01 hash seeder — ✅ FIXED & VERIFIED

```
v1.1 seeder $2b$10$92IX... :  password=true   password123=false
v1.2 seeder $2b$10$dJtv... :  password=false  password123=true
```
TC-03 sekarang akan lulus.

### Tabel regression lengkap

| Uji | Harapan | Hasil runtime | Verdict |
|---|---|---|---|
| Load schema dari nol | 6/3/4 objek, exit 0 | exit 0, 6/3/4 | ✅ |
| Poin dasar `selesai` | +2 (21000 → floor 21000/10000=2) | 150 → 152 | ✅ |
| Rollback → `selesai` lagi | tidak dobel | tetap 152, flag=1 | ✅ |
| Klik ganda `selesai` | tidak dobel | tetap 152 | ✅ |
| Midtrans: `selesai` saat `belum_bayar` | tidak ada poin | 45 → 45 | ✅ |
| Midtrans: lalu `lunas` | poin masuk + `paid_at` distempel | 45 → 47, `paid_at=2026-11-15 18:24:56`, flag=1 | ✅ |
| Bonus 2× (express / ≥5kg) | ×2 | order 5.50kg express → +12 (base 6) | ✅ |
| Voucher dipakai 2× | ditolak | `ERROR 1644 (45000) Voucher sudah pernah digunakan` | ✅ |
| Voucher + unique constraint | ditolak | `ERROR 1062 Duplicate entry '1' for key 'orders.uq_orders_voucher'` | ✅ |
| Voucher milik pelanggan lain | ditolak | `ERROR 1644 Voucher tidak valid untuk akun pelanggan ini` | ✅ |
| Reward non-aktif saat redeem | ditolak | `ERROR 1644 Promo reward sudah tidak aktif` | ✅ |
| Poin tidak cukup saat redeem | ditolak | `ERROR 1644 Poin pelanggan tidak mencukupi` | ✅ |
| `CHECK points >= 0` | ditolak | `ERROR 3819 Check constraint 'chk_users_points' is violated` | ✅ |
| `weight = 0` / `-1` | ditolak | `ERROR 3819 chk_orders_weight` (dua-duanya) | ✅ |
| `INSERT` dengan harga palsu | ditimpa trigger | 999999/88888/77777 → 14000/0/14000 | ✅ |
| `INSERT ... SELECT` | trigger tetap jalan | 14000/14000 | ✅ |
| Order `batal` keluar dari omzet | tidak dihitung | 28000 hilang dari `vw_daily_revenue_7days` | ✅ |
| Atomicity trigger + `CHECK` gagal | poin ikut rollback | 153 tetap 153 setelah `ERROR 3819` | ✅ |

**Atomicity (uji L):** `UPDATE ... SET status='selesai', total_price=-1` gagal di `chk_orders_total`, dan update `users.points` di dalam trigger **ikut dibatalkan**. Tidak ada poin hantu. Ini penting — kalau MySQL tidak rollback, akan ada kebocoran poin permanen.

---

## Bagian 3 — Uji Konkurensi (2 sesi paralel, dijalankan sungguhan)

### K-1 Voucher, TANPA `FOR UPDATE`

| Sesi | Aksi | Jam |
|---|---|---|
| A | `begin`, insert order pakai voucher #2 | 18:25:48.651 |
| A | inserted (uncommitted), `sleep(6)` | 18:25:48.655 |
| B | `begin`, insert order pakai voucher #2 yang sama | 18:25:49.673 |
| A | `commit` | 18:25:54.681 |
| B | **`ERROR 1062 Duplicate entry '2' for key 'orders.uq_orders_voucher'`** | — |

**Hasil:** B terblokir sampai A commit, lalu ditolak `uq_orders_voucher`. Hanya 1 order memakai voucher, **diskon tidak dobel**.
**Catatan jujur:** yang menyelamatkan di sini adalah `uq_orders_voucher`, bukan trigger. `trg_before_insert_order` tetap membaca `is_used` tanpa lock dan **tetap lolos dua kali** — backstop unique index yang menahan. Tanpa constraint itu, ini bug kritis. Sudah benar dari v1.1.

### K-2 Alokasi mesin, TANPA `FOR UPDATE`

| Sesi | Aksi | Jam | Mesin |
|---|---|---|---|
| A | pilih `status='tersedia'` → 1 | 18:25:55.517 | MC-01 |
| B | pilih `status='tersedia'` → 1 (**sama**) | 18:25:56.608 | MC-01 |
| B | update + insert, `commit` | 18:26:01.571 | sukses |
| A | **`ERROR 1213 Deadlock found when trying to get lock`** | — | rollback |

**Hasil:** dua-duanya memilih **MC-01**. Tidak terjadi double-allocation, tapi bukan karena logika — karena InnoDB mendeteksi deadlock dan membunuh satu transaksi.

**Ini bukan bukti aman.** Deadlock detection bersifat timing-dependent. Dengan interleaving lain (B memilih *setelah* A update tapi *sebelum* A commit, tanpa lock overlap), dua order bisa menempati satu drum. Yang pasti: jalur naive **melempar `1213` ke kasir**, pesan yang tidak bisa ditampilkan ke pengguna.

### K-3 Alokasi mesin, DENGAN `FOR UPDATE` — ✅ benar

| Sesi | Aksi | Jam | Mesin |
|---|---|---|---|
| A | `select ... for update` → 1 | 18:26:02.247 | MC-01 |
| B | minta lock | 18:26:03.325 | **menunggu** |
| A | `commit` | 18:26:08.290 | MC-01 |
| B | **lock didapat**, query ulang → **2** | 18:26:08.290 | **MC-02** ✅ |

**Hasil:** B menunggu 4,96 detik, lalu otomatis dapat mesin **berbeda**. Tidak ada deadlock, tidak ada tabrakan. Kontrak PRD-01 §5.3 terbukti bekerja.

**Kesimpulan konklusi:** `FOR UPDATE` bukan saran — itu satu-satunya jalur yang bersih. Backend wajib memakainya, dan wajib menangani `ER_LOCK_DEADLOCK (1213)` sebagai retry kalau ada jalur yang terlewat.

---

## Bagian 4 — Temuan Baru (runtime-proven)

### N-01 — `total_price` & `discount_amount` bisa diubah langsung setelah insert, dan poin mengikuti nilai palsu  `HIGH`

**Masalah:** `trg_before_insert_order` menghitung ulang harga **hanya saat INSERT**. Tidak ada trigger `BEFORE UPDATE` untuk kolom uang. Setelah order tersimpan, `UPDATE orders SET total_price = ...` lolos tanpa validasi apa pun.

**Bukti (dieksekusi):**
```sql
-- M1: hanya harga yang diubah
update orders set total_price = 999999 where id = 3;
-- hasil: id 3, subtotal 21000, total_price 999999, points_awarded 0  -> LOLOS

-- M2: diskon melebihi subtotal
update orders set discount_amount = 500000 where id = 4;
-- hasil: subtotal 28000, discount 500000, total_price 28000  -> LOLOS
```

**Eskalasi ke poin (M3 + M4):**
```sql
update orders set total_price = 500000 where id = 3;   -- belum selesai, flag=0
update orders set status = 'proses_cuci' where id = 3;
update orders set status = 'selesai'       where id = 3;
-- points: 103 -> 153   (+50, dihitung dari 500000/10000)
-- seharusnya +2 (21000/10000)
```

**Dampak:** siapa pun yang bisa `UPDATE orders` (role `kasir`) menaikkan poin pelanggan tanpa batas, atau menurunkan tagihan tanpa jejak. `floor(total_price/10000)` membaca nilai yang tidak pernah diverifikasi. Juga memutus integritas laporan: omzet = `total_price`.

**Fix — tambah trigger penjaga UPDATE.** Paling malas yang tetap aman:

```sql
delimiter $$
create trigger trg_before_update_order_money
before update on orders
for each row
begin
    if new.subtotal_price != old.subtotal_price
       or new.discount_amount != old.discount_amount
       or new.total_price != old.total_price
       or new.weight != old.weight
       or new.service_id != old.service_id
       or new.voucher_id <=> old.voucher_id = 0 then
        signal sqlstate '45000'
            set message_text = 'Harga, berat, dan voucher order tidak boleh diubah setelah dibuat.';
    end if;
end$$
delimiter ;
```

Kalau koreksi harga memang dibutuhkan operasional, jangan cabut guard — buat jalur eksplisit: `status = 'batal'` lalu buat order baru (audit trail bersih, poin tidak bisa diakali).

**Effort:** 10 menit.

---

### N-02 — `paid_at` bisa diubah bebas, omzet bisa digeser keluar jendela laporan  `HIGH`

**Masalah:** `paid_at` hanya distempel otomatis kalau `NULL`. Nilai eksplisit diterima apa adanya, kapan saja, tanpa syarat.

**Bukti (dieksekusi):**
```sql
update orders set paid_at = '2000-01-01 00:00:00' where id = 2;
-- hasil: paid_at = 2000-01-01 00:00:00, created_at tetap 2026-11-14  -> LOLOS
```
Sesudah itu order 66000 lenyap dari `vw_dashboard_summary.today_revenue` **dan** dari `vw_daily_revenue_7days` — omzet hilang dari laporan tanpa error apa pun.

**Dampak:** laporan keuangan bisa dipangkas/digeser tanpa jejak. Ini kelas manipulasi pembukuan, bukan sekadar bug tampilan.

**Fix — kunci `paid_at` sekali ditulis:**
```sql
delimiter $$
create trigger trg_before_update_paid_at
before update on orders
for each row
begin
    if old.paid_at is not null and new.paid_at != old.paid_at then
        signal sqlstate '45000'
            set message_text = 'Waktu pelunasan tidak boleh diubah.';
    end if;
end$$
delimiter ;
```
Bisa digabung ke N-01 dalam satu trigger `BEFORE UPDATE`.

**Effort:** 5 menit (gabung dengan N-01).

---

### N-03 — `customer_tier` di view dihitung dari saldo poin **sekarang**, bukan saat transaksi  `MEDIUM`

**Masalah:** `vw_order_details` menghitung `case when u.points >= 300 then 'Platinum' ...`. Karena join ke `users` live, tier di **order lama ikut berubah** setiap kali poin pelanggan naik.

**Bukti (dieksekusi, M7):**
```
sebelum: order id 2 (2026-11-14) customer_tier = Silver
setelah Budi naik ke Gold:
order id 2 -> Silver   (order lama)
order id 8 -> Gold     (order baru)
```
Satu pelanggan, dua tier di satu laporan. Riwayat jadi tidak konsisten — order lama menampilkan tier yang salah untuk konteks saat itu.

**Dampak:** rendah secara keamanan, tinggi secara kredibilitas laporan. Kalau laporan "omzet per tier" dibuat, angkanya bergeser setiap hari tanpa ada transaksi baru.

**Fix:** kalau tier dipakai untuk laporan historis, simpan snapshot saat order dibuat:
```sql
alter table orders add column customer_tier_snapshot varchar(10) null;
```
Isi di `trg_before_insert_order`:
```sql
select case when points >= 300 then 'Platinum'
            when points >= 100 then 'Gold' else 'Silver' end
  into @tier from users where id = new.user_id;
set new.customer_tier_snapshot = @tier;
```
Lalu view pakai kolom itu. Kalau tier hanya untuk badge UI "sekarang", biarkan — tapi jangan pakai view ini untuk laporan.

**Effort:** 20 menit.

---

### N-04 — Jalur alokasi mesin tanpa `FOR UPDATE` melempar `1213` ke kasir  `MEDIUM`

**Bukti:** lihat K-2 di atas — `ERROR 1213 Deadlock found when trying to get lock`.

**Dampak:** kegagalan transaksi yang tidak bisa dijelaskan ke kasir ("Deadlock found..." bukan pesan untuk pengguna toko). Kalau backend tidak retry, order hilang di tengah proses setelah foto sudah diunggah.

**Fix (backend, bukan SQL):**
```js
async function withRetry(fn, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try { return await fn(); }
    catch (e) {
      if (e.code !== 'ER_LOCK_DEADLOCK' && e.code !== 'ER_LOCK_WAIT_TIMEOUT') throw e;
      if (i === attempts - 1) throw new AppError('Sistem sedang sibuk, coba lagi.', 503);
    }
  }
}
```
Plus: alokasi mesin **wajib** `FOR UPDATE` (K-3 membuktikan jalan bersih).

**Effort:** 15 menit.

---

### N-05 — Grafik 7 hari bolong di hari tanpa transaksi  `INFO`

**Bukti (T9):** setelah order 13 Nov di-`batal`, hasil `vw_daily_revenue_7days`:
```
2026-11-14 | 66000
2026-11-15 | 58000
```
Tanggal `2026-11-13` **hilang dari hasil**, bukan `0`. `fl_chart` akan menggambar grafik dengan hari yang loncat.

**Fix:** isi tanggal kosong di backend sebelum kirim ke Flutter:
```js
const days = [...Array(7)].map((_, i) => {
  const d = new Date(); d.setDate(d.getDate() - (6 - i));
  return d.toISOString().slice(0, 10);
});
const map = new Map(rows.map((r) => [r.order_date, r]));
const series = days.map((d) => map.get(d) ?? { order_date: d, daily_revenue: 0, total_transactions: 0, total_weight_kg: 0 });
```

---

## Bagian 5 — Catatan Kecil Lain

| # | Temuan | Sev | Bukti |
|---|---|---|---|
| N-06 | `delimiter` adalah perintah *client*. Aiven Console / GUI tertentu akan gagal di blok trigger. Pakai `mysql` CLI atau Workbench. | LOW | `DELIMITER` bukan SQL server-side |
| N-07 | `vw_daily_revenue_7days` punya `order by` di definisi view — optimizer boleh mengabaikan. Backend wajib `ORDER BY` sendiri. | INFO | definisi view |
| N-08 | `trg_before_insert_user_voucher` sekarang pakai `declare ... default 0`, sehingga user tidak ditemukan berujung pesan "poin tidak mencukupi", bukan "pelanggan tidak ditemukan". FK menutup jalur ini, jadi aman; hanya pesan kurang tepat. | INFO | `if v_user_points < v_req_points` |
| N-09 | `vw_order_details` **masih** memuat `snap_token` & `snap_redirect_url`. Aman hanya jika controller `SELECT` kolom eksplisit. View ini dipakai `GET /api/orders` yang diakses `pelanggan`. | INFO | definisi view |
| N-10 | Tidak ada constraint yang mencegah 2 order aktif memakai `machine_id` sama (MySQL tak punya partial unique index). Sudah diputuskan: terima + `FOR UPDATE` + TC-09b. | INFO | hanya `fk_orders_machine` |
| N-11 | `tinyint(1)` memicu 5 warning deprecation di MySQL 8.4. Ganti `tinyint` saja kalau mau bersih; tidak wajib. | INFO | `Code 1681` × 5 |

---

## Bagian 6 — Status Akhir

### Lulus runtime (boleh dianggap benar)

```
[x] 6 tabel, 3 view, 4 trigger terbentuk, exit 0
[x] trigger hitung harga INSERT (subtotal/diskon/total/paid_at)
[x] trigger tolak voucher terpakai / milik orang lain / reward nonaktif
[x] trigger potong poin saat redeem + CHECK points >= 0
[x] unique voucher_id menahan double-claim (terbukti di 2 sesi paralel)
[x] poin idempoten: rollback, klik ganda, midtrans bayar-belakangan
[x] bonus 2x poin (>=5kg / express)
[x] paid_at distempel otomatis saat lunas (tunai & midtrans)
[x] atomicity: poin tidak bocor saat UPDATE gagal di CHECK
[x] order batal keluar dari omzet
[x] FOR UPDATE menyerialkan alokasi mesin dengan benar (A=MC-01, B=MC-02)
[x] hash seeder cocok dengan 'password123'
```

### Belum tertutup (temuan baru)

```
[ ] N-01  trigger penjaga UPDATE kolom uang/berat/voucher   HIGH    10 mnt
[ ] N-02  kunci paid_at sekali ditulis                       HIGH     5 mnt
[ ] N-03  snapshot customer_tier di orders                   MEDIUM  20 mnt
[ ] N-04  retry ER_LOCK_DEADLOCK di backend                  MEDIUM  15 mnt
[ ] N-05  isi tanggal kosong grafik 7 hari                   INFO     5 mnt
[ ] N-09  SELECT kolom eksplisit di GET /api/orders          INFO    10 mnt
[ ] N-10  TC-09b confirm-relay ganda                         INFO     5 mnt
```

N-01 dan N-02 bisa digabung satu trigger `BEFORE UPDATE`. **Total ~35 menit** untuk menutup dua HIGH.

### Di luar file SQL (tetap wajib)

```
[ ] timezone +07:00 di connection pool      (Fix 04)
[ ] FOR UPDATE voucher di orderController   (Fix 01B)
[ ] weight <= capacity_kg                   (Fix 08)
[ ] file /uploads/sample1..3.jpg            (Fix 10)
[ ] eksekusi ulang schema di Aiven, verifikasi 6/3/4
[ ] TC-01 s/d TC-13
```

---

## Lampiran — Harness Uji

Semua uji di atas bisa diulang tanpa menyentuh MySQL utama:

```
$env:TEMP\opencode\schema_v1_2.sql        # salinan schema yang dieksekusi
$env:TEMP\opencode\tests_v1_2.sql         # 16 uji fungsional (T1-T16)
$env:TEMP\opencode\test_L*.sql            # uji atomicity trigger
$env:TEMP\opencode\test_M.sql             # uji manipulasi pasca-insert (N-01..N-03)
$env:TEMP\opencode\race_A.sql / race_B.sql
$env:TEMP\opencode\mach_naive_A/B.sql, mach_fu_A/B.sql
$env:TEMP\opencode\run-mysql-test.ps1     # bootstrap datadir scratch + load schema
$env:TEMP\opencode\concurrency.ps1        # 3 skenario konkurensi
```

Server: `mysqld --initialize-insecure --datadir=<temp>` → port 3399 → `mysql -u root --protocol=TCP -h 127.0.0.1 -P 3399`. Port 3399 sudah dikosongkan setelah uji.

**Batas kejujuran:** semua diuji di **MySQL 8.4.3 Community lokal**, bukan Aiven. Versi Aiven bisa 8.0.x. Semua fitur yang dipakai (`CHECK`, `SIGNAL`, window `BEFORE UPDATE` assignment ke `NEW`) tersedia sejak 8.0.16, jadi perilaku seharusnya identik — tapi belum dijalankan di instance Aiven itu sendiri.
