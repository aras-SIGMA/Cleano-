import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/models/dashboard_summary_model.dart';
import 'package:cleano_app/models/order_model.dart';
import 'package:cleano_app/services/daily_report_service.dart';

DashboardSummaryModel _summary() => const DashboardSummaryModel(
      todayRevenue: 100000,
      activeOrders: 2,
      readyOrders: 1,
      availableMachines: 3,
      totalOperationalMachines: 4,
      revenue7Days: [],
    );

OrderModel _order(int id) => OrderModel(
      id: id,
      orderCode: 'CLN-20261125-000$id',
      userId: 2,
      customerName: 'Rina',
      customerPhone: '081234567890',
      memberCode: 'MBR-0001',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 1,
      serviceName: 'Cuci Komplit Reguler',
      pricePerKg: 7000,
      requiresMachine: true,
      weight: 3.5,
      subtotalPrice: 24500,
      discountAmount: 0,
      totalPrice: 24500,
      paymentMethod: 'tunai',
      paymentStatus: 'lunas',
      status: 'proses_cuci',
      queueWaitMinutes: 0,
      pointsAwarded: 2,
      createdAt: DateTime.now(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('laporan dibuat saat pertama kali dibuka, lalu tidak lagi di hari yang sama', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;

    final service = DailyReportService(
      prefs,
      onDailyReportReady: ({required summary, required orders}) async {
        calls++;
      },
    );

    await service.maybeRunDaily(summary: _summary(), orders: [_order(1)]);
    expect(calls, 1);

    // Rebuild / pull-to-refresh di hari yang sama tidak memicu lagi.
    await service.maybeRunDaily(summary: _summary(), orders: [_order(1)]);
    await service.maybeRunDaily(summary: _summary(), orders: [_order(1)]);
    expect(calls, 1);

    final last = prefs.getString('cleano_last_report_date');
    expect(last, isNotNull);
    expect(last, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('tanggal hanya tercatat setelah callback sukses', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var shouldFail = true;

    final service = DailyReportService(
      prefs,
      onDailyReportReady: ({required summary, required orders}) async {
        if (shouldFail) throw Exception('ekspor gagal');
      },
    );

    await service.maybeRunDaily(summary: _summary(), orders: [_order(1)]);
    // Gagal: tanggal tidak dicatat, besok coba lagi.
    expect(prefs.getString('cleano_last_report_date'), isNull);

    shouldFail = false;
    await service.maybeRunDaily(summary: _summary(), orders: [_order(1)]);
    expect(prefs.getString('cleano_last_report_date'), isNotNull);
  });

  test('kegagalan tidak melempar exception ke pemanggil', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final service = DailyReportService(
      prefs,
      onDailyReportReady: ({required summary, required orders}) async {
        throw Exception('ekspor gagal');
      },
    );

    await expectLater(
      service.maybeRunDaily(summary: _summary(), orders: [_order(1)]),
      completes,
    );
  });
}
