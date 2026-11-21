# Dokumentasi Cleano

## Mulai dari sini

| Dokumen | Untuk apa |
|---|---|
| [`PANDUAN-PENGERJAAN.md`](PANDUAN-PENGERJAAN.md) | aturan kerja, konvensi backend & Flutter, Definition of Done |
| [`DESIGN.md`](DESIGN.md) | panduan UI/UX, sistem warna Vibrant Azure, dan spesifikasi komponen |
| [`JADWAL-DEVELOPMENT.md`](JADWAL-DEVELOPMENT.md) | jadwal 2 hari development + 1 hari testing, per blok jam |
| [`TASK-backend.md`](TASK-backend.md) | 10 paket task backend, dengan status |
| [`TASK-mobile.md`](TASK-mobile.md) | 11 paket task Flutter, dengan status |

## Dokumen produk (PRD)

Di `docs/Context Production/`:

| # | Dokumen | Lapisan |
|---|---|---|
| PRD-01 | Arsitektur Sistem & Lapisan Database | DB |
| PRD-02 | Lapisan Backend REST API | API |
| PRD-03 | Frontend — Portal Kasir | Flutter |
| PRD-04 | Frontend — Portal Pelanggan | Flutter |
| PRD-05 | QA, Keamanan & Deployment | lintas |

## Audit database

| Dokumen | Isi |
|---|---|
| `AUDIT-database_schema-perbaikan.md` | audit awal, temuan |
| `AUDIT-database_schema-v1.1-verifikasi.md` | perbaikan + verifikasi |
| `AUDIT-database_schema-v1.2-verifikasi.md` | verifikasi lanjutan |
| `AUDIT-database_schema-v1.3-verifikasi.md` | immutability guard |
| `AUDIT-database_schema-v1.4-verifikasi.md` | final: 43 kasus serangan, 0 lubang |

## Kode

| Folder | Isi |
|---|---|
| `cleano-backend/` | Express API — lihat `cleano-backend/README.md` |
| `cleano_app/` | Flutter — lihat `cleano_app/README.md` |
| `database_schema.sql` | skema v1.4 final (6 tabel, 3 view, 6 trigger) |

## Alur baca yang disarankan

1. `PANDUAN-PENGERJAAN.md` — aturan main
2. `JADWAL-DEVELOPMENT.md` — apa yang dikerjakan kapan
3. `TASK-backend.md` / `TASK-mobile.md` — task per paket
4. PRD terkait saat mengerjakan paket tertentu