-- ============================================================================
-- file: database_schema.sql (final v1.4 - hardened + guard lengkap)
-- proyek: cleano (smart laundry pos & order tracking system)
-- dbms: mysql 8.0.16+ / 8.4+ (aiven cloud / localhost)
--
-- riwayat perbaikan:
--   v1.1  guard NOT FOUND, points_awarded, paid_at, exclude batal, hash seeder
--   v1.2  paid_at untuk omzet (bukan created_at)
--   v1.3  immutability guard harga/berat/paid_at, snapshot customer tier
--   v1.4  L-01 points_awarded tidak bisa direset (poin farming)
--         L-02 user_vouchers.is_used tidak bisa direset (voucher 1x pakai)
--         L-04 paid_at hanya boleh diisi sistem, bukan manual (termasuk NULL)
--              + order belum_bayar dipaksa paid_at = null saat INSERT
--                (klien tidak bisa menyuntik waktu pelunasan palsu)
--         L-05 payment_status tidak bisa mundur lunas -> belum_bayar
--         L-06 status order tidak bisa keluar dari selesai / batal
--         L-07 order tidak boleh dihapus (hard delete dilarang)
--         L-08 order_code, created_at, customer_tier_snapshot dikunci
--         L-09 voucher_code, user_id, reward_id voucher dikunci
--              (sebelumnya reward_id bisa ditukar -> arbitrase diskon)
-- ============================================================================

create database if not exists cleano_db
  character set utf8mb4
  collate utf8mb4_unicode_ci;

use cleano_db;

set foreign_key_checks = 0;
drop view if exists vw_order_details;
drop view if exists vw_daily_revenue_7days;
drop view if exists vw_dashboard_summary;

drop trigger if exists trg_before_insert_user_voucher;
drop trigger if exists trg_before_insert_order;
drop trigger if exists trg_after_insert_order;
drop trigger if exists trg_before_update_order;
drop trigger if exists trg_before_update_user_voucher;
drop trigger if exists trg_before_delete_order;

drop table if exists orders;
drop table if exists user_vouchers;
drop table if exists rewards;
drop table if exists machines;
drop table if exists services;
drop table if exists users;
set foreign_key_checks = 1;


-- ============================================================================
-- bagian 1: pembuatan 6 tabel utama (ddl)
-- ============================================================================

-- 1. tabel users
create table users (
    id int auto_increment primary key,
    name varchar(100) not null,
    email varchar(100) not null unique,
    password varchar(255) not null,
    role enum('kasir', 'pelanggan') not null default 'pelanggan',
    phone varchar(20) not null unique,
    created_at timestamp not null default current_timestamp,
    member_code varchar(20) not null unique,
    points int not null default 0,
    constraint chk_users_points check (points >= 0)
) engine=innodb default charset=utf8mb4 collate=utf8mb4_unicode_ci;


-- 2. tabel services
create table services (
    id int auto_increment primary key,
    name varchar(100) not null,
    price_per_kg int not null,
    wash_duration_minutes int not null default 45,
    estimated_hours int not null default 24,
    requires_machine tinyint not null default 1,
    description text null,
    created_at timestamp not null default current_timestamp,
    constraint chk_services_price check (price_per_kg > 0),
    constraint chk_services_duration check (wash_duration_minutes >= 0)
) engine=innodb default charset=utf8mb4 collate=utf8mb4_unicode_ci;


-- 3. tabel machines
create table machines (
    id int auto_increment primary key,
    machine_code varchar(20) not null unique,
    status enum('tersedia', 'digunakan', 'maintenance') not null default 'tersedia',
    capacity_kg decimal(4, 2) not null default 7.00,
    estimated_finish_at datetime null,
    index idx_machines_status_finish (status, estimated_finish_at)
) engine=innodb default charset=utf8mb4 collate=utf8mb4_unicode_ci;


-- 4. tabel rewards
create table rewards (
    id int auto_increment primary key,
    title varchar(100) not null,
    description text null,
    points_required int not null,
    discount_amount int not null,
    is_active tinyint not null default 1,
    created_at timestamp not null default current_timestamp,
    index idx_rewards_active (is_active),
    constraint chk_rewards_points check (points_required > 0),
    constraint chk_rewards_discount check (discount_amount > 0)
) engine=innodb default charset=utf8mb4 collate=utf8mb4_unicode_ci;


