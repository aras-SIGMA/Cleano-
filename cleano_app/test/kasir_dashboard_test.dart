import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/models/dashboard_summary_model.dart';
import 'package:cleano_app/models/order_model.dart';
import 'package:cleano_app/screens/kasir/kasir_dashboard_screen.dart';
import 'package:cleano_app/services/dashboard_service.dart';
import 'package:cleano_app/services/export_service.dart';
import 'package:cleano_app/services/order_service.dart';

class FakeDashboardService implements DashboardService {
  @override
  Future<DashboardSummaryModel> getSummary() async {
    return const DashboardSummaryModel(
      todayRevenue: 250000,
      activeOrders: 4,
      readyOrders: 2,
      availableMachines: 3,
      totalOperationalMachines: 4,
      revenue7Days: [
        DailyRevenueModel(
          orderDate: '2026-11-20',
          dailyRevenue: 250000,
          totalTransactions: 5,
          totalWeightKg: 18.5,
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOrderService implements OrderService {
  @override
  Future<OrderListResult> getOrders({String? status, String? search, int page = 1, int pageSize = 10}) async {
    return OrderListResult(
      items: [
        OrderModel(
          id: 1,
          orderCode: 'CLN-20261120-0001',
          userId: 2,
          customerName: 'Ahmad Subagyo',
          customerPhone: '081234567890',
          memberCode: 'MBR-0001',
          customerTier: 'Gold',
          customerCurrentTier: 'Gold',
          serviceId: 1,
          serviceName: 'Cuci Komplit Reguler',
          pricePerKg: 7000,
          requiresMachine: true,
          weight: 4.0,
          subtotalPrice: 28000,
          discountAmount: 0,
          totalPrice: 28000,
          paymentMethod: 'tunai',
          paymentStatus: 'lunas',
          status: 'proses_cuci',
          queueWaitMinutes: 0,
          pointsAwarded: 2,
          machineCode: 'MC-01',
          createdAt: DateTime.now(),
        ),
      ],
      page: 1,
      pageSize: 10,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExportService implements ExportService {
  final List<String> exportedFormats = [];

  @override
  Future<void> exportReport({
    required String format,
    required DashboardSummaryModel summary,
    List<OrderModel>? orders,
  }) async {
    exportedFormats.add(format);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('KasirDashboardScreen menampilkan 4 kartu metrik dan pesanan aktif', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: KasirDashboardScreen(
          dashboardService: FakeDashboardService(),
          orderService: FakeOrderService(),
          exportService: FakeExportService(),
        ),
      ),
    );

    // Animasi loading selesai
    await tester.pumpAndSettle();

    // 1. Verifikasi judul AppBar
    expect(find.text('Beranda Kasir'), findsOneWidget);

    // 2. Verifikasi 4 kartu metrik
    expect(find.text('Pendapatan Hari Ini'), findsOneWidget);
    expect(find.text('Pesanan Aktif'), findsWidgets);
    expect(find.text('Siap Diambil'), findsOneWidget);
    expect(find.text('Mesin Tersedia'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);

    // 3. Verifikasi order aktif tampil di daftar
    expect(find.text('CLN-20261120-0001'), findsOneWidget);
    expect(find.textContaining('Ahmad Subagyo'), findsOneWidget);
    expect(find.text('Sedang Dicuci'), findsWidgets);

    // Batasi lebar konten 1100 px dan pusatkan pada layar lebar.
    final content = find.byType(CustomScrollView);
    expect(tester.getSize(content).width, 1100);
    expect(tester.getCenter(content).dx, closeTo(640, 0.5));
  });

  testWidgets('laporan harian diekspor sekali per hari, tidak berulang saat layar dipasang ulang', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final exportService = FakeExportService();

    Widget buildScreen(Key key) => MaterialApp(
          home: KasirDashboardScreen(
            key: key,
            dashboardService: FakeDashboardService(),
            orderService: FakeOrderService(),
            exportService: exportService,
          ),
        );

    // Hari pertama: laporan dibuat tepat sekali.
    await tester.pumpWidget(buildScreen(const ValueKey('hari-1')));
    await tester.pumpAndSettle();
    expect(exportService.exportedFormats, ['PDF']);
    expect(find.textContaining('Laporan harian siap dibagikan'), findsOneWidget);

    // Hari yang sama: layar dipasang ulang — tidak boleh mengekspor lagi.
    await tester.pumpWidget(buildScreen(const ValueKey('hari-1-ulang')));
    await tester.pumpAndSettle();
    expect(exportService.exportedFormats, ['PDF']);
  });
}
