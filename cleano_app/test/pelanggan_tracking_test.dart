import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/models/order_model.dart';
import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/screens/pelanggan/pelanggan_tracking_screen.dart';
import 'package:cleano_app/services/api_service.dart';
import 'package:cleano_app/services/order_service.dart';
import 'package:cleano_app/widgets/frosted_glass_card.dart';
import 'package:cleano_app/widgets/tracking_order_card.dart';

class FakeOrderService implements OrderService {
  FakeOrderService({
    List<OrderModel>? activeOrders,
    List<OrderModel>? historyOrders,
    this.shouldThrow = false,
  })  : activeOrders = activeOrders ?? [],
        historyOrders = historyOrders ?? [];

  List<OrderModel> activeOrders;
  List<OrderModel> historyOrders;
  bool shouldThrow;
  int getOrdersCallCount = 0;
  final List<String?> requestedStatuses = [];

  @override
  Future<OrderListResult> getOrders({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    getOrdersCallCount++;
    requestedStatuses.add(status);
    if (shouldThrow) {
      throw const ApiException('Gagal terhubung ke server');
    }

    // Cermin backend: `aktif` adalah grup semua status yang belum final.
    final items = status == 'selesai'
        ? historyOrders
        : activeOrders.where((o) => status != 'aktif' || o.status != 'selesai').toList();
    return OrderListResult(
      items: items,
      page: page,
      pageSize: pageSize,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<OrderModel> createOrder({
    required int userId,
    required int serviceId,
    required double weight,
    required String paymentMethod,
    String? notes,
    String? voucherCode,
    String? photoPath,
    Uint8List? photoBytes,
    String? photoFileName,
  }) =>
      throw UnimplementedError();

  @override
  Future<OrderModel> getOrderDetail(int id) async {
    final all = [...activeOrders, ...historyOrders];
    return all.firstWhere((o) => o.id == id);
  }

  @override
  Future<OrderModel> updateStatus(int id, String status) => throw UnimplementedError();

  @override
  Future<OrderModel> confirmRelay(int id, int machineId) => throw UnimplementedError();

  @override
  Future<OrderModel> syncPayment(int id) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyUser = UserModel(
    id: 10,
    name: 'Budi Santoso',
    email: 'budi@cleano.id',
    phone: '081299887766',
    role: 'pelanggan',
    memberCode: 'MBR-0010',
    points: 150,
    tier: 'Gold',
  );

  final dummyActiveOrders = [
    OrderModel(
      id: 101,
      orderCode: 'CLN-2026-0001',
      userId: 10,
      customerName: 'Budi Santoso',
      customerPhone: '081299887766',
      memberCode: 'MBR-0010',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 1,
      serviceName: 'Cuci Komplit Reguler',
      pricePerKg: 8000,
      requiresMachine: true,
      machineId: 1,
      machineCode: 'MC-01',
      machineFinishAt: DateTime.now().add(const Duration(minutes: 35)),
      weight: 3.5,
      subtotalPrice: 28000,
      discountAmount: 0,
      totalPrice: 28000,
      paymentMethod: 'midtrans',
      paymentStatus: 'lunas',
      status: 'proses_cuci',
      queueWaitMinutes: 0,
      pointsAwarded: 0,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      imageUrl: 'https://cdn.cleano.id/orders/dropoff-101.jpg',
      notes: 'Baju putih dipisah cuci terpisah.',
    ),
    OrderModel(
      id: 102,
      orderCode: 'CLN-2026-0002',
      userId: 10,
      customerName: 'Budi Santoso',
      customerPhone: '081299887766',
      memberCode: 'MBR-0010',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 2,
      serviceName: 'Cuci Kering Lipat',
      pricePerKg: 6000,
      requiresMachine: true,
      weight: 2.0,
      subtotalPrice: 12000,
      discountAmount: 2000,
      voucherCode: 'DISKONHEMAT',
      totalPrice: 10000,
      paymentMethod: 'tunai',
      paymentStatus: 'menunggu_pembayaran',
      status: 'antre',
      queueWaitMinutes: 25,
      pointsAwarded: 0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    OrderModel(
      id: 103,
      orderCode: 'CLN-2026-0003',
      userId: 10,
      customerName: 'Budi Santoso',
      customerPhone: '081299887766',
      memberCode: 'MBR-0010',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 3,
      serviceName: 'Setrika Saja',
      pricePerKg: 5000,
      requiresMachine: false,
      weight: 1.5,
      subtotalPrice: 7500,
      discountAmount: 0,
      totalPrice: 7500,
      paymentMethod: 'tunai',
      paymentStatus: 'lunas',
      status: 'siap_diambil',
      queueWaitMinutes: 0,
      pointsAwarded: 0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
  ];

  final dummyHistoryOrders = [
    OrderModel(
      id: 100,
      orderCode: 'CLN-2026-0000',
      userId: 10,
      customerName: 'Budi Santoso',
      customerPhone: '081299887766',
      memberCode: 'MBR-0010',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 1,
      serviceName: 'Cuci Komplit Reguler',
      pricePerKg: 8000,
      requiresMachine: true,
      weight: 5.0,
      subtotalPrice: 40000,
      discountAmount: 5000,
      voucherCode: 'PROMO10K',
      totalPrice: 35000,
      paymentMethod: 'midtrans',
      paymentStatus: 'lunas',
      status: 'selesai',
      queueWaitMinutes: 0,
      pointsAwarded: 15,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildWidget({
    FakeOrderService? orderService,
    UserModel? user = dummyUser,
    VoidCallback? onLogout,
  }) {
    return MaterialApp(
      home: PelangganTrackingScreen(
        orderService: orderService ??
            FakeOrderService(
              activeOrders: dummyActiveOrders,
              historyOrders: dummyHistoryOrders,
            ),
        user: user,
        onLogout: onLogout,
      ),
    );
  }

  testWidgets('M7: Header menampilkan sapaan nama pelanggan, tier badge, dan saldo poin', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Halo, Budi Santoso 👋'), findsOneWidget);
    expect(find.text('Tier GOLD'), findsOneWidget);
    expect(find.text('150 Poin'), findsOneWidget);
    expect(find.text('Saldo Poin'), findsOneWidget);
  });

  testWidgets('M7: Tab Cucian Aktif menampilkan kartu pesanan dengan Stepper, mesin, antrean, dan status bayar', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Pastikan kedua order aktif muncul
    expect(find.text('CLN-2026-0001'), findsOneWidget);
    expect(find.text('CLN-2026-0002'), findsOneWidget);

    // Visual Stepper label
    expect(find.text('Antre'), findsWidgets);
    expect(find.text('Cuci'), findsWidgets);
    expect(find.text('Siap'), findsWidgets);
    expect(find.text('Selesai'), findsWidgets);

    // Status mesin untuk order 101 yang sedang dicuci
    expect(find.textContaining('Sedang Dicuci di Mesin MC-01'), findsOneWidget);

    // Status estimasi antrean untuk order 102
    expect(find.textContaining('Menunggu Antrean — Estimasi ± 25 Menit'), findsOneWidget);

    // Status pembayaran: cakup per kartu supaya LUNAS/BELUM BAYAR tidak
    // tertukar tanpa terdeteksi.
    Finder inCard(String code) => find.ancestor(
          of: find.text(code),
          matching: find.byType(TrackingOrderCard),
        );
    expect(
      find.descendant(of: inCard('CLN-2026-0001'), matching: find.text('LUNAS')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inCard('CLN-2026-0002'), matching: find.text('BELUM BAYAR')),
      findsOneWidget,
    );
  });

  testWidgets('M7: Query memakai grup aktif dan selesai, bukan status tunggal', (tester) async {
    final service = FakeOrderService(
      activeOrders: dummyActiveOrders,
      historyOrders: dummyHistoryOrders,
    );
    await tester.pumpWidget(buildWidget(orderService: service));
    await tester.pumpAndSettle();

    expect(service.requestedStatuses, containsAll(['aktif', 'selesai']));
  });

  testWidgets('M7: Order siap_diambil menampilkan banner pengambilan dan stepper tahap ketiga', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('CLN-2026-0003'), 200);
    await tester.pumpAndSettle();

    expect(find.text('CLN-2026-0003'), findsOneWidget);
    expect(find.text('Cucian Siap Diambil di Outlet! 🎉'), findsOneWidget);

    final siapCard = find.ancestor(
      of: find.text('CLN-2026-0003'),
      matching: find.byType(TrackingOrderCard),
    );
    final stepLabels = ['Antre', 'Cuci', 'Siap', 'Selesai'];
    for (final label in stepLabels) {
      expect(
        find.descendant(of: siapCard, matching: find.text(label)),
        findsOneWidget,
        reason: 'stepper harus punya tahap $label',
      );
    }
    // Tahap ketiga (Siap) adalah tahap aktif: tebal 800, bukan tahap lain.
    final siapLabel = tester.widget<Text>(
      find.descendant(of: siapCard, matching: find.text('Siap')),
    );
    expect(siapLabel.style?.fontWeight, FontWeight.w800);
    final cuciLabel = tester.widget<Text>(
      find.descendant(of: siapCard, matching: find.text('Cuci')),
    );
    expect(cuciLabel.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('M7: Berpindah ke Tab Riwayat Selesai menampilkan pesanan selesai dan informasi perolehan poin', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Tap tab Riwayat Selesai
    final historyTab = find.textContaining('Riwayat Selesai');
    expect(historyTab, findsOneWidget);
    await tester.tap(historyTab);
    await tester.pumpAndSettle();

    // Order riwayat CLN-2026-0000 muncul
    expect(find.text('CLN-2026-0000'), findsOneWidget);
    expect(find.text('Cuci Komplit Reguler • 5,00 kg'), findsOneWidget);

    // Badge perolehan poin loyalti muncul
    expect(find.text('Mendapatkan +15 Poin Loyalti'), findsOneWidget);
  });

  testWidgets('M7: Ketuk kartu pesanan membuka modal bottom-sheet rincian pesanan dan biaya', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Ketuk kartu order 101
    await tester.tap(find.text('CLN-2026-0001'));
    await tester.pumpAndSettle();

    // Bottom-sheet detail terbuka
    expect(find.text('Foto Bukti Drop-Off Pakaian'), findsOneWidget);
    expect(find.text('Catatan: Baju putih dipisah cuci terpisah.'), findsOneWidget);
    expect(find.text('Total Pembayaran'), findsOneWidget);
    expect(find.text('MIDTRANS • LUNAS'), findsOneWidget);

    // Tutup bottom sheet dengan tombol close
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Foto Bukti Drop-Off Pakaian'), findsNothing);
  });

  testWidgets('M7: Profil null menampilkan keterangan, bukan data karangan', (tester) async {
    await tester.pumpWidget(buildWidget(user: null));
    await tester.pumpAndSettle();

    expect(find.text('Profil belum termuat.'), findsOneWidget);
    expect(find.textContaining('Halo,'), findsNothing);
    expect(find.textContaining('Tier '), findsNothing);
    // Kartu aktivitas memakai kata "Poin", jadi yang diperiksa saldo profil.
    expect(find.text('Saldo Poin'), findsNothing);
  });

  testWidgets('M7: Keadaan kosong (Empty State) ditampilkan bila tidak ada cucian aktif', (tester) async {
    final emptyService = FakeOrderService(activeOrders: [], historyOrders: []);
    await tester.pumpWidget(buildWidget(orderService: emptyService));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada cucian yang sedang diproses.'), findsOneWidget);

    // Beralih ke tab riwayat
    await tester.tap(find.textContaining('Riwayat Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada riwayat pesanan yang selesai.'), findsOneWidget);
  });

  testWidgets('M7: Error state dan tombol coba lagi saat fetch API gagal', (tester) async {
    final failService = FakeOrderService(shouldThrow: true);
    await tester.pumpWidget(buildWidget(orderService: failService));
    await tester.pumpAndSettle();

    expect(find.text('Gagal terhubung ke server'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Perbaiki service dan tekan coba lagi
    failService.shouldThrow = false;
    failService.activeOrders = dummyActiveOrders;

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('CLN-2026-0001'), findsOneWidget);
  });

  testWidgets('M7: Kartu aktivitas 7 hari menghitung cucian, berat, dan poin dari riwayat', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Aktivitas 7 Hari Terakhir'), findsOneWidget);
    expect(find.text('dari riwayat terakhir'), findsOneWidget);
    expect(find.text('Cucian'), findsOneWidget);
    expect(find.text('5,00 kg'), findsOneWidget);
    expect(find.text('Total Berat'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Poin Didapat'), findsOneWidget);
  });

  testWidgets('M7: Pesanan lebih dari 7 hari tidak ikut dihitung', (tester) async {
    final lama = OrderModel(
      id: 99,
      orderCode: 'CLN-2026-LAMA',
      userId: 10,
      customerName: 'Budi Santoso',
      customerPhone: '081299887766',
      memberCode: 'MBR-0010',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 1,
      serviceName: 'Cuci Komplit Reguler',
      pricePerKg: 8000,
      requiresMachine: true,
      weight: 99.0,
      subtotalPrice: 792000,
      discountAmount: 0,
      totalPrice: 792000,
      paymentMethod: 'tunai',
      paymentStatus: 'lunas',
      status: 'selesai',
      queueWaitMinutes: 0,
      pointsAwarded: 999,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    await tester.pumpWidget(buildWidget(
      orderService: FakeOrderService(
        activeOrders: dummyActiveOrders,
        historyOrders: [...dummyHistoryOrders, lama],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('5,00 kg'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('99,00 kg'), findsNothing);
    expect(find.text('999'), findsNothing);
  });

  testWidgets('M7: Kartu aktivitas 7 hari tidak tampil saat riwayat kosong', (tester) async {
    await tester.pumpWidget(buildWidget(
      orderService: FakeOrderService(activeOrders: dummyActiveOrders),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aktivitas 7 Hari Terakhir'), findsNothing);
  });

  testWidgets('M7: Di layar lebar konten dibatasi 720 px dan di tengah', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    final content = find.byType(CustomScrollView);
    expect(tester.getSize(content).width, 720);
    expect(tester.getCenter(content).dx, closeTo(800, 0.5));

    // Kartu ringkasan ikut lebar konten, tidak melebar ke tepi layar.
    expect(tester.getSize(find.byType(FrostedGlassCard).first).width, lessThanOrEqualTo(720));
  });
}
