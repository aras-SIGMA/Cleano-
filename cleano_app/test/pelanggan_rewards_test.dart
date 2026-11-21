import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/models/reward_model.dart';
import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/models/voucher_model.dart';
import 'package:cleano_app/screens/pelanggan/pelanggan_rewards_screen.dart';
import 'package:cleano_app/services/api_service.dart';
import 'package:cleano_app/services/auth_service.dart';
import 'package:cleano_app/services/reward_service.dart';

class FakeRewardService implements RewardService {
  FakeRewardService({
    List<RewardModel>? catalog,
    List<VoucherModel>? activeVouchers,
    List<VoucherModel>? historyVouchers,
    this.shouldThrow = false,
  })  : catalog = catalog ?? [],
        activeVouchers = activeVouchers ?? [],
        historyVouchers = historyVouchers ?? [];

  List<RewardModel> catalog;
  List<VoucherModel> activeVouchers;
  List<VoucherModel> historyVouchers;
  bool shouldThrow;

  int? lastRedeemedRewardId;

  @override
  Future<List<RewardModel>> getCatalog() async {
    if (shouldThrow) throw const ApiException('Gagal memuat katalog.');
    return catalog;
  }

  @override
  Future<MyVouchersResult> getMyVouchers() async {
    if (shouldThrow) throw const ApiException('Gagal memuat voucher.');
    return MyVouchersResult(
      active: activeVouchers,
      history: historyVouchers,
      total: activeVouchers.length + historyVouchers.length,
    );
  }

  @override
  Future<VoucherModel> redeem(int rewardId) async {
    lastRedeemedRewardId = rewardId;
    if (shouldThrow) throw const ApiException('Gagal menukarkan voucher.');

    final reward = catalog.firstWhere((r) => r.id == rewardId);
    final voucher = VoucherModel(
      id: 999,
      voucherCode: 'CLN-VCR-NEW1',
      rewardId: reward.id,
      title: reward.title,
      discountAmount: reward.discountAmount,
      pointsRequired: reward.pointsRequired,
      isUsed: false,
      createdAt: DateTime.now(),
    );
    activeVouchers.insert(0, voucher);
    return voucher;
  }
}

class FakeAuthService extends AuthService {
  FakeAuthService({this.user});
  UserModel? user;
  int callCount = 0;

