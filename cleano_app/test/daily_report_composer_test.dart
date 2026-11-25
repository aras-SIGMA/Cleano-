import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/models/dashboard_summary_model.dart';
import 'package:cleano_app/models/order_model.dart';
import 'package:cleano_app/utils/daily_report_composer.dart';

OrderModel _order({
  required int id,
  required DateTime createdAt,
  int totalPrice = 20000,
}) =>
    OrderModel(
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
      subtotalPrice: totalPrice,
      discountAmount: 0,
      totalPrice: totalPrice,
      paymentMethod: 'tunai',
      paymentStatus: 'lunas',
      status: 'proses_cuci',
      queueWaitMinutes: 0,
      pointsAwarded: 2,
      createdAt: createdAt,
    );

const _summaryDenganTren = DashboardSummaryModel(
  todayRevenue: 0,
  activeOrders: 2,
  readyOrders: 1,
  availableMachines: 3,
  totalOperationalMachines: 4,
  revenue7Days: [
    DailyRevenueModel(
      orderDate: '2026-11-24',
      dailyRevenue: 100000,
      totalTransactions: 5,
      totalWeightKg: 10,
    ),
  ],
);

void main() {
  final hariIni = DateTime(2026, 11, 25);

  test('hanya order hari ini yang masuk laporan', () {
    final content = DailyReportComposer.compose(
      summary: _summaryDenganTren,
      orders: [
        _order(id: 1, createdAt: hariIni, totalPrice: 25000),
        _order(id: 2, createdAt: hariIni.subtract(const Duration(days: 1))),
        _order(id: 3, createdAt: hariIni.add(const Duration(days: 1))),
      ],
      day: hariIni,
    );

    expect(content.transactionCount, 1);
    expect(content.orders.single.orderCode, 'CLN-20261125-0001');
    expect(content.totalToday, 25000);
  });

  test('pembanding naik dan turun terhadap rata-rata 7 hari', () {
    final naik = DailyReportComposer.compose(
      summary: _summaryDenganTren,
      orders: [_order(id: 1, createdAt: hariIni, totalPrice: 150000)],
      day: hariIni,
    );
    expect(naik.comparisonLabel, '+Rp 50.000 vs rata-rata 7 hari');

    final turun = DailyReportComposer.compose(
      summary: _summaryDenganTren,
      orders: [_order(id: 1, createdAt: hariIni, totalPrice: 30000)],
      day: hariIni,
    );
    expect(turun.comparisonLabel, '-Rp 70.000 vs rata-rata 7 hari');
  });

  test('hari tanpa transaksi tetap menghasilkan laporan yang sah', () {
    final content = DailyReportComposer.compose(
      summary: const DashboardSummaryModel(
        todayRevenue: 0,
        activeOrders: 0,
        readyOrders: 0,
        availableMachines: 2,
        totalOperationalMachines: 4,
        revenue7Days: [],
      ),
      orders: const [],
      day: hariIni,
    );

    expect(content.transactionCount, 0);
    expect(content.totalToday, 0);
    expect(content.orders, isEmpty);
    expect(content.comparisonLabel, 'Belum ada pembanding');
  });
}
