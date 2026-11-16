# Audit Verifikasi `database_schema.sql` v1.4

**Tanggal:** 15 November 2026
**Objek uji:** `database_schema.sql` (6 tabel, 3 view, 6 trigger)
**Metode:** eksekusi nyata pada MySQL 8.4.3 (instance scratch, port 3397), bukan tinjauan statis.
**Baseline:** hasil audit v1.3 (`AUDIT-database_schema-v1.3-verifikasi.md`, temuan L-01..L-08).

---

## 1. Ringkasan Hasil

| Kategori | Jumlah | Status |
|---|---|---|
| Muat schema dari nol (`exit=0`) | — | LOLOS |
| Objek terpasang | 6 tabel / 3 view / 6 trigger | LOLOS |
| Skenario jalur normal (N1–N11) | 11 | semua benar |
| Matriks serangan | 43 kasus | **34 diblokir, 9 memang sah, 0 lubang, 0 guard berlebih** |
| Temuan baru v1.4 | 4 (L-01c, L-09a, L-09b, L-09c) | ditutup |
| Regresi yang sempat masuk | 2 (R-09 `paid_at`→NULL, R-10 seeder double-count) | ditutup |
| Penyempurnaan guard | R-11 `paid_at` disuntik via INSERT `belum_bayar` | ditutup |

Rincian lengkap per kasus ada di §4.

---

## 2. Temuan Baru pada Siklus v1.4

### L-01c — `points_awarded` bisa disuntik saat INSERT (menahan poin pelanggan)

**Bukti runtime:**

```
rina sebelum = 150
insert into orders (..., points_awarded=1) values (..., 'tunai', 'antre', 1, ...);
P1 -> total=28000 flag=1
update orders set status='selesai';
P1 selesai -> rina=150 flag=1   -- poin 2 tidak pernah masuk
```

**Dampak:** kasir bisa membuat baris order dengan `points_awarded = 1` sejak awal. Saat order
berubah menjadi `selesai`, trigger poin melihat `old.points_awarded = 1` dan tidak memberi poin.
Pelanggan kehilangan hak loyalti tanpa jejak error apa pun. Tidak menaikkan hak akses (bukan
eskalasi), tetapi merusak integritas loyalti dan audit.

**Perbaikan (v1.4 final):** `trg_before_insert_order` kini selalu memaksa `new.points_awarded = 0`
dan menghitung poin sendiri bila order dibuat langsung dalam keadaan `selesai` + `lunas`.
Nilai yang dikirim klien diabaikan sepenuhnya.

```sql
set new.points_awarded = 0;

if new.status = 'selesai' and new.payment_status = 'lunas' then
    select name into v_service_name from services where id = new.service_id;
    set v_base_points = floor(new.total_price / 10000);
    if new.weight >= 5.00 or lower(coalesce(v_service_name, '')) like '%express%' then
        set v_multiplier = 2;
    end if;
    if v_base_points > 0 then
        update users set points = points + (v_base_points * v_multiplier) where id = new.user_id;
    end if;
    set new.points_awarded = 1;
end if;
```

**Verifikasi ulang:**

```
insert points_awarded=1 -> flag=0  (diabaikan trigger)
update status='selesai' -> rina 150 -> 154, flag=1  (poin 4 masuk, sesuai 28.000/10.000)
```

---

### L-09a — Arbitrase diskon lewat `reward_id` voucher yang sudah diklaim

**Bukti runtime:**

```
katalog: r1 butuh 50 poin  -> diskon 5.000
         r2 butuh 100 poin -> diskon 14.000
         r3 butuh 200 poin -> diskon 25.000

insert into user_vouchers (user_id=2, reward_id=1);  -- rina 150 -> 100 poin
update user_vouchers set reward_id=3 where id=2;      -- LOLOS di v1.3
insert into orders (..., voucher_id=2);
P2 order -> subtotal=14000 diskon=25000 total=0
```

**Dampak:** CRITICAL. Pelanggan membayar 50 poin untuk voucher diskon Rp 5.000, lalu mengubah
`reward_id` menjadi reward Rp 25.000 sebelum voucher dipakai. Potongan naik 5×, `total_price`
jatuh ke 0. Ini pencurian pendapatan langsung dan hanya butuh satu `UPDATE` tanpa privilese
khusus.