-- 5. tabel user_vouchers
create table user_vouchers (
    id int auto_increment primary key,
    voucher_code varchar(30) not null unique,
    user_id int not null,
    reward_id int not null,
    is_used tinyint not null default 0,
    used_at datetime null,
    created_at timestamp not null default current_timestamp,
    index idx_uv_user_used (user_id, is_used),
    constraint fk_uv_user foreign key (user_id) references users(id)
        on delete cascade on update cascade,
    constraint fk_uv_reward foreign key (reward_id) references rewards(id)
        on delete restrict on update cascade
) engine=innodb default charset=utf8mb4 collate=utf8mb4_unicode_ci;


-- 6. tabel orders
create table orders (
    id int auto_increment primary key,
    order_code varchar(30) not null unique,
    user_id int not null,
    customer_tier_snapshot varchar(10) not null default 'Silver',
    service_id int not null,
    machine_id int null,
    weight decimal(4, 2) not null,
    subtotal_price int not null,
    discount_amount int not null default 0,
    total_price int not null,
    payment_method enum('tunai', 'midtrans') not null,
    payment_status enum('belum_bayar', 'lunas') not null default 'belum_bayar',
    paid_at datetime null,
    snap_token varchar(255) null,
    snap_redirect_url text null,
    status enum('antre', 'proses_cuci', 'sedang_diproses', 'siap_diambil', 'selesai', 'batal') not null default 'antre',
    queue_wait_minutes int not null default 0,
    points_awarded tinyint not null default 0,
    image_url varchar(255) not null,
    notes text null,
    created_at timestamp not null default current_timestamp,
    updated_at timestamp not null default current_timestamp on update current_timestamp,
    voucher_id int null,
    constraint uq_orders_voucher unique (voucher_id),
    index idx_orders_status_created (status, created_at),
    index idx_orders_payment_paid (payment_status, paid_at),
    index idx_orders_user_created (user_id, created_at),
    constraint chk_orders_weight check (weight > 0),
    constraint chk_orders_total check (total_price >= 0),
    constraint fk_orders_user foreign key (user_id) references users(id)
        on delete restrict on update cascade,
    constraint fk_orders_service foreign key (service_id) references services(id)
        on delete restrict on update cascade,
    constraint fk_orders_machine foreign key (machine_id) references machines(id)
        on delete set null on update cascade,
    constraint fk_orders_voucher foreign key (voucher_id) references user_vouchers(id)
        on delete set null on update cascade
) engine=innodb default charset=utf8mb4 collate=utf8mb4_unicode_ci;


-- ============================================================================
-- bagian 2: trigger
-- ============================================================================

delimiter $$

-- ----------------------------------------------------------------------------
-- trigger 1: klaim voucher. validasi saldo poin lalu potong otomatis.
-- ----------------------------------------------------------------------------
create trigger trg_before_insert_user_voucher
before insert on user_vouchers
for each row
begin
    declare v_user_points int;
    declare v_req_points int;
    declare v_active tinyint;

    select points into v_user_points from users where id = new.user_id;
    select points_required, is_active into v_req_points, v_active from rewards where id = new.reward_id;

    if v_user_points is null then
        signal sqlstate '45000' set message_text = 'Pelanggan tidak ditemukan.';
    end if;

    if v_active is null then
        signal sqlstate '45000' set message_text = 'Katalog reward tidak ditemukan.';
    end if;

    if v_active = 0 then
        signal sqlstate '45000' set message_text = 'Promo reward sudah tidak aktif.';
    end if;

    if v_user_points < v_req_points then
        signal sqlstate '45000' set message_text = 'Poin pelanggan tidak mencukupi untuk klaim voucher ini.';
    end if;

    update users set points = points - v_req_points where id = new.user_id;
end$$


