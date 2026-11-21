import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/screens/pelanggan/pelanggan_qr_card_screen.dart';
import 'package:cleano_app/services/auth_service.dart';
import 'package:cleano_app/services/session_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.user, this.shouldThrow = false});

  UserModel? user;
  bool shouldThrow;
  int callCount = 0;

  @override
  Future<UserModel?> getMe() async {
    callCount++;
    if (shouldThrow) {
      throw Exception('Gagal menghubungi server.');
    }
    return user;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyUser = UserModel(
    id: 1,
    name: 'Rina Marlina',
    email: 'rina@cleano.id',
    phone: '081234567891',
    role: 'pelanggan',
    memberCode: 'MBR-0001',
    points: 150,
    tier: 'Gold',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildWidget({
    SessionService? sessionService,
    AuthService? authService,
    UserModel? user,
    VoidCallback? onLogout,
  }) {
    return MaterialApp(
      home: PelangganQrCardScreen(
        sessionService: sessionService,
        authService: authService ?? FakeAuthService(user: dummyUser),
        user: user,
        onLogout: onLogout,
      ),
    );
  }

  testWidgets('M8: Kartu memuat QR Code yang hanya berisi member_code', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Verifikasi keberadaan QrImageView
    final qrFinder = find.byType(QrImageView);
    expect(qrFinder, findsOneWidget);

    // Pastikan data di dalam QR terkonfigurasi dengan member_code
    final qrWidget = tester.widget<QrImageView>(qrFinder);
    expect(qrWidget.semanticsLabel, 'QR Code MBR-0001');
  });

  testWidgets('M8: Menampilkan nama lengkap, tier badge, kode teks di bawah QR, dan poin', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Judul & Header Pass
    expect(find.text('CLEANO PASS'), findsOneWidget);
    expect(find.text('Exclusive Member'), findsOneWidget);

    // Tier badge
    expect(find.text('GOLD'), findsOneWidget);

    // Teks MBR-XXXX di bawah QR
    expect(find.text('MBR-0001'), findsOneWidget);

    // Nama lengkap member
    expect(find.text('Rina Marlina'), findsOneWidget);

    // Saldo Poin
    expect(find.text('150'), findsOneWidget);
    expect(find.text('Poin Loyalti'), findsOneWidget);
  });

  testWidgets('M8: Nomor WA disensor dan EMAIL TIDAK DITAMPILKAN SAMA SEKALI demi privasi', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Nomor WA disensor 0812-****-7891
    expect(find.text('0812-****-7891'), findsOneWidget);

    // Nomor HP asli tanpa sensor tidak boleh tampil
    expect(find.text('081234567891'), findsNothing);

    // EMAIL TIDAK DITAMPILKAN SAMA SEKALI
    expect(find.text('rina@cleano.id'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('M8: Petunjuk cara pakai di kasir ditampilkan', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Cara Pakai di Kasir'), findsOneWidget);
    expect(find.textContaining('Tunjukkan QR Code ini ke layar scanner kasir'), findsOneWidget);
    expect(find.textContaining('Kasir langsung memvalidasi akun tanpa perlu Anda mendiktekan nomor telepon'), findsOneWidget);
  });

  testWidgets('M8: Menangani error state dan tombol coba lagi', (tester) async {
    final failingAuth = FakeAuthService(shouldThrow: true);
    await tester.pumpWidget(buildWidget(authService: failingAuth));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal memuat kartu member'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Pulihkan auth service dan tekan coba lagi
    failingAuth.shouldThrow = false;
    failingAuth.user = dummyUser;

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('MBR-0001'), findsOneWidget);
  });

  testWidgets('M8: Profil dari navigasi induk tidak memicu fetch /users/me', (tester) async {
    final auth = FakeAuthService(user: dummyUser);
    await tester.pumpWidget(buildWidget(authService: auth, user: dummyUser));
    await tester.pumpAndSettle();

    expect(find.text('MBR-0001'), findsOneWidget);
    expect(auth.callCount, 0);
  });
}