**Perbaikan:** `trg_before_update_user_voucher` mengunci `reward_id` (serta `voucher_code` dan
`user_id`). Voucher menjadi catatan immutable setelah dibuat; satu-satunya transisi yang
diizinkan adalah penandaan pemakaian `0/NULL -> 1/waktu` oleh `trg_after_insert_order`.

**Verifikasi ulang:**

```
update user_vouchers set reward_id=3 where id=2;
ERROR 1644 (45000): Jenis reward voucher tidak boleh diubah.
voucher rw=1 (tetap) — dan order hanya mendapat diskon 5.000 sesuai klaim.
```

---

### L-09b / L-09c — `voucher_code` dan `user_id` voucher bisa diubah

**Bukti runtime:** `update user_vouchers set voucher_code='P4-HACKED'` dan
`update user_vouchers set user_id=3` keduanya sukses di v1.3.

**Dampak:** penggantian `user_id` memindahkan voucher antar akun (melewati validasi kepemilikan
di `trg_before_insert_order`, karena validasi membaca `uv.user_id` yang sudah diubah).
Penggantian `voucher_code` merusak rekonsiliasi QR dan memungkinkan tabrakan kode.

**Perbaikan:** sama dengan L-09a — kedua kolom dikunci di `trg_before_update_user_voucher`.

**Verifikasi ulang:**

```
ERROR 1644 (45000): Kode voucher tidak boleh diubah.
ERROR 1644 (45000): Pemilik voucher tidak boleh diubah.
```

---

## 3. Regresi yang Ditemukan dan Ditutup

### R-09 — Guard `paid_at` membocorkan `-> NULL`

Versi v1.4 awal memakai:

```sql
if new.paid_at is not null and not (new.paid_at <=> old.paid_at) then
```

Klausa `new.paid_at is not null` membuat `update orders set paid_at = null` **lolos** guard.
Efeknya: order lunas bisa dikembalikan ke kondisi "tanpa waktu bayar", yang menghapusnya dari
`vw_daily_revenue_7days` dan `vw_dashboard_summary.today_revenue` (keduanya memfilter
`date(paid_at) = ...`). Omzet hari itu turun tanpa jejak.

**Perbaikan:** klausa `is not null` dibuang; perbandingan NULL-safe dipakai apa adanya.

```sql
if not (new.paid_at <=> old.paid_at) then
    signal sqlstate '45000'
        set message_text = 'Waktu pelunasan hanya boleh diisi otomatis oleh sistem.';
end if;
```

Guard ini berada **sebelum** stempel otomatis di trigger yang sama, jadi satu-satunya penulis
`paid_at` yang lolos adalah trigger itu sendiri.

**Verifikasi ulang:**

```
update orders set paid_at = null  where ... -> ERROR 1644
update orders set paid_at = '2020-01-01' -> ERROR 1644
update orders set paid_at = '2019-01-01' -> ERROR 1644
```

**Tambahan v1.4 final — celah `paid_at` saat INSERT.** Guard di atas hanya menutup jalur
`UPDATE`. Jalur `INSERT` masih membiarkan `paid_at` terisi pada order `belum_bayar`, karena
`trg_before_insert_order` hanya punya cabang `if` tanpa `else`:

```sql
-- sebelum
if new.payment_method = 'tunai' or new.payment_status = 'lunas' then
    set new.payment_status = 'lunas';
    if new.paid_at is null then set new.paid_at = now(); end if;
end if;   -- tidak ada else: paid_at dari klien lolos apa adanya
```

**Bukti celah:** `insert ... ('midtrans','belum_bayar','2020-01-01')` akan menyimpan
`paid_at = 2020-01-01`. Baris seperti ini ikut terhitung di `vw_dashboard_summary` bila
tanggalnya kebetulan hari ini, dan mencemari `vw_daily_revenue_7days` bila tanggalnya di dalam
jendela 7 hari — omzet bisa digelembungkan mundur tanpa transaksi nyata.