-- ----------------------------------------------------------------------------
-- trigger 2: buat order. validasi voucher, hitung harga, snapshot tier,
--            stempel paid_at untuk tunai, dan kendalikan flag poin (L-01c).
-- ----------------------------------------------------------------------------
create trigger trg_before_insert_order
before insert on orders
for each row
begin
    declare v_price_per_kg int;
    declare v_user_points int;
    declare v_vcr_used tinyint;
    declare v_vcr_owner int;
    declare v_discount int default 0;
    declare v_service_name varchar(100);
    declare v_base_points int;
    declare v_multiplier int default 1;

    select points into v_user_points from users where id = new.user_id;
    if v_user_points is null then
        signal sqlstate '45000' set message_text = 'Pelanggan tidak ditemukan.';
    end if;

    set new.customer_tier_snapshot = case
        when v_user_points >= 300 then 'Platinum'
        when v_user_points >= 100 then 'Gold'
        else 'Silver'
    end;

    select price_per_kg into v_price_per_kg from services where id = new.service_id;
    if v_price_per_kg is null then
        signal sqlstate '45000' set message_text = 'Paket layanan tidak ditemukan.';
    end if;

    set new.subtotal_price = round(new.weight * v_price_per_kg);

    if new.voucher_id is not null then
        select uv.is_used, uv.user_id, r.discount_amount
        into v_vcr_used, v_vcr_owner, v_discount
        from user_vouchers uv
        join rewards r on uv.reward_id = r.id
        where uv.id = new.voucher_id;

        if v_vcr_owner is null then
            signal sqlstate '45000' set message_text = 'Kode voucher tidak ditemukan.';
        end if;

        if v_vcr_owner != new.user_id then
            signal sqlstate '45000' set message_text = 'Voucher tidak valid untuk akun pelanggan ini.';
        end if;

        if v_vcr_used = 1 then
            signal sqlstate '45000' set message_text = 'Voucher sudah pernah digunakan (hanya berlaku 1x pakai).';
        end if;

        set new.discount_amount = v_discount;
    else
        set new.discount_amount = 0;
    end if;

    set new.total_price = greatest(0, new.subtotal_price - new.discount_amount);

    -- L-04: paid_at hanya boleh diisi sistem.
    -- tunai / sudah lunas -> distempel sekarang; selain itu (mis. midtrans
    -- belum_bayar) WAJIB null, supaya klien tidak bisa menyuntik waktu
    -- pelunasan palsu saat INSERT dan mengacak omzet harian.
    if new.payment_method = 'tunai' or new.payment_status = 'lunas' then
        set new.payment_status = 'lunas';
        if new.paid_at is null then
            set new.paid_at = now();
        end if;
    else
        set new.paid_at = null;
    end if;

    -- L-01c: flag poin dikendalikan sistem, bukan pemanggil.
    -- klien tidak boleh menyuntik points_awarded=1 untuk menahan poin pelanggan.
    set new.points_awarded = 0;

    if new.status = 'selesai' and new.payment_status = 'lunas' then
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


-- ----------------------------------------------------------------------------
-- trigger 3: tandai voucher terpakai setelah order tersimpan.
-- ----------------------------------------------------------------------------
create trigger trg_after_insert_order
after insert on orders
for each row
begin
    if new.voucher_id is not null then
        update user_vouchers
        set is_used = 1, used_at = now()
        where id = new.voucher_id;
    end if;
end$$


