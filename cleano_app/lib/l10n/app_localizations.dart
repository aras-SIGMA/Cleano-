import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'Cleano — Smart Laundry POS'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In id, this message translates to:
  /// **'Beranda'**
  String get navHome;

  /// No description provided for @navPos.
  ///
  /// In id, this message translates to:
  /// **'Catat Cucian'**
  String get navPos;

  /// No description provided for @navPosShort.
  ///
  /// In id, this message translates to:
  /// **'Catat'**
  String get navPosShort;

  /// No description provided for @navOrders.
  ///
  /// In id, this message translates to:
  /// **'Pesanan'**
  String get navOrders;

  /// No description provided for @navStore.
  ///
  /// In id, this message translates to:
  /// **'Kelola Toko'**
  String get navStore;

  /// No description provided for @navStoreShort.
  ///
  /// In id, this message translates to:
  /// **'Toko'**
  String get navStoreShort;

  /// No description provided for @navAccount.
  ///
  /// In id, this message translates to:
  /// **'Akun'**
  String get navAccount;

  /// No description provided for @navTracking.
  ///
  /// In id, this message translates to:
  /// **'Lacak'**
  String get navTracking;

  /// No description provided for @navRewards.
  ///
  /// In id, this message translates to:
  /// **'Hadiah'**
  String get navRewards;

  /// No description provided for @logout.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi Keluar'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmKasir.
  ///
  /// In id, this message translates to:
  /// **'Apakah Anda yakin ingin keluar dari akun kasir?'**
  String get logoutConfirmKasir;

  /// No description provided for @logoutConfirmPelanggan.
  ///
  /// In id, this message translates to:
  /// **'Apakah Anda yakin ingin keluar dari akun pelanggan?'**
  String get logoutConfirmPelanggan;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In id, this message translates to:
  /// **'Coba Lagi'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get add;

  /// No description provided for @yes.
  ///
  /// In id, this message translates to:
  /// **'Ya'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In id, this message translates to:
  /// **'Tidak'**
  String get no;

  /// No description provided for @understood.
  ///
  /// In id, this message translates to:
  /// **'Mengerti'**
  String get understood;

  /// No description provided for @systemError.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan sistem. Silakan coba lagi.'**
  String get systemError;

  /// No description provided for @pointsUnit.
  ///
  /// In id, this message translates to:
  /// **'Poin'**
  String get pointsUnit;

  /// No description provided for @languageSettingTitle.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Aplikasi'**
  String get languageSettingTitle;

  /// No description provided for @languageSettingSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih bahasa tampilan sistem'**
  String get languageSettingSubtitle;

  /// No description provided for @languageIndonesian.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChanged.
  ///
  /// In id, this message translates to:
  /// **'Bahasa aplikasi diubah ke {language}.'**
  String languageChanged(String language);

  /// No description provided for @splashSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Solusi manajemen laundry modern, cepat, dan terpercaya untuk kasir dan pelanggan.'**
  String get splashSubtitle;

  /// No description provided for @login.
  ///
  /// In id, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In id, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @welcomeBack.
  ///
  /// In id, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Masuk ke akun Anda untuk mengelola cucian dan mengakses promo menarik.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailRequired.
  ///
  /// In id, this message translates to:
  /// **'Email wajib diisi.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In id, this message translates to:
  /// **'Format email tidak valid.'**
  String get emailInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In id, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordRequired.
  ///
  /// In id, this message translates to:
  /// **'Password wajib diisi.'**
  String get passwordRequired;

  /// No description provided for @passwordMin8.
  ///
  /// In id, this message translates to:
  /// **'Password minimal 8 karakter.'**
  String get passwordMin8;

  /// No description provided for @rememberMe.
  ///
  /// In id, this message translates to:
  /// **'Ingat saya'**
  String get rememberMe;

  /// No description provided for @cashier.
  ///
  /// In id, this message translates to:
  /// **'Kasir'**
  String get cashier;

  /// No description provided for @customer.
  ///
  /// In id, this message translates to:
  /// **'Pelanggan'**
  String get customer;

  /// No description provided for @devOnlyNote.
  ///
  /// In id, this message translates to:
  /// **'Hanya selama masa pengembangan'**
  String get devOnlyNote;

  /// No description provided for @noAccountQuestion.
  ///
  /// In id, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccountQuestion;

  /// No description provided for @registerTitle.
  ///
  /// In id, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Buat akun baru untuk mulai mencuci dan kumpulkan poin member.'**
  String get registerSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama Lengkap'**
  String get fullNameLabel;

  /// No description provided for @fullNameRequired.
  ///
  /// In id, this message translates to:
  /// **'Nama lengkap wajib diisi.'**
  String get fullNameRequired;

  /// No description provided for @fullNameMin2.
  ///
  /// In id, this message translates to:
  /// **'Nama minimal 2 karakter.'**
  String get fullNameMin2;

  /// No description provided for @phoneLabel.
  ///
  /// In id, this message translates to:
  /// **'Nomor HP (WhatsApp)'**
  String get phoneLabel;

  /// No description provided for @phoneRequired.
  ///
  /// In id, this message translates to:
  /// **'Nomor HP wajib diisi.'**
  String get phoneRequired;

  /// No description provided for @phoneDigitsRule.
  ///
  /// In id, this message translates to:
  /// **'Nomor HP harus berupa 8-20 digit angka.'**
  String get phoneDigitsRule;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi Password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi password wajib diisi.'**
  String get confirmPasswordRequired;

  /// No description provided for @confirmPasswordMismatch.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi password tidak cocok.'**
  String get confirmPasswordMismatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In id, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @signIn.
  ///
  /// In id, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @registerSuccessTitle.
  ///
  /// In id, this message translates to:
  /// **'Registrasi Berhasil!'**
  String get registerSuccessTitle;

  /// No description provided for @registerSuccessSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Akun Anda telah aktif. Berikut kode member Anda untuk mendapatkan promo & poin:'**
  String get registerSuccessSubtitle;

  /// No description provided for @startUsingCleano.
  ///
  /// In id, this message translates to:
  /// **'Mulai Gunakan Cleano'**
  String get startUsingCleano;

  /// No description provided for @kasirProfileTitle.
  ///
  /// In id, this message translates to:
  /// **'Akun & Pengaturan Kasir'**
  String get kasirProfileTitle;

  /// No description provided for @pelangganProfileTitle.
  ///
  /// In id, this message translates to:
  /// **'Profil & Akun Saya'**
  String get pelangganProfileTitle;

  /// No description provided for @sectionAccountSecurity.
  ///
  /// In id, this message translates to:
  /// **'INFORMASI AKUN & KEAMANAN'**
  String get sectionAccountSecurity;

  /// No description provided for @sectionHardwarePos.
  ///
  /// In id, this message translates to:
  /// **'PERANGKAT & HARDWARE POS'**
  String get sectionHardwarePos;

  /// No description provided for @sectionSopSupport.
  ///
  /// In id, this message translates to:
  /// **'STANDAR OPERASIONAL & BANTUAN'**
  String get sectionSopSupport;

  /// No description provided for @sectionSystemApp.
  ///
  /// In id, this message translates to:
  /// **'SISTEM & APLIKASI'**
  String get sectionSystemApp;

  /// No description provided for @sectionServicePrefs.
  ///
  /// In id, this message translates to:
  /// **'PREFERENSI LAYANAN'**
  String get sectionServicePrefs;

  /// No description provided for @sectionHelpGuide.
  ///
  /// In id, this message translates to:
  /// **'BANTUAN & PANDUAN'**
  String get sectionHelpGuide;

  /// No description provided for @registeredEmail.
  ///
  /// In id, this message translates to:
  /// **'Email Terdaftar'**
  String get registeredEmail;

  /// No description provided for @changePassword.
  ///
  /// In id, this message translates to:
  /// **'Ganti Kata Sandi'**
  String get changePassword;

  /// No description provided for @updatePassword.
  ///
  /// In id, this message translates to:
  /// **'Ubah Kata Sandi'**
  String get updatePassword;

  /// No description provided for @changePasswordSubtitleKasir.
  ///
  /// In id, this message translates to:
  /// **'Perbarui kata sandi akun kasir untuk keamanan berkala'**
  String get changePasswordSubtitleKasir;

  /// No description provided for @changePasswordSubtitlePelanggan.
  ///
  /// In id, this message translates to:
  /// **'Perbarui kata sandi akun pelanggan Anda'**
  String get changePasswordSubtitlePelanggan;

  /// No description provided for @currentPassword.
  ///
  /// In id, this message translates to:
  /// **'Kata Sandi Saat Ini'**
  String get currentPassword;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In id, this message translates to:
  /// **'Masukkan kata sandi lama'**
  String get currentPasswordRequired;

  /// No description provided for @newPasswordMin8Label.
  ///
  /// In id, this message translates to:
  /// **'Kata Sandi Baru (Min. 8 Karakter)'**
  String get newPasswordMin8Label;

  /// No description provided for @passwordMin8Short.
  ///
  /// In id, this message translates to:
  /// **'Kata sandi minimal 8 karakter'**
  String get passwordMin8Short;

  /// No description provided for @passwordMax128.
  ///
  /// In id, this message translates to:
  /// **'Kata sandi maksimal 128 karakter'**
  String get passwordMax128;

  /// No description provided for @confirmNewPassword.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi Kata Sandi Baru'**
  String get confirmNewPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi kata sandi tidak cocok'**
  String get passwordMismatch;

  /// No description provided for @passwordUpdated.
  ///
  /// In id, this message translates to:
  /// **'Kata sandi berhasil diperbarui.'**
  String get passwordUpdated;

  /// No description provided for @passwordUpdateFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memperbarui kata sandi. Coba lagi.'**
  String get passwordUpdateFailed;

  /// No description provided for @savePassword.
  ///
  /// In id, this message translates to:
  /// **'Simpan Kata Sandi'**
  String get savePassword;

  /// No description provided for @kasirCloseShiftLogout.
  ///
  /// In id, this message translates to:
  /// **'Tutup Shift & Keluar Akun'**
  String get kasirCloseShiftLogout;

  /// No description provided for @pelangganLogoutBtn.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari Akun'**
  String get pelangganLogoutBtn;

  /// No description provided for @staffRoleBadge.
  ///
  /// In id, this message translates to:
  /// **'STAFF KASIR'**
  String get staffRoleBadge;

  /// No description provided for @outletCenterName.
  ///
  /// In id, this message translates to:
  /// **'Cleano Outlet 01 — Pusat Sukajadi'**
  String get outletCenterName;

  /// No description provided for @onlineBadge.
  ///
  /// In id, this message translates to:
  /// **'ONLINE'**
  String get onlineBadge;

  /// No description provided for @shiftTitle.
  ///
  /// In id, this message translates to:
  /// **'Shift Kasir'**
  String get shiftTitle;

  /// No description provided for @shiftMorningValue.
  ///
  /// In id, this message translates to:
  /// **'Pagi (08-16)'**
  String get shiftMorningValue;

  /// No description provided for @counterPosTitle.
  ///
  /// In id, this message translates to:
  /// **'Konter POS'**
  String get counterPosTitle;

  /// No description provided for @counterReadyValue.
  ///
  /// In id, this message translates to:
  /// **'Siap Melayani'**
  String get counterReadyValue;

  /// No description provided for @syncTitle.
  ///
  /// In id, this message translates to:
  /// **'Sinkronisasi'**
  String get syncTitle;

  /// No description provided for @syncRealtimeValue.
  ///
  /// In id, this message translates to:
  /// **'Realtime'**
  String get syncRealtimeValue;

  /// No description provided for @whatsappNumber.
  ///
  /// In id, this message translates to:
  /// **'Nomor WhatsApp'**
  String get whatsappNumber;

  /// No description provided for @activeWhatsappNumber.
  ///
  /// In id, this message translates to:
  /// **'Nomor WhatsApp Aktif'**
  String get activeWhatsappNumber;

  /// No description provided for @changePasswordSub.
  ///
  /// In id, this message translates to:
  /// **'Ubah sandi login untuk keamanan akun'**
  String get changePasswordSub;

  /// No description provided for @authPinTitle.
  ///
  /// In id, this message translates to:
  /// **'PIN Otorisasi Kasir'**
  String get authPinTitle;

  /// No description provided for @authPinSubtitle.
  ///
  /// In id, this message translates to:
  /// **'PIN supervisor untuk pembatalan pesanan'**
  String get authPinSubtitle;

  /// No description provided for @authPinInfo.
  ///
  /// In id, this message translates to:
  /// **'PIN otorisasi disetel oleh manajer outlet.'**
  String get authPinInfo;

  /// No description provided for @thermalPrinterTitle.
  ///
  /// In id, this message translates to:
  /// **'Printer Thermal Bluetooth'**
  String get thermalPrinterTitle;

  /// No description provided for @printerConnected.
  ///
  /// In id, this message translates to:
  /// **'Terhubung (ESC/POS 58mm)'**
  String get printerConnected;

  /// No description provided for @printerDisconnected.
  ///
  /// In id, this message translates to:
  /// **'Terputus (Ketuk untuk scan)'**
  String get printerDisconnected;

  /// No description provided for @testPrint.
  ///
  /// In id, this message translates to:
  /// **'Uji Cetak'**
  String get testPrint;

  /// No description provided for @soundNotifTitle.
  ///
  /// In id, this message translates to:
  /// **'Suara Notifikasi Pesanan'**
  String get soundNotifTitle;

  /// No description provided for @soundNotifSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Bunyikan bel saat ada cucian antrean baru'**
  String get soundNotifSubtitle;

  /// No description provided for @posScannerTitle.
  ///
  /// In id, this message translates to:
  /// **'Pemindai Kamera POS'**
  String get posScannerTitle;

  /// No description provided for @posScannerSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kamera belakang aktif (Fokus otomatis)'**
  String get posScannerSubtitle;

  /// No description provided for @posScannerInfo.
  ///
  /// In id, this message translates to:
  /// **'Pemindai barcode kamera siap digunakan di menu Catat Cucian.'**
  String get posScannerInfo;

  /// No description provided for @sopTitle.
  ///
  /// In id, this message translates to:
  /// **'Panduan SOP Kasir & Estafet'**
  String get sopTitle;

  /// No description provided for @sopSubtitle.
  ///
  /// In id, this message translates to:
  /// **'4 langkah standar pelayanan & alur mesin'**
  String get sopSubtitle;

  /// No description provided for @supervisorTitle.
  ///
  /// In id, this message translates to:
  /// **'Kontak Supervisor & Bantuan'**
  String get supervisorTitle;

  /// No description provided for @supervisorSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Nomor penanggung jawab outlet & tim teknis'**
  String get supervisorSubtitle;

  /// No description provided for @termsPrivacyTitle.
  ///
  /// In id, this message translates to:
  /// **'Ketentuan Layanan & Privasi'**
  String get termsPrivacyTitle;

  /// No description provided for @termsPrivacySubtitle.
  ///
  /// In id, this message translates to:
  /// **'Perlindungan data pelanggan & aturan laundry'**
  String get termsPrivacySubtitle;

  /// No description provided for @privacyTermsDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Privasi & Ketentuan'**
  String get privacyTermsDialogTitle;

  /// No description provided for @simReceiptTitle.
  ///
  /// In id, this message translates to:
  /// **'Simulasi Struk POS'**
  String get simReceiptTitle;

  /// No description provided for @sendToPrinter.
  ///
  /// In id, this message translates to:
  /// **'Kirim ke Printer'**
  String get sendToPrinter;

  /// No description provided for @printSentMsg.
  ///
  /// In id, this message translates to:
  /// **'Perintah cetak struk terkirim ke printer Bluetooth (58mm).'**
  String get printSentMsg;

  /// No description provided for @digitalPassTitle.
  ///
  /// In id, this message translates to:
  /// **'Kartu Akses Member Digital'**
  String get digitalPassTitle;

  /// No description provided for @digitalPassSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Gunakan saat drop-off cucian di gerai Cleano'**
  String get digitalPassSubtitle;

  /// No description provided for @tapToShowQr.
  ///
  /// In id, this message translates to:
  /// **'Ketuk untuk Tampilkan QR Code'**
  String get tapToShowQr;

  /// No description provided for @openQrCard.
  ///
  /// In id, this message translates to:
  /// **'Buka Kartu QR'**
  String get openQrCard;

  /// No description provided for @send.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get send;

  /// No description provided for @digitalMemberCardTitle.
  ///
  /// In id, this message translates to:
  /// **'Kartu Member Digital'**
  String get digitalMemberCardTitle;

  /// No description provided for @shareModalTitle.
  ///
  /// In id, this message translates to:
  /// **'Kirim Kartu ke Kurir / Keluarga'**
  String get shareModalTitle;

  /// No description provided for @shareModalSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mudahkan orang lain memesankan cucian atas nama Anda'**
  String get shareModalSubtitle;

  /// No description provided for @shareModalBenefit.
  ///
  /// In id, this message translates to:
  /// **'Kasir hanya butuh kode member Anda untuk menginput pesanan. Poin cucian dan notifikasi proses cuci tetap otomatis masuk ke akun Anda!'**
  String get shareModalBenefit;

  /// No description provided for @shareWhatsappFormat.
  ///
  /// In id, this message translates to:
  /// **'Salin Format Pesan WhatsApp / Chat'**
  String get shareWhatsappFormat;

  /// No description provided for @shareWhatsappSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Template teks lengkap dengan nama, kode member, dan panduan kasir'**
  String get shareWhatsappSubtitle;

  /// No description provided for @shareCodeOnly.
  ///
  /// In id, this message translates to:
  /// **'Salin Kode Member Saja ({code})'**
  String shareCodeOnly(String code);

  /// No description provided for @shareCodeOnlySubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kirimkan kode unik singkat untuk dicatat kasir'**
  String get shareCodeOnlySubtitle;

  /// No description provided for @shareQrScreenshot.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan QR untuk Tangkapan Layar'**
  String get shareQrScreenshot;

  /// No description provided for @shareQrScreenshotSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Buka kartu QR untuk di-screenshot dan dikirim sebagai gambar'**
  String get shareQrScreenshotSubtitle;

  /// No description provided for @shareMessageCopied.
  ///
  /// In id, this message translates to:
  /// **'Format pesan titip cucian berhasil disalin!'**
  String get shareMessageCopied;

  /// No description provided for @memberCodeCopied.
  ///
  /// In id, this message translates to:
  /// **'Kode member {code} disalin!'**
  String memberCodeCopied(String code);

  /// No description provided for @redeemRewardsLink.
  ///
  /// In id, this message translates to:
  /// **'Tukar Hadiah →'**
  String get redeemRewardsLink;

  /// No description provided for @highestTierVip.
  ///
  /// In id, this message translates to:
  /// **'Tier Tertinggi (VIP)'**
  String get highestTierVip;

  /// No description provided for @pointsToGold.
  ///
  /// In id, this message translates to:
  /// **'{pts} poin menuju Gold'**
  String pointsToGold(int pts);

  /// No description provided for @pointsToPlatinum.
  ///
  /// In id, this message translates to:
  /// **'{pts} poin menuju Platinum'**
  String pointsToPlatinum(Object pts);

  /// No description provided for @favOutletTitle.
  ///
  /// In id, this message translates to:
  /// **'Outlet Langganan Utama'**
  String get favOutletTitle;

  /// No description provided for @favOutletSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Cleano Outlet 01 — Pusat Sukajadi (Bandung)'**
  String get favOutletSubtitle;

  /// No description provided for @favOutletInfo.
  ///
  /// In id, this message translates to:
  /// **'Cleano Outlet 01 adalah cabang utama akun Anda.'**
  String get favOutletInfo;

  /// No description provided for @waNotifTitle.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi WhatsApp Cucian'**
  String get waNotifTitle;

  /// No description provided for @waNotifSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Dapatkan pesan WA otomatis saat cucian siap diambil'**
  String get waNotifSubtitle;

  /// No description provided for @csWhatsappTitle.
  ///
  /// In id, this message translates to:
  /// **'Pusat Bantuan WhatsApp'**
  String get csWhatsappTitle;

  /// No description provided for @csWhatsappSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Hubungi Customer Care Cleano (0812-9988-7766)'**
  String get csWhatsappSubtitle;

  /// No description provided for @csPhoneCopied.
  ///
  /// In id, this message translates to:
  /// **'Nomor CS Cleano disalin!'**
  String get csPhoneCopied;

  /// No description provided for @pointsGuideTitle.
  ///
  /// In id, this message translates to:
  /// **'Panduan Poin & Hadiah'**
  String get pointsGuideTitle;

  /// No description provided for @pointsGuideSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Cara kumpulkan poin 2x lipat dan penukaran voucher'**
  String get pointsGuideSubtitle;

  /// No description provided for @privacyTitle.
  ///
  /// In id, this message translates to:
  /// **'Syarat & Kebijakan Privasi'**
  String get privacyTitle;

  /// No description provided for @privacySubtitle.
  ///
  /// In id, this message translates to:
  /// **'Perlindungan data dan ketentuan pencucian'**
  String get privacySubtitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In id, this message translates to:
  /// **'Beranda Kasir'**
  String get dashboardTitle;

  /// No description provided for @downloadRecap.
  ///
  /// In id, this message translates to:
  /// **'Unduh Rekap'**
  String get downloadRecap;

  /// No description provided for @periodToday.
  ///
  /// In id, this message translates to:
  /// **'Hari Ini'**
  String get periodToday;

  /// No description provided for @period7Days.
  ///
  /// In id, this message translates to:
  /// **'7 Hari Terakhir'**
  String get period7Days;

  /// No description provided for @periodThisMonth.
  ///
  /// In id, this message translates to:
  /// **'Bulan Ini'**
  String get periodThisMonth;

  /// No description provided for @metricTodayRevenue.
  ///
  /// In id, this message translates to:
  /// **'Pendapatan Hari Ini'**
  String get metricTodayRevenue;

  /// No description provided for @metricActiveOrders.
  ///
  /// In id, this message translates to:
  /// **'Pesanan Aktif'**
  String get metricActiveOrders;

  /// No description provided for @metricReadyOrders.
  ///
  /// In id, this message translates to:
  /// **'Siap Diambil'**
  String get metricReadyOrders;

  /// No description provided for @metricAvailableMachines.
  ///
  /// In id, this message translates to:
  /// **'Mesin Tersedia'**
  String get metricAvailableMachines;

  /// No description provided for @readyShort.
  ///
  /// In id, this message translates to:
  /// **'Siap'**
  String get readyShort;

  /// No description provided for @activeOrdersTitle.
  ///
  /// In id, this message translates to:
  /// **'Pesanan Aktif'**
  String get activeOrdersTitle;

  /// No description provided for @seeAll.
  ///
  /// In id, this message translates to:
  /// **'Lihat Semua >'**
  String get seeAll;

  /// No description provided for @filterAllCount.
  ///
  /// In id, this message translates to:
  /// **'Semua ({count})'**
  String filterAllCount(int count);

  /// No description provided for @filterWaitingMachine.
  ///
  /// In id, this message translates to:
  /// **'Menunggu Mesin'**
  String get filterWaitingMachine;

  /// No description provided for @filterWashing.
  ///
  /// In id, this message translates to:
  /// **'Sedang Dicuci'**
  String get filterWashing;

  /// No description provided for @noActiveOrdersInCategory.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada cucian aktif pada kategori ini.'**
  String get noActiveOrdersInCategory;

  /// No description provided for @exportModalTitle.
  ///
  /// In id, this message translates to:
  /// **'Ekspor Ringkasan Laporan'**
  String get exportModalTitle;

  /// No description provided for @exportModalSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Unduh rekap data operasional kasir Cleano'**
  String get exportModalSubtitle;

  /// No description provided for @exportCsv.
  ///
  /// In id, this message translates to:
  /// **'Ekspor CSV'**
  String get exportCsv;

  /// No description provided for @exportPdf.
  ///
  /// In id, this message translates to:
  /// **'Ekspor PDF'**
  String get exportPdf;

  /// No description provided for @exportSuccess.
  ///
  /// In id, this message translates to:
  /// **'Laporan format {format} berhasil diekspor.'**
  String exportSuccess(String format);

  /// No description provided for @exportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengekspor laporan: {err}'**
  String exportFailed(String err);

  /// No description provided for @noRevenue7Days.
  ///
  /// In id, this message translates to:
  /// **'Belum ada data pendapatan 7 hari terakhir.'**
  String get noRevenue7Days;

  /// No description provided for @ordersTitle.
  ///
  /// In id, this message translates to:
  /// **'Daftar Pesanan'**
  String get ordersTitle;

  /// No description provided for @searchOrdersHint.
  ///
  /// In id, this message translates to:
  /// **'Cari kode order, nama, atau No. HP...'**
  String get searchOrdersHint;

  /// No description provided for @statusAll.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get statusAll;

  /// No description provided for @statusQueue.
  ///
  /// In id, this message translates to:
  /// **'Antre'**
  String get statusQueue;

  /// No description provided for @statusWashing.
  ///
  /// In id, this message translates to:
  /// **'Proses Cuci'**
  String get statusWashing;

  /// No description provided for @statusProcessing.
  ///
  /// In id, this message translates to:
  /// **'Sedang Diproses'**
  String get statusProcessing;

  /// No description provided for @statusReady.
  ///
  /// In id, this message translates to:
  /// **'Siap Diambil'**
  String get statusReady;

  /// No description provided for @statusDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get statusCancelled;

  /// No description provided for @checkPayment.
  ///
  /// In id, this message translates to:
  /// **'Cek Bayar'**
  String get checkPayment;

  /// No description provided for @markReady.
  ///
  /// In id, this message translates to:
  /// **'Tandai Siap Diambil'**
  String get markReady;

  /// No description provided for @completeOrder.
  ///
  /// In id, this message translates to:
  /// **'Selesaikan Pesanan'**
  String get completeOrder;

  /// No description provided for @cancelOrder.
  ///
  /// In id, this message translates to:
  /// **'Batalkan Pesanan'**
  String get cancelOrder;

  /// No description provided for @paidBadge.
  ///
  /// In id, this message translates to:
  /// **'LUNAS'**
  String get paidBadge;

  /// No description provided for @unpaidBadge.
  ///
  /// In id, this message translates to:
  /// **'BELUM BAYAR'**
  String get unpaidBadge;

  /// No description provided for @posTitle.
  ///
  /// In id, this message translates to:
  /// **'Catat Cucian Baru'**
  String get posTitle;

  /// No description provided for @stepSelectCustomer.
  ///
  /// In id, this message translates to:
  /// **'Pilih Pelanggan'**
  String get stepSelectCustomer;

  /// No description provided for @searchCustomerHint.
  ///
  /// In id, this message translates to:
  /// **'Cari Kode MBR-XXXX atau No. HP...'**
  String get searchCustomerHint;

  /// No description provided for @scanQrMember.
  ///
  /// In id, this message translates to:
  /// **'Scan QR Member Pelanggan'**
  String get scanQrMember;

  /// No description provided for @stepServiceWeight.
  ///
  /// In id, this message translates to:
  /// **'Layanan & Berat Cucian'**
  String get stepServiceWeight;

  /// No description provided for @laundryWeightKg.
  ///
  /// In id, this message translates to:
  /// **'Berat Cucian (kg)'**
  String get laundryWeightKg;

  /// No description provided for @notesOptional.
  ///
  /// In id, this message translates to:
  /// **'Catatan Khusus (Opsional)'**
  String get notesOptional;

  /// No description provided for @stepVoucher.
  ///
  /// In id, this message translates to:
  /// **'Voucher Diskon'**
  String get stepVoucher;

  /// No description provided for @stepPayment.
  ///
  /// In id, this message translates to:
  /// **'Metode Pembayaran'**
  String get stepPayment;

  /// No description provided for @processTransaction.
  ///
  /// In id, this message translates to:
  /// **'Proses Transaksi'**
  String get processTransaction;

  /// No description provided for @orderSavedSuccess.
  ///
  /// In id, this message translates to:
  /// **'Pesanan Berhasil Disimpan!'**
  String get orderSavedSuccess;

  /// No description provided for @newLaundryBtn.
  ///
  /// In id, this message translates to:
  /// **'Cucian Baru'**
  String get newLaundryBtn;

  /// No description provided for @changeCustomer.
  ///
  /// In id, this message translates to:
  /// **'Ganti Pelanggan'**
  String get changeCustomer;

  /// No description provided for @selectLaundryService.
  ///
  /// In id, this message translates to:
  /// **'Pilih Jenis Layanan Laundry'**
  String get selectLaundryService;

  /// No description provided for @takeClothingPhoto.
  ///
  /// In id, this message translates to:
  /// **'Ambil Foto Bukti Pakaian'**
  String get takeClothingPhoto;

  /// No description provided for @typeVoucherHint.
  ///
  /// In id, this message translates to:
  /// **'Ketik kode voucher...'**
  String get typeVoucherHint;

  /// No description provided for @applyVoucher.
  ///
  /// In id, this message translates to:
  /// **'Terapkan'**
  String get applyVoucher;

  /// No description provided for @manageStoreTitle.
  ///
  /// In id, this message translates to:
  /// **'Kelola Toko'**
  String get manageStoreTitle;

  /// No description provided for @refreshData.
  ///
  /// In id, this message translates to:
  /// **'Segarkan Data'**
  String get refreshData;

  /// No description provided for @newServiceBtn.
  ///
  /// In id, this message translates to:
  /// **'Layanan Baru'**
  String get newServiceBtn;

  /// No description provided for @newMachineBtn.
  ///
  /// In id, this message translates to:
  /// **'Unit Mesin Baru'**
  String get newMachineBtn;

  /// No description provided for @newRewardBtn.
  ///
  /// In id, this message translates to:
  /// **'Kupon Baru'**
  String get newRewardBtn;

  /// No description provided for @addBtn.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get addBtn;

  /// No description provided for @helloGreeting.
  ///
  /// In id, this message translates to:
  /// **'Halo, {name} 👋'**
  String helloGreeting(String name);

  /// No description provided for @pointsBalanceLabel.
  ///
  /// In id, this message translates to:
  /// **'Saldo Poin'**
  String get pointsBalanceLabel;

  /// No description provided for @weeklyActivityTitle.
  ///
  /// In id, this message translates to:
  /// **'Aktivitas 7 Hari Terakhir'**
  String get weeklyActivityTitle;

  /// No description provided for @fromRecentHistory.
  ///
  /// In id, this message translates to:
  /// **'dari riwayat terakhir'**
  String get fromRecentHistory;

  /// No description provided for @laundryCountLabel.
  ///
  /// In id, this message translates to:
  /// **'Cucian'**
  String get laundryCountLabel;

  /// No description provided for @totalWeightLabel.
  ///
  /// In id, this message translates to:
  /// **'Total Berat'**
  String get totalWeightLabel;

  /// No description provided for @pointsEarnedLabel.
  ///
  /// In id, this message translates to:
  /// **'Poin Didapat'**
  String get pointsEarnedLabel;

  /// No description provided for @activeLaundryTab.
  ///
  /// In id, this message translates to:
  /// **'Cucian Aktif ({count})'**
  String activeLaundryTab(int count);

  /// No description provided for @completedHistoryTab.
  ///
  /// In id, this message translates to:
  /// **'Riwayat Selesai ({count})'**
  String completedHistoryTab(int count);

  /// No description provided for @noActiveLaundry.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada cucian yang sedang diproses.'**
  String get noActiveLaundry;

  /// No description provided for @noCompletedHistory.
  ///
  /// In id, this message translates to:
  /// **'Belum ada riwayat pesanan yang selesai.'**
  String get noCompletedHistory;

  /// No description provided for @dropoffPhotoTitle.
  ///
  /// In id, this message translates to:
  /// **'Foto Bukti Drop-Off Pakaian'**
  String get dropoffPhotoTitle;

  /// No description provided for @serviceLabel.
  ///
  /// In id, this message translates to:
  /// **'Layanan'**
  String get serviceLabel;

  /// No description provided for @weightLabel.
  ///
  /// In id, this message translates to:
  /// **'Berat Cucian'**
  String get weightLabel;

  /// No description provided for @totalPaymentLabel.
  ///
  /// In id, this message translates to:
  /// **'Total Pembayaran'**
  String get totalPaymentLabel;

  /// No description provided for @methodStatusLabel.
  ///
  /// In id, this message translates to:
  /// **'Metode / Status'**
  String get methodStatusLabel;

  /// No description provided for @rewardsTitle.
  ///
  /// In id, this message translates to:
  /// **'Loyalti & Hadiah'**
  String get rewardsTitle;

  /// No description provided for @rewardsSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kumpulkan Poin & Dapatkan Promo Menarik'**
  String get rewardsSubtitle;

  /// No description provided for @myPointsBalance.
  ///
  /// In id, this message translates to:
  /// **'SALDO POIN SAYA'**
  String get myPointsBalance;

  /// No description provided for @highestTierLabel.
  ///
  /// In id, this message translates to:
  /// **'Tingkat Keanggotaan Tertinggi'**
  String get highestTierLabel;

  /// No description provided for @bonus2xTitle.
  ///
  /// In id, this message translates to:
  /// **'Bonus 2x Poin Loyalti ⚡'**
  String get bonus2xTitle;

  /// No description provided for @bonus2xSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Otomatis dapatkan 2x poin untuk cucian berat ≥ 5 kg atau layanan Express!'**
  String get bonus2xSubtitle;

  /// No description provided for @catalogTab.
  ///
  /// In id, this message translates to:
  /// **'Katalog Hadiah ({count})'**
  String catalogTab(int count);

  /// No description provided for @myVouchersTab.
  ///
  /// In id, this message translates to:
  /// **'Voucher Saya ({count})'**
  String myVouchersTab(int count);

  /// No description provided for @redeemPointsBtn.
  ///
  /// In id, this message translates to:
  /// **'Tukar Poin'**
  String get redeemPointsBtn;

  /// No description provided for @insufficientPointsBtn.
  ///
  /// In id, this message translates to:
  /// **'Poin Kurang'**
  String get insufficientPointsBtn;

  /// No description provided for @oneTimeUseBadge.
  ///
  /// In id, this message translates to:
  /// **'1x Pakai'**
  String get oneTimeUseBadge;

  /// No description provided for @copyCodeBtn.
  ///
  /// In id, this message translates to:
  /// **'Salin Kode'**
  String get copyCodeBtn;

  /// No description provided for @usedBadge.
  ///
  /// In id, this message translates to:
  /// **'Sudah Terpakai'**
  String get usedBadge;

  /// No description provided for @changeProfilePhoto.
  ///
  /// In id, this message translates to:
  /// **'Ubah Foto Profil'**
  String get changeProfilePhoto;

  /// No description provided for @takeFromCamera.
  ///
  /// In id, this message translates to:
  /// **'Ambil dari Kamera'**
  String get takeFromCamera;

  /// No description provided for @chooseFromGallery.
  ///
  /// In id, this message translates to:
  /// **'Pilih dari Galeri'**
  String get chooseFromGallery;

  /// No description provided for @avatarUpdated.
  ///
  /// In id, this message translates to:
  /// **'Foto profil berhasil diperbarui.'**
  String get avatarUpdated;

  /// No description provided for @avatarUpdateFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memperbarui foto profil: {err}'**
  String avatarUpdateFailed(String err);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