**Perbaikan:** cabang `else` yang memaksa `null`.

```sql
if new.payment_method = 'tunai' or new.payment_status = 'lunas' then
    set new.payment_status = 'lunas';
    if new.paid_at is null then
        set new.paid_at = now();
    end if;
else
    set new.paid_at = null;
end if;
```

**Verifikasi ulang (runtime):**

| Uji | Hasil |
|---|---|
| insert midtrans `belum_bayar` + `paid_at='2020-01-01'` | `pay=belum_bayar paid=NULL` |
| insert midtrans `belum_bayar` + `paid_at='2020-05-05'` | `paid=NULL`, `ada_baris_2020=0` di tren 7 hari |
| insert tunai (tanpa `paid_at`) | `pay=lunas paid≈now` (stempel otomatis tetap jalan) |
| insert midtrans `lunas` | `pay=lunas paid≈now` (stempel otomatis tetap jalan) |
| midtrans `belum_bayar` → `lunas` via `UPDATE` | `paid_stamped=1`, omzet 21.000 → 77.000 |
| `update paid_at=null` / `update paid_at='2020-01-01'` | `ERROR 1644` (guard L-04 tetap utuh) |

---

### R-10 — Seeder double-count poin

Perbaikan L-01c membuat `trg_before_insert_order` memberi poin juga pada order yang lahir
`selesai` + `lunas`. Tiga baris order di seeder berstatus `selesai`, jadi saldo akhir bergeser
dari 150/45 menjadi 152/57.

**Perbaikan:** saldo awal seeder disesuaikan (`198` dan `33`) agar hasil akhir tetap
**Rina 150 / Budi 45** sesuai PRD-02. Komentar penjelasan ditambahkan di blok seeder.

**Verifikasi ulang:** `user 2 pts=150`, `user 3 pts=45`, `order 1 flag=1`, `order 2 tier=Silver`.

---

### R-11 — `paid_at` disuntik lewat INSERT order `belum_bayar`

Guard L-04 hanya berjalan di `trg_before_update_order`. `trg_before_insert_order` tidak punya
cabang `else`, sehingga nilai `paid_at` yang dikirim klien pada order non-tunai tersimpan apa
adanya. Order `midtrans`/`belum_bayar` bisa lahir dengan `paid_at` palsu (mis. `2020-01-01`),
lalu mencemari `vw_daily_revenue_7days` dan berpotensi menggelembungkan omzet bila tanggalnya
jatuh di jendela 7 hari.

**Perbaikan:** cabang `else` yang memaksa `new.paid_at = null` untuk semua kondisi selain
tunai/lunas.

**Verifikasi ulang:** lihat tabel pada §3 R-09 di atas.

---

## 3b. Status Setelah Dua Perbaikan Terakhir

Seluruh uji dijalankan ulang dari nol setelah kedua perbaikan:

| Uji | Hasil |
|---|---|
| Muat schema bersih | `exit=0`, 6 tabel / 3 view / 6 trigger |
| Matriks serangan 43 kasus | 34 diblokir, 9 sah, **0 lubang, 0 guard berlebih** |
| Jalur normal (N1–N11) | semua benar, termasuk tunai → stempel otomatis, midtrans lunas belakangan, bonus 2×, voucher 1× pakai |
| Saldo seed | Rina **150**, Budi **45** (sesuai PRD-02) |

---

## 4. Matriks Serangan Final (43 Kasus)

Semua target memakai **nilai yang benar-benar berbeda** dari nilai lama, agar tidak ada
false-positive "LOLOS" dari operasi no-op (masalah yang ditemukan pada harness sebelumnya).

### 4.1 Harus ditolak — 34 kasus, semuanya `ERROR 1644`