-- ----------------------------------------------------------------------------
-- trigger 4: guard utama orders (BEFORE UPDATE).
--   L-08  kunci order_code, created_at, customer_tier_snapshot
--   N-01  kunci harga, berat, layanan, pemilik, voucher
--   L-04  paid_at hanya boleh diisi sistem (termasuk larangan dikosongkan)
--   L-01  points_awarded tidak boleh dibatalkan (1 -> 0)
--   L-01b points_awarded tidak boleh dinaikkan manual (0 -> 1)
--   L-05  payment_status tidak boleh mundur dari lunas
--   L-06  status tidak boleh keluar dari selesai / batal
--   lalu: stempel paid_at otomatis & pemberian poin idempoten sekali jalan
-- ----------------------------------------------------------------------------
create trigger trg_before_update_order
before update on orders
for each row
begin
    declare v_service_name varchar(100);
    declare v_base_points int;
    declare v_multiplier int default 1;

    -- L-08: identitas & jejak waktu tidak boleh berubah
    if new.order_code != old.order_code then
        signal sqlstate '45000'
            set message_text = 'Kode order tidak boleh diubah.';
    end if;

    if not (new.created_at <=> old.created_at) then
        signal sqlstate '45000'
            set message_text = 'Waktu pembuatan order tidak boleh diubah.';
    end if;

    if not (new.customer_tier_snapshot <=> old.customer_tier_snapshot) then
        signal sqlstate '45000'
            set message_text = 'Snapshot tier pelanggan tidak boleh diubah.';
    end if;

    -- N-01: nilai uang & komposisi order tidak boleh berubah
    if new.subtotal_price != old.subtotal_price
       or new.discount_amount != old.discount_amount
       or new.total_price != old.total_price
       or new.weight != old.weight
       or new.service_id != old.service_id
       or new.user_id != old.user_id
       or not (new.voucher_id <=> old.voucher_id) then
        signal sqlstate '45000'
            set message_text = 'Harga, berat, layanan, dan voucher order tidak boleh diubah setelah dibuat.';
    end if;

    -- L-04: paid_at hanya boleh ditulis oleh sistem.
    -- guard ini berjalan SEBELUM stempel otomatis di bawah, jadi satu-satunya
    -- penulis yang lolos adalah trigger ini sendiri. semua perubahan eksplisit
    -- (mengisi saat belum bayar, menggeser, atau mengosongkan) ditolak.
    if not (new.paid_at <=> old.paid_at) then
        signal sqlstate '45000'
            set message_text = 'Waktu pelunasan hanya boleh diisi otomatis oleh sistem.';
    end if;

    -- L-01: poin yang sudah diberikan tidak boleh dibatalkan (mencegah poin farming)
    if old.points_awarded = 1 and new.points_awarded = 0 then
        signal sqlstate '45000'
            set message_text = 'Status pemberian poin tidak boleh dibatalkan.';
    end if;

    -- L-01b: flag poin hanya boleh naik ke 1 bersamaan dengan transisi ke selesai+lunas
    --        (mencegah kasir menahan poin pelanggan dengan memaksa flag = 1 lebih dulu)
    if old.points_awarded = 0 and new.points_awarded = 1
       and not (new.status = 'selesai' and new.payment_status = 'lunas') then
        signal sqlstate '45000'
            set message_text = 'Status pemberian poin hanya boleh diisi otomatis oleh sistem.';
    end if;

    -- L-05: pembayaran tidak boleh mundur dari lunas
    if old.payment_status = 'lunas' and new.payment_status = 'belum_bayar' then
        signal sqlstate '45000'
            set message_text = 'Status lunas tidak dapat dibatalkan. Gunakan pembatalan order.';
    end if;

    -- L-06: order final tidak boleh dihidupkan kembali
    if old.status in ('selesai', 'batal') and new.status != old.status then
        signal sqlstate '45000'
            set message_text = 'Order yang sudah selesai atau batal tidak dapat diubah statusnya.';
    end if;

    -- stempel paid_at otomatis saat berubah menjadi lunas
    if old.payment_status != 'lunas' and new.payment_status = 'lunas' and new.paid_at is null then
        set new.paid_at = now();
    end if;

    -- poin tepat satu kali, dihitung dari harga final yang tidak bisa diubah
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


