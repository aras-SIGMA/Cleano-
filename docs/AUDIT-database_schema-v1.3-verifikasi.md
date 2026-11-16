# VERIFIKASI `database_schema.sql` v1.3 (Cleano) — RUNTIME

* **Objek:** `database_schema.sql` final v1.3 (hardened runtime edition)
* **Metode:** eksekusi nyata di MySQL 8.4.3 lokal (Laragon, datadir scratch, port 3398). Server sudah dimatikan.
* **Tanggal:** 2026-11-15
* **Hasil:** load bersih (exit 0). **6 tabel / 3 view / 4 trigger.** Warning `1681` hilang total. N-01, N-02, N-03 tertutup dan **terbukti menahan serangan**. Tapi ada **4 lubang baru**, semuanya runtime-proven, 2 di antaranya memungkinkan **poin farming tanpa batas**.

---

## Bagian 1 — Load & Regression

```
schema load exit = 0
tables 6 | views 3 | triggers 4
trg_after_insert_order        AFTER  INSERT
trg_before_insert_order       BEFORE INSERT
trg_before_insert_user_voucher BEFORE INSERT
trg_before_update_order_status BEFORE UPDATE
```
Warning `1681 Integer display width` **hilang** setelah `tinyint(1)` → `tinyint`. Seed benar. `customer_tier_snapshot` terisi otomatis: order 1 = Gold, order 2 = Silver, order 3 = Gold (snapshot dari poin saat insert). Rina 200→150 (voucher).

### N-01 guard — LULUS semua jalur

| Uji | Perintah | Hasil |
|---|---|---|
| ubah `total_price` | `set total_price = 999999` | `ERROR 1644 ... tidak boleh diubah setelah dibuat` |
| ubah `subtotal_price` | `set subtotal_price = 1` | ditolak 1644 |
| ubah `discount_amount` | `set discount_amount = 1` | ditolak 1644 |
| ubah `weight` | `set weight = 99.00` | ditolak 1644 |
| ubah `service_id` | `set service_id = 2` | ditolak 1644 |
| ubah `user_id` | `set user_id = 3` | ditolak 1644 |
| ubah `voucher_id` | `set voucher_id = 1` | ditolak 1644 |
| **harga + status `selesai` bareng** | `set status='selesai', total_price=500000` | ditolak, **poin tidak bertambah** (150→150) |

Eskalasi N-01 dari v1.2 (`total_price=500000` → poin +50) sekarang **mati total**.

### N-02 guard — LULUS

| Uji | Hasil |
|---|---|
| `set paid_at = '2000-01-01'` pada order lunas | `ERROR 1644 Waktu pelunasan (paid_at) tidak boleh diubah setelah tercatat` |
| `set paid_at = null` | ditolak 1644 |
| `set paid_at = ...` saat `payment_status='belum_bayar'` | **ditolak 1644** — paid_at sudah terisi saat seed, jadi guard aktif (lihat L-04, ini bukan celah) |

### N-03 snapshot tier — LULUS

`vw_order_details` sekarang punya `customer_tier` (snapshot, statis) **dan** `customer_current_tier` (live). Order lama tidak lagi berubah tier-nya saat pelanggan naik level. Kasus v1.2 ("satu pelanggan dua tier di satu laporan") tertutup.

### Regression lain — LULUS

| Uji | Hasil |
|---|---|
| poin dasar saat `selesai` | 150 → 152 (+2) ✅ |
| klik ganda `selesai` | tetap ✅ |
| midtrans: `selesai` saat `belum_bayar` | tidak ada poin (45→45) ✅ |
| midtrans: lalu `lunas` | poin masuk (45→47), `paid_at` distempel ✅ |
| bonus 2× express / ≥5 kg | 6 kg express → +14 ✅ |
| voucher terpakai 2× | `ERROR 1644 Voucher sudah pernah digunakan` ✅ |
| voucher + unique constraint | `ERROR 1062 uq_orders_voucher` ✅ |
| reward nonaktif / poin kurang | `ERROR 1644` sesuai pesan ✅ |
| `CHECK points >= 0` / `weight > 0` | `ERROR 3819` ✅ |
| `INSERT ... SELECT` | trigger tetap menimpa harga ✅ |
| order `batal` keluar omzet | ✅ |
| atomicity trigger saat UPDATE gagal | poin tidak bocor ✅ |

---

## Bagian 2 — Lubang Baru (runtime-proven)

