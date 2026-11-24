import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/screens/kasir/kasir_profile_screen.dart';

void main() {
  const dummyKasir = UserModel(
    id: 10,
    name: 'Rudi Hartono',
    email: 'rudi.hartono@cleano.id',
    phone: '081234567890',
    role: 'kasir',
    memberCode: 'STF-0010',
    points: 0,
    tier: 'Silver',
  );

  Widget createWidget({UserModel? user, VoidCallback? onLogout}) {
    return MaterialApp(
      home: KasirProfileScreen(
        user: user ?? dummyKasir,
        onLogout: onLogout,
      ),
    );
  }

  group('KasirProfileScreen Tests', () {
    testWidgets('Menampilkan profil staf, shift, dan informasi outlet lengkap', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Judul AppBar
      expect(find.text('Akun & Pengaturan Kasir'), findsOneWidget);

      // Hero Card Identitas Staf
      expect(find.text('Rudi Hartono'), findsOneWidget);
      expect(find.text('STAFF KASIR'), findsOneWidget);
      expect(find.text('STF-0010'), findsOneWidget);
      expect(find.text('Cleano Outlet 01 — Pusat Sukajadi'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);

      // Shift & Quick Stats
      expect(find.text('Shift Kasir'), findsOneWidget);
      expect(find.text('Pagi (08-16)'), findsOneWidget);
      expect(find.text('Konter POS'), findsOneWidget);
      expect(find.text('Siap Melayani'), findsOneWidget);

      // Informasi Akun & Keamanan
      expect(find.text('INFORMASI AKUN & KEAMANAN'), findsOneWidget);
      expect(find.text('rudi.hartono@cleano.id'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('Ganti Kata Sandi'), findsOneWidget);

      // Hardware POS
      expect(find.text('PERANGKAT & HARDWARE POS'), findsOneWidget);
      expect(find.text('Printer Thermal Bluetooth'), findsOneWidget);
      expect(find.text('Suara Notifikasi Pesanan'), findsOneWidget);

      // SOP & Bantuan
      expect(find.text('STANDAR OPERASIONAL & BANTUAN'), findsOneWidget);
      expect(find.text('Panduan SOP Kasir & Estafet'), findsOneWidget);
      expect(find.text('Kontak Supervisor & Bantuan'), findsOneWidget);

      // Sistem
      expect(find.text('SISTEM & APLIKASI'), findsOneWidget);
      expect(find.textContaining('Cleano POS v1.0.0'), findsOneWidget);

      // Tombol Logout
      expect(find.text('Tutup Shift & Keluar Akun'), findsOneWidget);
    });

    testWidgets('Membuka dialog simulasi struk thermal saat tombol Uji Cetak ditekan', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final ujiCetakBtn = find.text('Uji Cetak');
      expect(ujiCetakBtn, findsOneWidget);
      await tester.tap(ujiCetakBtn);
      await tester.pumpAndSettle();

      // Verifikasi dialog struk terbuka
      expect(find.text('Simulasi Struk POS'), findsOneWidget);
      expect(find.text('CLEANO SMART LAUNDRY'), findsOneWidget);
      expect(find.text('UJI COBA THERMAL 58mm'), findsOneWidget);
      expect(find.text('Kirim ke Printer'), findsOneWidget);

      // Tekan tombol kirim ke printer
      await tester.tap(find.text('Kirim ke Printer'));
      await tester.pumpAndSettle();

      // Dialog tertutup dan SnackBar muncul
      expect(find.text('Simulasi Struk POS'), findsNothing);
      expect(find.textContaining('Perintah cetak struk terkirim'), findsOneWidget);
    });

    testWidgets('Membuka bottom sheet ganti kata sandi', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final gantiSandiTile = find.text('Ganti Kata Sandi');
      expect(gantiSandiTile, findsOneWidget);
      await tester.tap(gantiSandiTile);
      await tester.pumpAndSettle();

      // Verifikasi form ubah kata sandi
      expect(find.text('Ubah Kata Sandi'), findsOneWidget);
      expect(find.text('Kata Sandi Saat Ini'), findsOneWidget);
      expect(find.text('Kata Sandi Baru (Min. 6 Karakter)'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi Baru'), findsOneWidget);
      expect(find.text('Simpan Kata Sandi'), findsOneWidget);
    });

    testWidgets('Membuka bottom sheet panduan SOP Kasir & Estafet', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final sopTile = find.text('Panduan SOP Kasir & Estafet');
      expect(sopTile, findsOneWidget);
      await tester.tap(sopTile);
      await tester.pumpAndSettle();

      // Verifikasi konten SOP terbuka
      expect(find.text('Standar operasional kebersihan & pelayanan Cleano'), findsOneWidget);
      expect(find.text('Identifikasi Pelanggan & Drop-Off'), findsOneWidget);
      expect(find.text('Penimbangan & Pengecekan Kantong'), findsOneWidget);
      expect(find.text('Estafet Mesin Cuci Otomatis (FIFO)'), findsOneWidget);
      expect(find.text('Pengambilan & Verifikasi Pembayaran'), findsOneWidget);
    });

    testWidgets('Membuka bottom sheet kontak supervisor', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final kontakTile = find.text('Kontak Supervisor & Bantuan');
      expect(kontakTile, findsOneWidget);
      await tester.tap(kontakTile);
      await tester.pumpAndSettle();

      expect(find.text('Bantuan & Kontak Supervisor'), findsOneWidget);
      expect(find.text('Hendra Saputra (Supervisor Outlet)'), findsOneWidget);
      expect(find.text('0812-8899-7711'), findsOneWidget);
      expect(find.text('Tim IT & Support Cleano'), findsOneWidget);
    });

    testWidgets('Memanggil callback onLogout saat tombol Tutup Shift ditekan', (tester) async {
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

      // Scroll ke bawah jika perlu
      await tester.scrollUntilVisible(find.text('Tutup Shift & Keluar Akun'), 200);
      await tester.tap(find.text('Tutup Shift & Keluar Akun'));
      await tester.pumpAndSettle();

      expect(logoutCalled, isTrue);
    });
  });
}