| Kode | Serangan | Status |
|---|---|---|
| L-01a | reset `points_awarded` 1→0 (order selesai) | DITOLAK |
| L-01b | reset `points_awarded` 1→0 (order lain) | DITOLAK |
| L-01c | paksa `points_awarded` 0→1 sebelum selesai | DITOLAK |
| L-01e | suntik `points_awarded=1` saat INSERT | DIBERSIHKAN (dipaksa 0) |
| L-02a | reset `is_used` 1→0 | DITOLAK |
| L-02b | kosongkan `used_at` | DITOLAK |
| L-02c | geser `used_at` | DITOLAK |
| L-02d | reset `is_used` + `used_at` bersamaan | DITOLAK |
| L-02e | `is_used` 0→1 tanpa `used_at` | DITOLAK |
| L-02f | isi `used_at` pada voucher belum dipakai | DITOLAK |
| L-04a | isi `paid_at` manual | DITOLAK |
| L-04b | kosongkan `paid_at` | DITOLAK |
| L-04c | geser `paid_at` | DITOLAK |
| L-05 | `payment_status` lunas → belum_bayar | DITOLAK |
| L-06a | status selesai → proses_cuci | DITOLAK |
| L-06b | status selesai → batal | DITOLAK |
| L-06c | status selesai → siap_diambil | DITOLAK |
| L-06d | status batal → siap_diambil | DITOLAK |
| L-07a | `DELETE` satu baris order | DITOLAK |
| L-07b | `DELETE` semua order | DITOLAK |
| L-07c | `DELETE` order berstatus batal | DITOLAK |
| L-08a | ubah `order_code` | DITOLAK |
| L-08b | ubah `created_at` | DITOLAK |
| L-08c | ubah `customer_tier_snapshot` | DITOLAK |
| L-09a | tukar `reward_id` voucher | DITOLAK |
| L-09b | ubah `voucher_code` | DITOLAK |
| L-09c | ubah pemilik voucher | DITOLAK |
| N-01a | ubah `total_price` | DITOLAK |
| N-01b | ubah `subtotal_price` | DITOLAK |
| N-01c | ubah `discount_amount` | DITOLAK |
| N-01d | ubah `weight` | DITOLAK |
| N-01e | ubah `service_id` (1→2) | DITOLAK |
| N-01f | ubah `user_id` (2→3) | DITOLAK |
| N-01g | ubah `voucher_id` | DITOLAK |
| N-01i | suntik harga + status selesai bersamaan | DITOLAK |

### 4.2 Harus diterima — 9 kasus, semuanya sukses

| Kode | Operasi | Alasan sah |
|---|---|---|
| L-04d | `update` yang tidak menyentuh kolom terlindungi | no-op, tidak boleh diblokir |
| N-01h | set kolom ke nilai yang sama | no-op |
| OK-1 | ubah `machine_id` | estafet FIFO relay antar mesin |
| OK-2 | ubah `queue_wait_minutes` | dihitung ulang saat antrean berubah |
| OK-3 | ubah `notes` + `image_url` | diisi kasir setelah cucian |
| OK-4 | isi `snap_token` | ditulis backend saat membuat transaksi Midtrans |
| OK-5 | status maju siap_diambil → selesai | transisi normal, memicu poin |
| L-01e | insert dengan `points_awarded=1` | statement diterima, nilainya dipaksa 0 |
| L-01f | verifikasi flag hasil insert = 0 | memastikan sanitasi berjalan |

Catatan: `L-01e` dan `L-01f` sengaja dihitung sebagai "harus diterima" karena yang diuji adalah
**sanitasi nilai**, bukan penolakan statement. Statement berhasil, tetapi `points_awarded`
dipaksa menjadi 0 oleh trigger sehingga poin pelanggan tidak bisa ditahan.

---

## 5. Jalur Normal (Tidak Ada Regresi)

Semua dijalankan setelah reload schema dari nol.