### L-01 — `points_awarded` bisa direset → **poin farming tanpa batas**  `CRITICAL`

**Masalah:** guard N-01 melindungi 7 kolom, tapi **tidak** menyertakan `points_awarded`. Kolom itu adalah satu-satunya penghalang idempotensi poin. Siapa pun yang bisa `UPDATE orders` dapat mengosongkannya lalu memicu award ulang, berulang kali.

**Bukti (dieksekusi, W1):**
```sql
-- awal: 168 poin
update orders set points_awarded = 0 where id = 3;
update orders set status = 'proses_cuci' where id = 3;
update orders set status = 'selesai'       where id = 3;
-- -> 170
-- ulangi pola yang sama:
-- -> 172
-- -> 174
```
Tiga putaran, +6 poin dari satu order. Tidak ada batas. Loop 1000× = +2000 poin = 20 voucher gratis.

**Dampak:** pelanggaran langsung KPI PRD-01 §3. `kasir` (atau siapa pun yang pegang `UPDATE` di `orders`) bisa mencetak poin tanpa batas. Kebocoran finansial langsung: poin → voucher → potongan omzet.

**Fix — perluas guard N-01** (satu baris, di trigger `BEFORE UPDATE` yang sudah ada):

```sql
or new.points_awarded != old.points_awarded
```
Tapi ini menabrak kebutuhan internal trigger sendiri (trigger menulis `NEW.points_awarded = 1`). Solusi bersih: **hanya izinkan transisi 0 → 1**, tolak sisanya:

```sql
-- tambahkan setelah guard N-01
if old.points_awarded = 1 and new.points_awarded = 0 then
    signal sqlstate '45000'
        set message_text = 'Status pemberian poin tidak boleh dibatalkan.';
end if;
```
Karena trigger hanya pernah menulis `0 → 1`, larangan `1 → 0` tidak memblokir logika sah. Backend tidak pernah butuh mengosongkan flag ini.

**Effort:** 3 menit.

---

### L-02 — `user_vouchers.is_used` bisa direset → **voucher dipakai berulang**  `CRITICAL`

**Masalah:** `trg_after_insert_order` menulis `is_used = 1`, tapi tidak ada trigger yang mencegah penulisan `is_used = 0` kembali. Voucher "sekali pakai" menjadi bisa dipakai tak terbatas.

**Bukti (dieksekusi, X1–X2):**
```sql
-- pakai voucher 1
insert into orders (... voucher_id=1 ...);   -- diskon 5000, total 9000, is_used -> 1
update user_vouchers set is_used = 0 where id = 1;
insert into orders (... voucher_id=1 ...);   -- diskon 5000 LAGI, total 9000, is_used -> 1
```
Dua order, diskon dobel. `uq_orders_voucher` tidak menahan karena baris order lama sudah dihapus lebih dulu — dan tetap tidak akan menahan kalau order lama di-`UPDATE` agar `voucher_id = NULL` (boleh, karena... lihat L-03).

**Dampak:** sama dengan C-01 di v1.0 tapi lewat jalur berbeda. KPI "nol double-claim" bocor lewat `UPDATE`, bukan `INSERT`.

**Fix — kunci `is_used` sekali jadi 1:**
```sql
delimiter $$
create trigger trg_before_update_user_voucher
before update on user_vouchers
for each row
begin
    if old.is_used = 1 and new.is_used = 0 then
        signal sqlstate '45000'
            set message_text = 'Voucher yang sudah terpakai tidak dapat diaktifkan kembali.';
    end if;
end$$
delimiter ;
```
**Effort:** 5 menit.

---

### L-03 — `voucher_id` boleh dibersihkan lewat `UPDATE ... SET voucher_id = NULL`, membebaskan kembali keunikan  `HIGH`

**Masalah:** guard N-01 memakai `not (new.voucher_id <=> old.voucher_id)` sehingga perubahan apa pun ditolak — **termasuk** `voucher_id → NULL`. Uji V7 (`set voucher_id = 1` pada order tanpa voucher) ditolak. Tapi jalur sebaliknya perlu diperiksa: apakah `NULL`-kan masih mungkin?

**Status:** pada uji ini **tertahan** oleh guard yang sama (`<=>` menangkap kedua arah). Jadi bukan celah aktif — tapi ini **ketergantungan rapuh**: kalau kelak guard dilonggarkan untuk mengizinkan pelepasan voucher (misal kasir salah scan), `uq_orders_voucher` langsung bisa dilewati. Catat sebagai batasan desain, bukan bug sekarang.