-- ----------------------------------------------------------------------------
-- trigger 5 (L-02): voucher sekali pakai tidak boleh diaktifkan kembali,
--            dan identitas voucher tidak boleh ditukar (arbitrase diskon).
-- ----------------------------------------------------------------------------
create trigger trg_before_update_user_voucher
before update on user_vouchers
for each row
begin
    -- L-02c: kode, pemilik, dan reward voucher dikunci.
    -- tanpa ini, klaim reward murah (50 poin) bisa ditukar jadi reward mahal
    -- (25.000 diskon) hanya dengan mengubah reward_id setelah voucher dibuat.
    if new.voucher_code != old.voucher_code then
        signal sqlstate '45000'
            set message_text = 'Kode voucher tidak boleh diubah.';
    end if;

    if new.user_id != old.user_id then
        signal sqlstate '45000'
            set message_text = 'Pemilik voucher tidak boleh diubah.';
    end if;

    if new.reward_id != old.reward_id then
        signal sqlstate '45000'
            set message_text = 'Jenis reward voucher tidak boleh diubah.';
    end if;

    -- is_used & used_at hanya boleh berubah bersamaan, dan hanya lewat transisi
    -- pemakaian voucher: 0/NULL -> 1/waktu (ditulis trg_after_insert_order).
    -- seluruh bentuk lain ditolak: reset 1->0, is_used naik tanpa used_at,
    -- used_at diisi pada voucher yang belum dipakai, used_at digeser/dikosongkan.
    -- ponytail: pemakaian manual (1 baris, is_used=1 + used_at terisi) masih
    --           mungkin; mysql tidak bisa membedakan dml pemanggil dari trigger.
    --           tutup di lapisan otorisasi kasir bila perlu.
    if not (new.is_used <=> old.is_used) or not (new.used_at <=> old.used_at) then
        if not (old.is_used = 0 and new.is_used = 1 and new.used_at is not null) then
            signal sqlstate '45000'
                set message_text = 'Status dan waktu pemakaian voucher hanya boleh diisi sistem saat voucher dipakai.';
        end if;
    end if;
end$$


-- ----------------------------------------------------------------------------
-- trigger 6 (L-07): order tidak boleh dihapus, gunakan status batal.
-- ----------------------------------------------------------------------------
create trigger trg_before_delete_order
before delete on orders
for each row
begin
    signal sqlstate '45000'
        set message_text = 'Order tidak boleh dihapus. Gunakan status batal untuk membatalkan transaksi.';
end$$

delimiter ;


-- ============================================================================
-- bagian 3: views
-- ============================================================================

-- view 1: detail pesanan. customer_tier = snapshot historis, customer_current_tier = kondisi sekarang
create view vw_order_details as
select
    o.id,
    o.order_code,
    o.user_id,
    u.name as customer_name,
    u.phone as customer_phone,
    u.member_code,
    o.customer_tier_snapshot as customer_tier,
    case
        when u.points >= 300 then 'Platinum'
        when u.points >= 100 then 'Gold'
        else 'Silver'
    end as customer_current_tier,
    o.service_id,
    s.name as service_name,
    s.price_per_kg,
    s.requires_machine,
    o.machine_id,
    m.machine_code,
    m.estimated_finish_at as machine_finish_at,
    o.weight,
    o.subtotal_price,
    o.discount_amount,
    o.total_price,
    o.payment_method,
    o.payment_status,
    o.paid_at,
    o.snap_token,
    o.snap_redirect_url,
    o.status,
    o.queue_wait_minutes,
    o.points_awarded,
    o.image_url,
    o.notes,
    o.voucher_id,
    uv.voucher_code,
    o.created_at,
    o.updated_at
from orders o
join users u on o.user_id = u.id
join services s on o.service_id = s.id
left join machines m on o.machine_id = m.id
left join user_vouchers uv on o.voucher_id = uv.id;


-- view 2: ringkasan kartu dashboard kasir
create view vw_dashboard_summary as
select
    coalesce((
        select sum(total_price) from orders
        where payment_status = 'lunas'
          and status != 'batal'
          and date(paid_at) = curdate()
    ), 0) as today_revenue,
    (select count(*) from orders where status in ('antre', 'proses_cuci', 'sedang_diproses')) as active_orders,
    (select count(*) from orders where status = 'siap_diambil') as ready_orders,
    (select count(*) from machines where status = 'tersedia') as available_machines,
    (select count(*) from machines where status != 'maintenance') as total_operational_machines;


-- view 3: tren omzet 7 hari terakhir
-- catatan: backend wajib mengisi sendiri 7 tanggal (hari tanpa transaksi tidak muncul di sini)
create view vw_daily_revenue_7days as
select
    date_format(paid_at, '%Y-%m-%d') as order_date,
    coalesce(sum(total_price), 0) as daily_revenue,
    count(id) as total_transactions,
    coalesce(sum(weight), 0) as total_weight_kg
from orders
where payment_status = 'lunas'
  and status != 'batal'
  and paid_at >= date_sub(curdate(), interval 6 day)