  @override
  Future<UserModel?> getMe() async {
    callCount++;
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

  final dummyCatalog = [
    const RewardModel(
      id: 1,
      title: 'Potongan Hemat Rp 5.000',
      description: 'Potongan langsung Rp 5.000 tanpa minimal transaksi.',
      pointsRequired: 50,
      discountAmount: 5000,
      isActive: true,
    ),
    const RewardModel(
      id: 2,
      title: 'Potongan Spesial Rp 25.000',
      description: 'Diskon Rp 25.000 khusus cucian komplit keluarga.',
      pointsRequired: 200, // Lebih dari 150 poin user -> tidak cukup
      discountAmount: 25000,
      isActive: true,
    ),
  ];

  final dummyActiveVouchers = [
    VoucherModel(
      id: 10,
      voucherCode: 'CLN-VCR-8821',
      rewardId: 1,
      title: 'Potongan Hemat Rp 5.000',
      discountAmount: 5000,
      pointsRequired: 50,
      isUsed: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final dummyHistoryVouchers = [
    VoucherModel(
      id: 9,
      voucherCode: 'CLN-VCR-USED',
      rewardId: 1,
      title: 'Potongan Hemat Rp 5.000',
      discountAmount: 5000,
      pointsRequired: 50,
      isUsed: true,
      usedAt: DateTime.now().subtract(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildWidget({
    RewardService? rewardService,
    AuthService? authService,
    VoidCallback? onLogout,
    UserModel? user,
  }) {
    return MaterialApp(
      home: PelangganRewardsScreen(
        rewardService: rewardService ??
            FakeRewardService(
              catalog: dummyCatalog,
              activeVouchers: dummyActiveVouchers,
              historyVouchers: dummyHistoryVouchers,
            ),
        authService: authService ?? FakeAuthService(user: dummyUser),
        user: user,
        onLogout: onLogout,
      ),
    );
  }

  testWidgets('M9: Banner menampilkan saldo poin, tier, progress bar, dan info bonus 2x poin', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Saldo poin & tier
    expect(find.text('SALDO POIN SAYA'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('TIER GOLD'), findsOneWidget);

    // Progress bar info (150 poin lagi menuju Platinum)
    expect(find.text('150 Poin lagi menuju Platinum'), findsOneWidget);

    // Info bonus 2x poin
    expect(find.text('Bonus 2x Poin Loyalti ⚡'), findsOneWidget);
    expect(find.textContaining('berat ≥ 5 kg atau layanan Express'), findsOneWidget);
  });

  testWidgets('M9: Sub-tab Katalog Hadiah menampilkan daftar reward dan status tombol tukar', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Reward 1 (50 poin) -> Cukup (User punya 150 poin)
    expect(find.text('Potongan Hemat Rp 5.000'), findsOneWidget);
    expect(find.text('50 Poin'), findsOneWidget);
    expect(find.text('Tukar Poin'), findsOneWidget);

    // Reward 2 (200 poin) -> Kurang
    expect(find.text('Potongan Spesial Rp 25.000'), findsOneWidget);
    expect(find.text('200 Poin'), findsOneWidget);
    expect(find.text('Poin Kurang'), findsOneWidget);
  });

  testWidgets('M9: Alur Tukar Poin memunculkan dialog konfirmasi dan memanggil API redeem', (tester) async {
    final fakeService = FakeRewardService(
      catalog: dummyCatalog,
      activeVouchers: [...dummyActiveVouchers],
      historyVouchers: dummyHistoryVouchers,
    );
    await tester.pumpWidget(buildWidget(rewardService: fakeService));
    await tester.pumpAndSettle();

    // Tekan tombol "Tukar Poin" pada reward 1
    await tester.tap(find.text('Tukar Poin'));
    await tester.pumpAndSettle();

    // Dialog konfirmasi muncul
    expect(find.text('Konfirmasi Tukar Poin'), findsOneWidget);
    expect(find.text('-50 Poin'), findsOneWidget);
    expect(find.text('100 Poin'), findsOneWidget); // Sisa saldo

    // Konfirmasi penukaran
    await tester.tap(find.text('Tukar Sekarang'));
    await tester.pumpAndSettle();

    // Verifikasi service terpanggil dengan id 1
    expect(fakeService.lastRedeemedRewardId, 1);

    // SnackBar sukses muncul
    expect(find.textContaining('CLN-VCR-NEW1 berhasil diklaim'), findsOneWidget);
  });

  testWidgets('M9: Sub-tab Voucher Saya menampilkan voucher aktif (QR + badge) dan riwayat terpakai (redup)', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Beralih ke sub-tab Voucher Saya
    final vouchersTab = find.textContaining('Voucher Saya');
    expect(vouchersTab, findsOneWidget);
    await tester.tap(vouchersTab);
    await tester.pumpAndSettle();

    // Voucher aktif CLN-VCR-8821
    expect(find.text('Voucher Aktif (Siap Pakai)'), findsOneWidget);
    expect(find.text('CLN-VCR-8821'), findsOneWidget);
    expect(find.text('1x Pakai'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    // Scroll sampai riwayat voucher terlihat
    await tester.scrollUntilVisible(find.text('Riwayat Voucher'), 200);

    // Riwayat voucher terpakai CLN-VCR-USED
    expect(find.text('Riwayat Voucher'), findsOneWidget);
    expect(find.text('CLN-VCR-USED'), findsOneWidget);
    expect(find.text('Sudah Terpakai'), findsOneWidget);
  });

  testWidgets('M9: Ketuk QR voucher membuka dialog perbesaran QR untuk kasir', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Pindah ke tab voucher
    await tester.tap(find.textContaining('Voucher Saya'));
    await tester.pumpAndSettle();

    // Scroll sampai QR terlihat
    await tester.scrollUntilVisible(find.byType(QrImageView), 100);

    // Ketuk QR image view
    await tester.tap(find.byType(QrImageView));
    await tester.pumpAndSettle();

    // Modal QR terbuka
    expect(find.text('Tunjukkan QR ini ke kasir saat memesan cucian.'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tutup dialog
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tunjukkan QR ini ke kasir saat memesan cucian.'), findsNothing);
  });

  testWidgets('M9: Tampilan kosong (Empty State) saat katalog dan voucher kosong', (tester) async {
    final emptyService = FakeRewardService(catalog: [], activeVouchers: [], historyVouchers: []);
    await tester.pumpWidget(buildWidget(rewardService: emptyService));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada reward voucher yang tersedia saat ini.'), findsOneWidget);

    // Cek tab voucher kosong
    await tester.tap(find.textContaining('Voucher Saya'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Anda belum memiliki voucher reward'), findsOneWidget);
  });

  testWidgets('M9: Profil dari induk dipakai tanpa fetch /users/me ulang', (tester) async {
    final auth = FakeAuthService(user: dummyUser);

    await tester.pumpWidget(buildWidget(authService: auth, user: dummyUser));
    await tester.pumpAndSettle();

    // Induk sudah memuat profil sekali untuk seluruh portal.
    expect(auth.callCount, 0);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('TIER GOLD'), findsOneWidget);
  });

  testWidgets('M9: Refresh menarik saldo poin terbaru dari server', (tester) async {
    const saldoBaru = UserModel(
      id: 1,
      name: 'Rina Marlina',
      email: 'rina@cleano.id',
      phone: '081234567891',
      role: 'pelanggan',
      memberCode: 'MBR-0001',
      points: 320,
      tier: 'Platinum',
    );
    final auth = FakeAuthService(user: saldoBaru);

    await tester.pumpWidget(buildWidget(authService: auth, user: dummyUser));
    await tester.pumpAndSettle();
    expect(find.text('TIER GOLD'), findsOneWidget);

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(auth.callCount, greaterThan(0));
    expect(find.text('TIER PLATINUM'), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
  });

  testWidgets('M9: Profil baru dari induk ikut tampil walau state sudah terpasang', (tester) async {
    final auth = FakeAuthService();
    const poinNaik = UserModel(
      id: 1,
      name: 'Rina Marlina',
      email: 'rina@cleano.id',
      phone: '081234567891',
      role: 'pelanggan',
      memberCode: 'MBR-0001',
      points: 260,
      tier: 'Gold',
    );

    await tester.pumpWidget(buildWidget(authService: auth, user: dummyUser));
    await tester.pumpAndSettle();
    expect(find.text('150 Poin lagi menuju Platinum'), findsOneWidget);

    await tester.pumpWidget(buildWidget(authService: auth, user: poinNaik));
    await tester.pumpAndSettle();

    expect(find.text('40 Poin lagi menuju Platinum'), findsOneWidget);
  });
}