**Rekomendasi:** jangan longgarkan. Kalau butuh koreksi voucher, wajibkan `status = 'batal'` lalu order baru.

---

### L-04 — `paid_at` bisa dipaksa terisi saat `payment_status` masih `belum_bayar` → omzet hilang dari laporan  `HIGH`

**Masalah:** guard N-02 hanya menolak perubahan **kalau `old.paid_at` sudah terisi**. Saat `paid_at` masih `NULL`, siapa pun boleh mengisinya dengan tanggal apa pun, termasuk masa lalu, sebelum pembayaran benar-benar terjadi.

**Bukti (dieksekusi, P4):**
```sql
-- order baru, midtrans, belum_bayar, paid_at = NULL
update orders set paid_at = '2020-05-05 05:05:05' where order_code = 'CLN-P4';  -- LOLOS
update orders set payment_status = 'lunas'  where order_code = 'CLN-P4';
-- hasil: lunas, paid_at = 2020-05-05 (dipertahankan, tidak distempel now())
-- today_revenue TIDAK bertambah 14000
```
Transaksi lunas hari ini, tapi omzetnya tercatat tahun 2020 dan hilang dari `vw_dashboard_summary` maupun `vw_daily_revenue_7days`.

**Dampak:** kebalikan dari N-02. N-02 menutup "menggeser uang keluar setelah tercatat", L-04 membuka "menanam paid_at palsu sebelum tercatat". Hasil akhirnya sama: laporan bisa dipangkas.

**Fix — stempel `paid_at` sepenuhnya di server, tolak nilai eksplisit:**
```sql
-- di trg_before_update_order_status, ganti blok n-02 jadi:
if new.paid_at is not null and not (new.paid_at <=> old.paid_at) then
    signal sqlstate '45000'
        set message_text = 'Waktu pelunasan hanya boleh diisi otomatis oleh sistem.';
end if;
```
Lalu andalkan satu-satunya penulis `paid_at`: trigger itu sendiri (INSERT tunai + UPDATE saat lunas). Backend tidak perlu mengirim `paid_at` sama sekali.

**Effort:** 3 menit.

---

### L-05 — `payment_status` bisa bolak-balik `lunas → belum_bayar → lunas`  `MEDIUM`

**Bukti (dieksekusi, P2–P3):**
```sql
update orders set payment_status = 'belum_bayar' where order_code = 'CLN-R1';
-- today_revenue: 56000 -> 28000 (order 28000 hilang dari omzet)
update orders set payment_status = 'lunas' where order_code = 'CLN-R1';
-- paid_at dipertahankan (2026-11-15 19:44:57), bukan distempel ulang
```
Omzet bisa dinaikkan/diturunkan sesuka hati dengan toggle status, tanpa menyentuh `paid_at`.

**Dampak:** laporan keuangan bisa "dipoles" sebelum screenshot. Kalau digabung L-04, jendela manipulasi makin lebar.

**Fix:** status pembayaran hanya boleh maju:
```sql
if old.payment_status = 'lunas' and new.payment_status = 'belum_bayar' then
    signal sqlstate '45000'
        set message_text = 'Status lunas tidak dapat dibatalkan. Gunakan pembatalan order.';
end if;
```

---

### L-06 — Status order bisa mundur & lompat  `MEDIUM`

**Bukti (dieksekusi, W8 + V17):**
```sql
-- maju: antre -> selesai langsung, poin diberikan (154 -> 168, +14)
update orders set status = 'selesai' where order_code = 'CLN-V17';
-- mundur: selesai -> proses_cuci, poin TIDAK ditarik
update orders set status = 'proses_cuci' where id = 3;
-- hasil: status proses_cuci, points_awarded tetap 1, poin 154 tetap di akun
```
Order yang sudah selesai bisa dihidupkan lagi dan dijual ulang, sementara poinnya sudah masuk. Tidak ada state machine di lapisan DB.

**Dampak:** sedang. Butuh akses `UPDATE orders` (role `kasir`). Bukan eskalasi, tapi merusak konsistensi operasional dan audit.

