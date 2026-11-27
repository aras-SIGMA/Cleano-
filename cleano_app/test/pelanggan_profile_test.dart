import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/screens/pelanggan/pelanggan_profile_screen.dart';
import 'package:cleano_app/widgets/profile_avatar_picker.dart';

void main() {
  const dummyCustomer = UserModel(
    id: 2,
    name: 'Rina Marlina',
    email: 'rina.marlina@cleano.id',
    phone: '081234567891',
    role: 'pelanggan',
    memberCode: 'MBR-0001',
    points: 150,
    tier: 'Gold',
  );

  Widget createWidget({
    UserModel? user,
    VoidCallback? onLogout,
    VoidCallback? onNavigateToRewards,
  }) {
    return MaterialApp(
      home: PelangganProfileScreen(
        user: user ?? dummyCustomer,
        onLogout: onLogout,
        onNavigateToRewards: onNavigateToRewards,
      ),
    );
  }

  group('PelangganProfileScreen Tests', () {
    testWidgets('Menampilkan profil pelanggan, badge tier, poin loyalti, dan kartu digital', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Judul AppBar
      expect(find.text('Profil & Akun Saya'), findsOneWidget);

      // Hero Card Identitas Pelanggan
      expect(find.text('Rina Marlina'), findsOneWidget);
      expect(find.text('GOLD MEMBER'), findsOneWidget);
      expect(find.text('150 Poin Loyalti'), findsOneWidget);

      // Bagian Kartu Akses Member Digital
      expect(find.text('Kartu Akses Member Digital'), findsOneWidget);
      expect(find.text('Buka Kartu QR'), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);

      // Seksi Informasi Akun & Keamanan
      expect(find.text('INFORMASI AKUN & KEAMANAN'), findsOneWidget);
      expect(find.text('rina.marlina@cleano.id'), findsOneWidget);
      expect(find.text('0812-3456-7890'), findsNothing); // format data asli
      expect(find.text('081234567891'), findsOneWidget);
      expect(find.text('Ubah Kata Sandi'), findsOneWidget);

      // Preferensi Layanan & Bantuan
      expect(find.text('PREFERENSI LAYANAN'), findsOneWidget);
      expect(find.text('Notifikasi WhatsApp Cucian'), findsOneWidget);
      expect(find.text('BANTUAN & PANDUAN'), findsOneWidget);
      expect(find.text('Pusat Bantuan WhatsApp'), findsOneWidget);

      // Tombol Logout
      expect(find.text('Keluar dari Akun'), findsOneWidget);
    });

    testWidgets('Membuka modal kartu member digital penuh dengan QR code berprivasi tinggi (tanpa email)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Ketuk tombol Buka Kartu QR
      await tester.tap(find.text('Buka Kartu QR'));
      await tester.pumpAndSettle();

      // Verifikasi bottom sheet terbuka
      expect(find.text('Kartu Member Digital'), findsOneWidget);
      expect(find.text('CLEANO PASS'), findsOneWidget);
      expect(find.text('MBR-0001'), findsWidgets);

      // Verifikasi QrImageView terpasang dengan semantics label benar
      final qrFinder = find.byType(QrImageView);
      expect(qrFinder, findsOneWidget);
      final qrWidget = tester.widget<QrImageView>(qrFinder);
      expect(qrWidget.semanticsLabel, 'QR Code MBR-0001');

      // Verifikasi privasi: nomor WA tersensor (0812-****-7891)
      expect(find.text('No. WA: 0812-****-7891'), findsOneWidget);

      // Pastikan email pelanggan tidak muncul pada modal kartu member QR.
      final sheetFinder = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheetFinder, matching: find.text('rina.marlina@cleano.id')),
        findsNothing,
      );
    });

    testWidgets('Membuka modal opsi berbagi kartu member ke kurir/keluarga dan menyalin format chat', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Ketuk tombol Kirim
      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();

      // Verifikasi modal opsi berbagi muncul
      expect(find.text('Kirim Kartu ke Kurir / Keluarga'), findsOneWidget);
      expect(find.text('Salin Format Pesan WhatsApp / Chat'), findsOneWidget);
      expect(find.text('Salin Kode Member Saja (MBR-0001)'), findsOneWidget);
      expect(find.text('Tampilkan QR untuk Tangkapan Layar'), findsOneWidget);

      // Ketuk Salin Format Pesan WhatsApp / Chat
      await tester.tap(find.text('Salin Format Pesan WhatsApp / Chat'));
      await tester.pumpAndSettle();

      // Modal tertutup dan SnackBar muncul
      expect(find.text('Kirim Kartu ke Kurir / Keluarga'), findsNothing);
      expect(find.text('Format pesan titip cucian berhasil disalin!'), findsOneWidget);
    });

    testWidgets('Membuka bottom sheet ubah kata sandi', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ubah Kata Sandi'));
      await tester.pumpAndSettle();

      expect(find.text('Kata Sandi Saat Ini'), findsOneWidget);
      expect(find.text('Kata Sandi Baru (Min. 8 Karakter)'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi Baru'), findsOneWidget);
      expect(find.text('Simpan Kata Sandi'), findsOneWidget);
    });

    testWidgets('Memanggil callback onLogout saat tombol Keluar Akun ditekan', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool logoutCalled = false;
      await tester.pumpWidget(createWidget(
        onLogout: () {
          logoutCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
      await tester.tap(find.text('Keluar dari Akun'));
      await tester.pumpAndSettle();

      expect(logoutCalled, isTrue);
    });

    testWidgets('Menampilkan ProfileAvatarPicker dan membuka sheet Ubah Foto Profil saat diketuk', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final avatarFinder = find.byType(ProfileAvatarPicker);
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(find.text('Ubah Foto Profil'), findsOneWidget);
      expect(find.text('Ambil dari Kamera'), findsOneWidget);
      expect(find.text('Pilih dari Galeri'), findsOneWidget);
    });
  });
}