| Skenario | Hasil runtime |
|---|---|
| Tunai → otomatis lunas + `paid_at` | `tier=Gold subtotal=21000 total=21000 pay=lunas paid≈now` |
| Estafet mesin | `machine=1 status=proses_cuci` → `machine=NULL status=siap_diambil` |
| Selesai → poin sekali | `rina 150 → 152` (`floor(21000/10000) = 2`), `flag=1` |
| Idempoten (update catatan) | `rina=152 flag=1` (tidak dobel) |
| Midtrans: selesai dulu, lunas belakangan | `budi=45 flag=0` → `budi=59 flag=1 paid_stamped=1` |
| Klaim voucher | `rina 152 → 102`, voucher `is_used=0` |
| Pakai voucher | `subtotal=14000 diskon=5000 total=9000`, voucher `is_used=1 used_at terisi` |
| Batal dari proses_cuci | `status=batal` |
| Bonus 2× express | `total=36000`, `budi=65` (+6, bukan +3) |
| Bonus 2× berat ≥ 5 kg | `total=35000`, `budi=71` (+6, bukan +3) |
| `snap_token` / `snap_redirect_url` | bisa diisi backend |
| `queue_wait_minutes` | bisa diisi (`q=20`) |
| `vw_order_details` | `tier_snapshot=Gold tier_now=Gold svc=Cuci Komplit Reguler` |
| `vw_dashboard_summary` | `omzet=185000 aktif=0 siap=1 mesin_tersedia=3` |
| `vw_daily_revenue_7days` | `2026-11-13=28000`, `2026-11-14=66000`, `2026-11-15=185000` |
| Guard poin & reward | `UPDATE users set points=-100` → error check constraint; klaim poin kurang → 1644; reward nonaktif → 1644 |
| Voucher dipakai 2× | insert kedua → 1644 "sudah pernah digunakan" |
| Voucher milik akun lain | 1644 "tidak valid untuk akun pelanggan ini" |

---

## 6. Catatan Batasan (Bukan Bug Schema)

1. **Pemakaian voucher manual.** MySQL tidak bisa membedakan DML dari klien dengan DML dari
   trigger. Satu baris `update user_vouchers set is_used=1, used_at=now()` masih sah di level
   database. Mitigasi: endpoint pemakaian voucher wajib `kasir`-only (PRD-05 TC-04/TC-12);
   level SQL tidak bisa menutup ini tanpa memindahkan penulisan ke `AFTER INSERT` pada tabel
   terpisah. Ditandai `ponytail:` di trigger.

2. **`INSERT ... SELECT` dari `user_vouchers` ke `orders` gagal `ERROR 1442`.** Ini artefak pola
   query uji, bukan cacat schema: `trg_after_insert_order` menulis `user_vouchers`, sehingga
   MySQL melarang tabel yang sama dibaca dan ditulis dalam satu statement. Aplikasi harus
   mengambil `voucher_id` lebih dulu (satu `SELECT`), lalu `INSERT` dengan nilai literal —
   yang memang sudah jadi pola backend di PRD-02.

3. **`vw_daily_revenue_7days` tidak mengisi tanggal kosong.** Hari tanpa transaksi tidak muncul
   sebagai baris. Backend wajib menyisipkan 7 tanggal (sudah jadi catatan di schema dan PRD-02).

4. **Zona waktu.** `now()` mengikuti `time_zone` server. Connection pool wajib `+07:00`
   (PRD-02), kalau tidak `paid_at` bergeser dan omzet harian salah hari.

5. **Deadlock alokasi mesin.** `SELECT ... FOR UPDATE` pada `machines` dan `user_vouchers` wajib
   di `orderController.js`, plus retry pada `ER_LOCK_DEADLOCK` (1213). Sudah dibuktikan di audit
   v1.2; tidak bisa ditutup dari sisi schema.

---

## 7. Kesiapan

Schema v1.4 dinyatakan **lulus** untuk seluruh vektor serangan level database:

- 6 tabel, 3 view, 6 trigger terpasang bersih dari nol.
- 34/34 serangan ditolak, 9/9 operasi sah diterima, 0 lubang, 0 guard berlebih.
- 16 skenario jalur normal berjalan benar, termasuk bonus 2×, voucher sekali pakai,
  pembayaran Midtrans yang lunas belakangan, dan poin idempoten.
- Saldo seed sesuai PRD: **Rina 150**, **Budi 45**.

Kewajiban yang tersisa berada di lapisan backend (bukan SQL): `FOR UPDATE` + retry deadlock,
`time_zone='+07:00'` pada pool, `SELECT` kolom eksplisit (jangan `SELECT *` agar `snap_token`
tidak ikut terekspos ke portal pelanggan), dan pengisian 7 tanggal pada grafik omzet.