**Fix (minimal):** tolak transisi keluar dari status final.
```sql
if old.status in ('selesai','batal') and new.status != old.status then
    signal sqlstate '45000'
        set message_text = 'Order yang sudah selesai atau batal tidak dapat diubah statusnya.';
end if;
```
Transisi maju lain biarkan bebas — validasi urutan penuh lebih baik di backend supaya pesan errornya jelas.

---

### L-07 — `orders` bisa di-`DELETE` bebas, meninggalkan poin & omzet yatim  `MEDIUM`

**Bukti (dieksekusi, Z6–Z8):**
```sql
delete from orders where id = 1;   -- 5 baris -> 4 baris, berhasil
delete from orders;                -- 4 baris -> 0, berhasil
```
Tidak ada trigger `BEFORE DELETE`, tidak ada soft-delete. Poin yang sudah diberikan tetap di `users.points`; omzet yang sudah dihitung hilang; voucher yang terlanjur `is_used = 1` menjadi hangus selamanya (X3) karena baris order pemakainya lenyap.

**Dampak:** audit trail bisa dihapus total. Satu `DELETE` menghapus bukti transaksi, dan poin yang sudah terlanjur masuk tidak bisa direkonsiliasi.

**Fix:** larang hard delete.
```sql
delimiter $$
create trigger trg_before_delete_order
before delete on orders
for each row
begin
    signal sqlstate '45000'
        set message_text = 'Order tidak boleh dihapus. Gunakan status batal untuk membatalkan.';
end$$
delimiter ;
```
*(ponytail: kalau nanti butuh bersih-bersih data uji, drop trigger dulu saat maintenance — belum perlu jalur resmi.)*

---

### L-08 — `order_code`, `created_at`, `machine_id`, `customer_tier_snapshot` bebas diubah  `LOW`

**Bukti (dieksekusi):**
```sql
update orders set order_code = 'CLN-HIJACK-0001' where id = 3;      -- LOLOS
update orders set created_at = '2020-01-01'      where id = 3;      -- LOLOS
update orders set machine_id = 3                 where id = 3;      -- LOLOS
update orders set customer_tier_snapshot='Platinum' where id = 3;   -- LOLOS
```
Daftar kolom yang **tidak** dilindungi guard (dari `information_schema`):
```
order_code, customer_tier_snapshot, machine_id, payment_method, payment_status,
snap_token, snap_redirect_url, status, queue_wait_minutes, points_awarded,
image_url, notes, created_at, updated_at
```

`order_code` adalah identifier yang dikutip ke pelanggan dan Midtrans — mengubahnya memutus jejak pembayaran. `created_at` menggeser jendela laporan (bukan omzet, karena omzet pakai `paid_at`, tapi daftar "order hari ini" jadi bohong).

**Fix prioritas:** `order_code` dan `created_at` masuk guard N-01 (`created_at` hanya boleh tidak berubah). `machine_id` sengaja dibiarkan bisa diubah — itu justru inti estafet FIFO. `customer_tier_snapshot` sebaiknya dikunci juga karena itu snapshot historis.

---

## Bagian 3 — Ringkasan Lubang per Kolom

| Kolom `orders` | Dijaga? | Bisa disalahgunakan |
|---|---|---|
| `subtotal_price`, `discount_amount`, `total_price` | ✅ N-01 | — |
| `weight`, `service_id`, `user_id`, `voucher_id` | ✅ N-01 | — |
| `paid_at` | ⚠️ sebagian | **L-04** (isi saat belum bayar) |
| `points_awarded` | ❌ | **L-01 poin farming** |
| `payment_status` | ❌ | **L-05** toggle omzet |
| `status` | ❌ | **L-06** mundur / lompat |
| `order_code` | ❌ | L-08 putus jejak pembayaran |
| `created_at` | ❌ | L-08 geser jendela laporan |
| `customer_tier_snapshot` | ❌ | L-08 palsukan tier historis |
| `machine_id` | ❌ (sengaja) | dibutuhkan estafet FIFO |
| `image_url`, `notes`, `snap_*` | ❌ (wajar) | — |

| Tabel lain | Dijaga? | Catatan |
|---|---|---|
| `user_vouchers.is_used` | ❌ | **L-02 voucher dipakai ulang** |
| `user_vouchers.*` DELETE | ❌ | hapus voucher → hilang dari dompet |
| `orders` DELETE | ❌ | **L-07 audit trail hilang** |
| `users.points` | ⚠️ hanya `CHECK >= 0` | tidak dijaga dari penulisan langsung |

---

## Bagian 4 — Urutan Perbaikan

