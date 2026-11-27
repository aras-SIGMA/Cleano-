// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Cleano — Smart Laundry POS';

  @override
  String get navHome => 'Beranda';

  @override
  String get navPos => 'Catat Cucian';

  @override
  String get navPosShort => 'Catat';

  @override
  String get navOrders => 'Pesanan';

  @override
  String get navStore => 'Kelola Toko';

  @override
  String get navStoreShort => 'Toko';

  @override
  String get navAccount => 'Akun';

  @override
  String get navTracking => 'Lacak';

  @override
  String get navRewards => 'Hadiah';

  @override
  String get logout => 'Keluar';

  @override
  String get logoutConfirmTitle => 'Konfirmasi Keluar';

  @override
  String get logoutConfirmKasir =>
      'Apakah Anda yakin ingin keluar dari akun kasir?';

  @override
  String get logoutConfirmPelanggan =>
      'Apakah Anda yakin ingin keluar dari akun pelanggan?';

  @override
  String get cancel => 'Batal';

  @override
  String get close => 'Tutup';

  @override
  String get retry => 'Coba Lagi';

  @override
  String get delete => 'Hapus';

  @override
  String get add => 'Tambah';

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get understood => 'Mengerti';

  @override
  String get systemError => 'Terjadi kesalahan sistem. Silakan coba lagi.';

  @override
  String get pointsUnit => 'Poin';

  @override
  String get languageSettingTitle => 'Bahasa Aplikasi';

  @override
  String get languageSettingSubtitle => 'Pilih bahasa tampilan sistem';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String languageChanged(String language) {
    return 'Bahasa aplikasi diubah ke $language.';
  }

  @override
  String get splashSubtitle =>
      'Solusi manajemen laundry modern, cepat, dan terpercaya untuk kasir dan pelanggan.';

  @override
  String get login => 'Login';

  @override
  String get signUp => 'Sign up';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginSubtitle =>
      'Masuk ke akun Anda untuk mengelola cucian dan mengakses promo menarik.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailRequired => 'Email wajib diisi.';

  @override
  String get emailInvalid => 'Format email tidak valid.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Password wajib diisi.';

  @override
  String get passwordMin8 => 'Password minimal 8 karakter.';

  @override
  String get rememberMe => 'Ingat saya';

  @override
  String get cashier => 'Kasir';

  @override
  String get customer => 'Pelanggan';

  @override
  String get devOnlyNote => 'Hanya selama masa pengembangan';

  @override
  String get noAccountQuestion => 'Don\'t have an account? ';

  @override
  String get registerTitle => 'Register';

  @override
  String get registerSubtitle =>
      'Buat akun baru untuk mulai mencuci dan kumpulkan poin member.';

  @override
  String get fullNameLabel => 'Nama Lengkap';

  @override
  String get fullNameRequired => 'Nama lengkap wajib diisi.';

  @override
  String get fullNameMin2 => 'Nama minimal 2 karakter.';

  @override
  String get phoneLabel => 'Nomor HP (WhatsApp)';

  @override
  String get phoneRequired => 'Nomor HP wajib diisi.';

  @override
  String get phoneDigitsRule => 'Nomor HP harus berupa 8-20 digit angka.';

  @override
  String get confirmPasswordLabel => 'Konfirmasi Password';

  @override
  String get confirmPasswordRequired => 'Konfirmasi password wajib diisi.';

  @override
  String get confirmPasswordMismatch => 'Konfirmasi password tidak cocok.';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get signIn => 'Sign in';

  @override
  String get registerSuccessTitle => 'Registrasi Berhasil!';

  @override
  String get registerSuccessSubtitle =>
      'Akun Anda telah aktif. Berikut kode member Anda untuk mendapatkan promo & poin:';

  @override
  String get startUsingCleano => 'Mulai Gunakan Cleano';

  @override
  String get kasirProfileTitle => 'Akun & Pengaturan Kasir';

  @override
  String get pelangganProfileTitle => 'Profil & Akun Saya';

  @override
  String get sectionAccountSecurity => 'INFORMASI AKUN & KEAMANAN';

  @override
  String get sectionHardwarePos => 'PERANGKAT & HARDWARE POS';

  @override
  String get sectionSopSupport => 'STANDAR OPERASIONAL & BANTUAN';

  @override
  String get sectionSystemApp => 'SISTEM & APLIKASI';

  @override
  String get sectionServicePrefs => 'PREFERENSI LAYANAN';

  @override
  String get sectionHelpGuide => 'BANTUAN & PANDUAN';

  @override
  String get registeredEmail => 'Email Terdaftar';

  @override
  String get changePassword => 'Ganti Kata Sandi';

  @override
  String get updatePassword => 'Ubah Kata Sandi';

  @override
  String get changePasswordSubtitleKasir =>
      'Perbarui kata sandi akun kasir untuk keamanan berkala';

  @override
  String get changePasswordSubtitlePelanggan =>
      'Perbarui kata sandi akun pelanggan Anda';

  @override
  String get currentPassword => 'Kata Sandi Saat Ini';

  @override
  String get currentPasswordRequired => 'Masukkan kata sandi lama';

  @override
  String get newPasswordMin8Label => 'Kata Sandi Baru (Min. 8 Karakter)';

  @override
  String get passwordMin8Short => 'Kata sandi minimal 8 karakter';

  @override
  String get passwordMax128 => 'Kata sandi maksimal 128 karakter';

  @override
  String get confirmNewPassword => 'Konfirmasi Kata Sandi Baru';

  @override
  String get passwordMismatch => 'Konfirmasi kata sandi tidak cocok';

  @override
  String get passwordUpdated => 'Kata sandi berhasil diperbarui.';

  @override
  String get passwordUpdateFailed => 'Gagal memperbarui kata sandi. Coba lagi.';

  @override
  String get savePassword => 'Simpan Kata Sandi';

  @override
  String get kasirCloseShiftLogout => 'Tutup Shift & Keluar Akun';

  @override
  String get pelangganLogoutBtn => 'Keluar dari Akun';

  @override
  String get staffRoleBadge => 'STAFF KASIR';

  @override
  String get outletCenterName => 'Cleano Outlet 01 — Pusat Sukajadi';

  @override
  String get onlineBadge => 'ONLINE';

  @override
  String get shiftTitle => 'Shift Kasir';

  @override
  String get shiftMorningValue => 'Pagi (08-16)';

  @override
  String get counterPosTitle => 'Konter POS';

  @override
  String get counterReadyValue => 'Siap Melayani';

  @override
  String get syncTitle => 'Sinkronisasi';

  @override
  String get syncRealtimeValue => 'Realtime';

  @override
  String get whatsappNumber => 'Nomor WhatsApp';

  @override
  String get activeWhatsappNumber => 'Nomor WhatsApp Aktif';

  @override
  String get changePasswordSub => 'Ubah sandi login untuk keamanan akun';

  @override
  String get authPinTitle => 'PIN Otorisasi Kasir';

  @override
  String get authPinSubtitle => 'PIN supervisor untuk pembatalan pesanan';

  @override
  String get authPinInfo => 'PIN otorisasi disetel oleh manajer outlet.';

  @override
  String get thermalPrinterTitle => 'Printer Thermal Bluetooth';

  @override
  String get printerConnected => 'Terhubung (ESC/POS 58mm)';

  @override
  String get printerDisconnected => 'Terputus (Ketuk untuk scan)';

  @override
  String get testPrint => 'Uji Cetak';

  @override
  String get soundNotifTitle => 'Suara Notifikasi Pesanan';

  @override
  String get soundNotifSubtitle => 'Bunyikan bel saat ada cucian antrean baru';

  @override
  String get posScannerTitle => 'Pemindai Kamera POS';

  @override
  String get posScannerSubtitle => 'Kamera belakang aktif (Fokus otomatis)';

  @override
  String get posScannerInfo =>
      'Pemindai barcode kamera siap digunakan di menu Catat Cucian.';

  @override
  String get sopTitle => 'Panduan SOP Kasir & Estafet';

  @override
  String get sopSubtitle => '4 langkah standar pelayanan & alur mesin';

  @override
  String get supervisorTitle => 'Kontak Supervisor & Bantuan';

  @override
  String get supervisorSubtitle => 'Nomor penanggung jawab outlet & tim teknis';

  @override
  String get termsPrivacyTitle => 'Ketentuan Layanan & Privasi';

  @override
  String get termsPrivacySubtitle =>
      'Perlindungan data pelanggan & aturan laundry';

  @override
  String get privacyTermsDialogTitle => 'Privasi & Ketentuan';

  @override
  String get simReceiptTitle => 'Simulasi Struk POS';

  @override
  String get sendToPrinter => 'Kirim ke Printer';

  @override
  String get printSentMsg =>
      'Perintah cetak struk terkirim ke printer Bluetooth (58mm).';

  @override
  String get digitalPassTitle => 'Kartu Akses Member Digital';

  @override
  String get digitalPassSubtitle =>
      'Gunakan saat drop-off cucian di gerai Cleano';

  @override
  String get tapToShowQr => 'Ketuk untuk Tampilkan QR Code';

  @override
  String get openQrCard => 'Buka Kartu QR';

  @override
  String get send => 'Kirim';

  @override
  String get digitalMemberCardTitle => 'Kartu Member Digital';

  @override
  String get shareModalTitle => 'Kirim Kartu ke Kurir / Keluarga';

  @override
  String get shareModalSubtitle =>
      'Mudahkan orang lain memesankan cucian atas nama Anda';

  @override
  String get shareModalBenefit =>
      'Kasir hanya butuh kode member Anda untuk menginput pesanan. Poin cucian dan notifikasi proses cuci tetap otomatis masuk ke akun Anda!';

  @override
  String get shareWhatsappFormat => 'Salin Format Pesan WhatsApp / Chat';

  @override
  String get shareWhatsappSubtitle =>
      'Template teks lengkap dengan nama, kode member, dan panduan kasir';

  @override
  String shareCodeOnly(String code) {
    return 'Salin Kode Member Saja ($code)';
  }

  @override
  String get shareCodeOnlySubtitle =>
      'Kirimkan kode unik singkat untuk dicatat kasir';

  @override
  String get shareQrScreenshot => 'Tampilkan QR untuk Tangkapan Layar';

  @override
  String get shareQrScreenshotSubtitle =>
      'Buka kartu QR untuk di-screenshot dan dikirim sebagai gambar';

  @override
  String get shareMessageCopied =>
      'Format pesan titip cucian berhasil disalin!';

  @override
  String memberCodeCopied(String code) {
    return 'Kode member $code disalin!';
  }

  @override
  String get redeemRewardsLink => 'Tukar Hadiah →';

  @override
  String get highestTierVip => 'Tier Tertinggi (VIP)';

  @override
  String pointsToGold(int pts) {
    return '$pts poin menuju Gold';
  }

  @override
  String pointsToPlatinum(int pts) {
    return '$pts poin menuju Platinum';
  }

  @override
  String get favOutletTitle => 'Outlet Langganan Utama';

  @override
  String get favOutletSubtitle => 'Cleano Outlet 01 — Pusat Sukajadi (Bandung)';

  @override
  String get favOutletInfo => 'Cleano Outlet 01 adalah cabang utama akun Anda.';

  @override
  String get waNotifTitle => 'Notifikasi WhatsApp Cucian';

  @override
  String get waNotifSubtitle =>
      'Dapatkan pesan WA otomatis saat cucian siap diambil';

  @override
  String get csWhatsappTitle => 'Pusat Bantuan WhatsApp';

  @override
  String get csWhatsappSubtitle =>
      'Hubungi Customer Care Cleano (0812-9988-7766)';

  @override
  String get csPhoneCopied => 'Nomor CS Cleano disalin!';

  @override
  String get pointsGuideTitle => 'Panduan Poin & Hadiah';

  @override
  String get pointsGuideSubtitle =>
      'Cara kumpulkan poin 2x lipat dan penukaran voucher';

  @override
  String get privacyTitle => 'Syarat & Kebijakan Privasi';

  @override
  String get privacySubtitle => 'Perlindungan data dan ketentuan pencucian';

  @override
  String get dashboardTitle => 'Beranda Kasir';

  @override
  String get downloadRecap => 'Unduh Rekap';

  @override
  String get periodToday => 'Hari Ini';

  @override
  String get period7Days => '7 Hari Terakhir';

  @override
  String get periodThisMonth => 'Bulan Ini';

  @override
  String get metricTodayRevenue => 'Pendapatan Hari Ini';

  @override
  String get metricActiveOrders => 'Pesanan Aktif';

  @override
  String get metricReadyOrders => 'Siap Diambil';

  @override
  String get metricAvailableMachines => 'Mesin Tersedia';

  @override
  String get readyShort => 'Siap';

  @override
  String get activeOrdersTitle => 'Pesanan Aktif';

  @override
  String get seeAll => 'Lihat Semua >';

  @override
  String filterAllCount(int count) {
    return 'Semua ($count)';
  }

  @override
  String get filterWaitingMachine => 'Menunggu Mesin';

  @override
  String get filterWashing => 'Sedang Dicuci';

  @override
  String get noActiveOrdersInCategory =>
      'Tidak ada cucian aktif pada kategori ini.';

  @override
  String get exportModalTitle => 'Ekspor Ringkasan Laporan';

  @override
  String get exportModalSubtitle => 'Unduh rekap data operasional kasir Cleano';

  @override
  String get exportCsv => 'Ekspor CSV';

  @override
  String get exportPdf => 'Ekspor PDF';

  @override
  String exportSuccess(String format) {
    return 'Laporan format $format berhasil diekspor.';
  }

  @override
  String exportFailed(String err) {
    return 'Gagal mengekspor laporan: $err';
  }

  @override
  String get noRevenue7Days => 'Belum ada data pendapatan 7 hari terakhir.';

  @override
  String get ordersTitle => 'Daftar Pesanan';

  @override
  String get searchOrdersHint => 'Cari kode order, nama, atau No. HP...';

  @override
  String get statusAll => 'Semua';

  @override
  String get statusQueue => 'Antre';

  @override
  String get statusWashing => 'Proses Cuci';

  @override
  String get statusProcessing => 'Sedang Diproses';

  @override
  String get statusReady => 'Siap Diambil';

  @override
  String get statusDone => 'Selesai';

  @override
  String get statusCancelled => 'Batal';

  @override
  String get checkPayment => 'Cek Bayar';

  @override
  String get markReady => 'Tandai Siap Diambil';

  @override
  String get completeOrder => 'Selesaikan Pesanan';

  @override
  String get cancelOrder => 'Batalkan Pesanan';

  @override
  String get paidBadge => 'LUNAS';

  @override
  String get unpaidBadge => 'BELUM BAYAR';

  @override
  String get posTitle => 'Catat Cucian Baru';

  @override
  String get stepSelectCustomer => 'Pilih Pelanggan';

  @override
  String get searchCustomerHint => 'Cari Kode MBR-XXXX atau No. HP...';

  @override
  String get scanQrMember => 'Scan QR Member Pelanggan';

  @override
  String get stepServiceWeight => 'Layanan & Berat Cucian';

  @override
  String get laundryWeightKg => 'Berat Cucian (kg)';

  @override
  String get notesOptional => 'Catatan Khusus (Opsional)';

  @override
  String get stepVoucher => 'Voucher Diskon';

  @override
  String get stepPayment => 'Metode Pembayaran';

  @override
  String get processTransaction => 'Proses Transaksi';

  @override
  String get orderSavedSuccess => 'Pesanan Berhasil Disimpan!';

  @override
  String get newLaundryBtn => 'Cucian Baru';

  @override
  String get changeCustomer => 'Ganti Pelanggan';

  @override
  String get selectLaundryService => 'Pilih Jenis Layanan Laundry';

  @override
  String get takeClothingPhoto => 'Ambil Foto Bukti Pakaian';

  @override
  String get typeVoucherHint => 'Ketik kode voucher...';

  @override
  String get applyVoucher => 'Terapkan';

  @override
  String get manageStoreTitle => 'Kelola Toko';

  @override
  String get refreshData => 'Segarkan Data';

  @override
  String get newServiceBtn => 'Layanan Baru';

  @override
  String get newMachineBtn => 'Unit Mesin Baru';

  @override
  String get newRewardBtn => 'Kupon Baru';

  @override
  String get addBtn => 'Tambah';

  @override
  String helloGreeting(String name) {
    return 'Halo, $name 👋';
  }

  @override
  String get pointsBalanceLabel => 'Saldo Poin';

  @override
  String get weeklyActivityTitle => 'Aktivitas 7 Hari Terakhir';

  @override
  String get fromRecentHistory => 'dari riwayat terakhir';

  @override
  String get laundryCountLabel => 'Cucian';

  @override
  String get totalWeightLabel => 'Total Berat';

  @override
  String get pointsEarnedLabel => 'Poin Didapat';

  @override
  String activeLaundryTab(int count) {
    return 'Cucian Aktif ($count)';
  }

  @override
  String completedHistoryTab(int count) {
    return 'Riwayat Selesai ($count)';
  }

  @override
  String get noActiveLaundry => 'Tidak ada cucian yang sedang diproses.';

  @override
  String get noCompletedHistory => 'Belum ada riwayat pesanan yang selesai.';

  @override
  String get dropoffPhotoTitle => 'Foto Bukti Drop-Off Pakaian';

  @override
  String get serviceLabel => 'Layanan';

  @override
  String get weightLabel => 'Berat Cucian';

  @override
  String get totalPaymentLabel => 'Total Pembayaran';

  @override
  String get methodStatusLabel => 'Metode / Status';

  @override
  String get rewardsTitle => 'Loyalti & Hadiah';

  @override
  String get rewardsSubtitle => 'Kumpulkan Poin & Dapatkan Promo Menarik';

  @override
  String get myPointsBalance => 'SALDO POIN SAYA';

  @override
  String get highestTierLabel => 'Tingkat Keanggotaan Tertinggi';

  @override
  String get bonus2xTitle => 'Bonus 2x Poin Loyalti ⚡';

  @override
  String get bonus2xSubtitle =>
      'Otomatis dapatkan 2x poin untuk cucian berat ≥ 5 kg atau layanan Express!';

  @override
  String catalogTab(int count) {
    return 'Katalog Hadiah ($count)';
  }

  @override
  String myVouchersTab(int count) {
    return 'Voucher Saya ($count)';
  }

  @override
  String get redeemPointsBtn => 'Tukar Poin';

  @override
  String get insufficientPointsBtn => 'Poin Kurang';

  @override
  String get oneTimeUseBadge => '1x Pakai';

  @override
  String get copyCodeBtn => 'Salin Kode';

  @override
  String get usedBadge => 'Sudah Terpakai';

  @override
  String get changeProfilePhoto => 'Ubah Foto Profil';

  @override
  String get takeFromCamera => 'Ambil dari Kamera';

  @override
  String get chooseFromGallery => 'Pilih dari Galeri';

  @override
  String get avatarUpdated => 'Foto profil berhasil diperbarui.';

  @override
  String avatarUpdateFailed(String err) {
    return 'Gagal memperbarui foto profil: $err';
  }
}