group by date_format(paid_at, '%Y-%m-%d');


-- ============================================================================
-- bagian 4: data seeder awal
-- password seluruh akun dummy: 'password123'
-- catatan: order seed di bawah berstatus 'selesai' + 'lunas', jadi trigger 2
-- memberi poin saat insert (rina +2 dari 28.000; budi +12 dari 66.000 x2 bonus).
-- saldo awal sudah dikurangi nilai itu supaya hasil akhir tetap 150 / 45.
-- ============================================================================

insert into users (name, email, password, role, phone, member_code, points) values
('Kasir Utama Cleano', 'kasir@cleano.id', '$2b$10$dJtvMjnmVcXCSOIKdco5feBtozeOiKSn1VvdkRk9b.ToTI6hhHnaW', 'kasir', '081200000001', 'STF-0001', 0),
('Rina Marlina', 'rina@gmail.com', '$2b$10$dJtvMjnmVcXCSOIKdco5feBtozeOiKSn1VvdkRk9b.ToTI6hhHnaW', 'pelanggan', '081234567890', 'MBR-0001', 198),
('Budi Santoso', 'budi@gmail.com', '$2b$10$dJtvMjnmVcXCSOIKdco5feBtozeOiKSn1VvdkRk9b.ToTI6hhHnaW', 'pelanggan', '085798765432', 'MBR-0002', 33);


insert into services (name, price_per_kg, wash_duration_minutes, estimated_hours, requires_machine, description) values
('Cuci Komplit Reguler', 7000, 45, 48, 1, 'Cuci bersih, pengeringan, setrika uap, dan parfum standar.'),
('Cuci Komplit Express 6 Jam', 12000, 40, 6, 1, 'Layanan prioritas selesai dalam 6 jam (Bonus 2x Poin).'),
('Cuci Kering Lipat', 5500, 45, 24, 1, 'Cuci bersih dan kering tanpa setrika.'),
('Setrika & Pengeringan Saja', 4500, 0, 24, 0, 'Tanpa mesin cuci, langsung proses pengeringan dan setrika.');


insert into machines (machine_code, status, capacity_kg, estimated_finish_at) values
('MC-01', 'tersedia', 8.00, null),
('MC-02', 'tersedia', 8.00, null),
('MC-03', 'tersedia', 10.00, null),
('MC-04', 'maintenance', 7.00, null);


insert into rewards (title, description, points_required, discount_amount, is_active) values
('Potongan Hemat Rp 5.000', 'Diskon langsung Rp 5.000 untuk semua paket laundry.', 50, 5000, 1),
('Gratis Cuci 2 Kg (Rp 14.000)', 'Potongan Rp 14.000 setara 2 kg Cuci Komplit Reguler.', 100, 14000, 1),
('Diskon Keluarga Rp 25.000', 'Potongan spesial Rp 25.000 untuk transaksi besar.', 200, 25000, 1);


-- trigger 1 memotong poin rina 200 -> 150
insert into user_vouchers (voucher_code, user_id, reward_id, is_used) values
('CLN-VCR-8821', 2, 1, 0);


-- trigger 2 menghitung subtotal/discount/total + snapshot tier + paid_at
insert into orders (order_code, user_id, service_id, machine_id, weight, subtotal_price, discount_amount, total_price, payment_method, payment_status, paid_at, status, queue_wait_minutes, points_awarded, image_url, notes, created_at) values
('CLN-20261113-0001', 2, 1, null, 4.00, 0, 0, 0, 'tunai', 'lunas', date_sub(now(), interval 2 day), 'selesai', 0, 1, '/uploads/sample1.jpg', 'Pisahkan kemeja putih', date_sub(now(), interval 2 day)),
('CLN-20261114-0001', 3, 2, null, 5.50, 0, 0, 0, 'midtrans', 'lunas', date_sub(now(), interval 1 day), 'selesai', 0, 1, '/uploads/sample2.jpg', 'Paket express', date_sub(now(), interval 1 day)),
('CLN-20261115-0001', 2, 1, null, 3.00, 0, 0, 0, 'tunai', 'lunas', now(), 'siap_diambil', 0, 0, '/uploads/sample3.jpg', null, now());