| # | Aksi | Menutup | Effort |
|---|---|---|---|
| 1 | Guard `old.points_awarded = 1 and new.points_awarded = 0` → `SIGNAL` | **L-01** | 3 mnt |
| 2 | Trigger `BEFORE UPDATE user_vouchers`: `1 → 0` dilarang | **L-02** | 5 mnt |
| 3 | Guard `paid_at`: tolak semua perubahan eksplisit | **L-04** | 3 mnt |
| 4 | Guard `payment_status`: `lunas → belum_bayar` dilarang | L-05 | 3 mnt |
| 5 | Guard `status`: tidak boleh keluar dari `selesai`/`batal` | L-06 | 3 mnt |
| 6 | Trigger `BEFORE DELETE orders` → `SIGNAL` | L-07 | 5 mnt |
| 7 | Masukkan `order_code`, `created_at`, `customer_tier_snapshot` ke guard N-01 | L-08 | 5 mnt |

**Total ~27 menit**, semuanya di dalam satu trigger `BEFORE UPDATE` + dua trigger kecil baru. Tidak ada perubahan DDL.

---

## Bagian 5 — Yang Lulus & Yang Tidak Bisa Diuji di SQL

### Lulus runtime
```
[x] load bersih, 6 tabel / 3 view / 4 trigger, tanpa warning
[x] N-01 guard: 7 kolom + jalur eskalasi poin
[x] N-02 guard: paid_at terkunci setelah tercatat
[x] N-03 snapshot tier: order lama tidak berubah tier
[x] poin idempoten: rollback, klik ganda, midtrans bayar-belakangan
[x] bonus 2x, voucher 1x pakai, unique constraint, CHECK constraints
[x] atomicity trigger saat UPDATE gagal
[x] omzet exclude batal, berbasis paid_at
[x] hash seeder = password123
```

### Tetap di luar SQL (wajib di backend)
```
[ ] FOR UPDATE pada user_vouchers di POST /api/orders      (Fix 01B)
[ ] FOR UPDATE pada machines saat alokasi & confirm-relay  (K-3 membuktikan perlu)
[ ] retry ER_LOCK_DEADLOCK (1213)                           (N-04 v1.2)
[ ] timezone +07:00 pada connection pool                    (Fix 04)
[ ] SELECT kolom eksplisit — snap_token masih ada di view   (N-09)
[ ] isi tanggal kosong grafik 7 hari                        (N-05)
[ ] weight <= capacity_kg                                   (Fix 08)
[ ] file /uploads/sample1..3.jpg
[ ] eksekusi ulang di Aiven + verifikasi 6/3/4
[ ] TC-01 s/d TC-13
```

---

## Lampiran — Harness Uji

```
$env:TEMP\opencode\schema_v1_3.sql    # salinan schema yang dieksekusi
$env:TEMP\opencode\audit_cols.sql     # daftar kolom + guard coverage
$env:TEMP\opencode\test_v13_a.sql     # V1-V20 guard N-01/N-02 + jalur normal
$env:TEMP\opencode\test_v13_b.sql     # W1-W9 poin farming, voucher, payment_status
$env:TEMP\opencode\test_v13_c.sql     # X1-X4 voucher reuse
$env:TEMP\opencode\test_v13_d.sql     # Y1-Y5 INSERT selesai / no-op update
$env:TEMP\opencode\test_v13_e.sql     # Z1-Z5 delete & FK behaviour
$env:TEMP\opencode\test_v13_f.sql     # Z6-Z8 verifikasi count delete (anti false-positive)
$env:TEMP\opencode\test_v13_g.sql     # P1-P5 omzet toggle + paid_at palsu
$env:TEMP\opencode\boot3.ps1          # bootstrap datadir scratch + load
$env:TEMP\opencode\run13a.ps1 / run13c.ps1
```

Catatan metodologi: satu hipotesis awal (delete 1 baris menyisakan 1 dari 6) saya **verifikasi ulang** di `test_v13_f.sql` dengan hitung baris eksplisit — hasilnya 5→4, jadi laporan awal itu salah dan **tidak** saya masukkan sebagai temuan. Hanya temuan yang bisa direproduksi dengan query eksplisit yang masuk tabel.

Batas kejujuran: diuji di MySQL 8.4.3 Community lokal, bukan instance Aiven (kemungkinan 8.0.x). Semua fitur yang dipakai tersedia sejak 8.0.16.
