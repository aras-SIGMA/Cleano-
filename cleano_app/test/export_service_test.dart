import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          createdAt: DateTime(2026, 11, 20, 10, 0),
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

class FakeExportService extends ExportService {
  final List<String> exportedFormats = [];
  bool shouldThrow = false;

  @override
  Future<void> exportReport({
    required String format,
    required DashboardSummaryModel summary,
    List<OrderModel>? orders,
  }) async {
    if (shouldThrow) {
      throw Exception('Simulasi gagal export');
    }
    exportedFormats.add(format);
  }
}

void main() {
  const dummySummary = DashboardSummaryModel(
    todayRevenue: 350000,
    activeOrders: 5,
    readyOrders: 3,
    availableMachines: 2,
    totalOperationalMachines: 4,
    revenue7Days: [
      DailyRevenueModel(
        orderDate: '2026-11-20',
        dailyRevenue: 350000,
        totalTransactions: 6,
        totalWeightKg: 24.0,
      ),
    ],
  );

  final dummyOrders = [
    OrderModel(
      id: 10,
      orderCode: 'CLN-20261120-0010',
      userId: 3,
      customerName: 'Budi Santoso',
      customerPhone: '081298765432',
      memberCode: 'MBR-0002',
      customerTier: 'Silver',
      customerCurrentTier: 'Silver',
      serviceId: 2,
      serviceName: 'Cuci Kering Express',
      pricePerKg: 10000,
      requiresMachine: true,
      weight: 5.0,
      subtotalPrice: 50000,
      discountAmount: 5000,
      totalPrice: 45000,
      paymentMethod: 'qris',
      paymentStatus: 'lunas',
      status: 'siap_ambil',
      queueWaitMinutes: 0,
      pointsAwarded: 5,
      createdAt: DateTime(2026, 11, 20, 14, 30),
    ),
  ];

  group('ExportService Unit Tests (M10)', () {
    test('generateCsv menghasilkan byte array CSV yang lengkap dengan metrik & pesanan', () async {
      final service = ExportService(shareCallback: ({required bytes, required filename}) async => true);
      final bytes = await service.generateCsv(summary: dummySummary, orders: dummyOrders);

      expect(bytes, isNotEmpty);
      final csvText = utf8.decode(bytes);

      expect(csvText, contains('CLEANO SMART LAUNDRY - REKAP LAPORAN OPERASIONAL'));
      expect(csvText, contains('RINGKASAN METRIK OPERASIONAL'));
      expect(csvText, contains('Omzet Hari Ini'));
      expect(csvText, contains('350000'));
      expect(csvText, contains('TREN OMZET 7 HARI TERAKHIR'));
      expect(csvText, contains('2026-11-20'));
      expect(csvText, contains('DAFTAR TRANSAKSI PESANAN'));
      expect(csvText, contains('CLN-20261120-0010'));
      expect(csvText, contains('Budi Santoso'));
      expect(csvText, contains('Cuci Kering Express'));
    });

    test('generateCsv dapat menangani pesanan kosong tanpa error', () async {
      final service = ExportService(shareCallback: ({required bytes, required filename}) async => true);
      final bytes = await service.generateCsv(summary: dummySummary, orders: null);

      expect(bytes, isNotEmpty);
      final csvText = utf8.decode(bytes);

      expect(csvText, contains('RINGKASAN METRIK OPERASIONAL'));
      expect(csvText, isNot(contains('DAFTAR TRANSAKSI PESANAN')));
    });

    test('generatePdf menghasilkan biner PDF valid dengan header %PDF-', () async {
      final service = ExportService(shareCallback: ({required bytes, required filename}) async => true);
      final bytes = await service.generatePdf(summary: dummySummary, orders: dummyOrders);

      expect(bytes, isNotEmpty);
      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('exportReport format CSV memanggil shareCallback dengan ekstensi .csv', () async {
      Uint8List? capturedBytes;
      String? capturedFilename;

      final service = ExportService(
        shareCallback: ({required bytes, required filename}) async {
          capturedBytes = bytes;
          capturedFilename = filename;
          return true;
        },
      );

      await service.exportReport(
        format: 'CSV',
        summary: dummySummary,
        orders: dummyOrders,
      );

      expect(capturedFilename, isNotNull);
      expect(capturedFilename!.endsWith('.csv'), isTrue);
      expect(capturedBytes, isNotNull);
      expect(capturedBytes!, isNotEmpty);
    });

    test('exportReport format PDF memanggil shareCallback dengan ekstensi .pdf', () async {
      Uint8List? capturedBytes;
      String? capturedFilename;

      final service = ExportService(
        shareCallback: ({required bytes, required filename}) async {
          capturedBytes = bytes;
          capturedFilename = filename;
          return true;
        },
      );

      await service.exportReport(
        format: 'PDF',
        summary: dummySummary,
        orders: dummyOrders,
      );

      expect(capturedFilename, isNotNull);
      expect(capturedFilename!.endsWith('.pdf'), isTrue);
      expect(capturedBytes, isNotNull);
      expect(capturedBytes!, isNotEmpty);
      expect(utf8.decode(capturedBytes!.sublist(0, 5)), equals('%PDF-'));
    });
  });

  group('KasirDashboardScreen Export Integration Tests (M10)', () {
    testWidgets('Membuka bottom sheet ekspor dan memicu ekspor CSV dengan notifikasi sukses', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeExport = FakeExportService();

      await tester.pumpWidget(
        MaterialApp(
          home: KasirDashboardScreen(
            dashboardService: FakeDashboardService(),
            orderService: FakeOrderService(),
            exportService: fakeExport,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Temukan tombol Unduh Rekap di AppBar
      final downloadBtn = find.text('Unduh Rekap');
      expect(downloadBtn, findsOneWidget);
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      // Verifikasi bottom sheet terbuka
      expect(find.text('Ekspor Ringkasan Laporan'), findsOneWidget);
      expect(find.text('Unduh rekap data operasional kasir Cleano'), findsOneWidget);
      expect(find.text('Ekspor CSV'), findsOneWidget);
      expect(find.text('Ekspor PDF'), findsOneWidget);

      // Tap Ekspor CSV
      await tester.tap(find.text('Ekspor CSV'));
      await tester.pumpAndSettle();

      // Verifikasi fakeExport dipanggil
      expect(fakeExport.exportedFormats, contains('CSV'));
      // Verifikasi SnackBar sukses
      expect(find.text('Laporan format CSV berhasil diekspor.'), findsOneWidget);
    });

    testWidgets('Memicu ekspor PDF dan menampilkan notifikasi sukses', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeExport = FakeExportService();

      await tester.pumpWidget(
        MaterialApp(
          home: KasirDashboardScreen(
            dashboardService: FakeDashboardService(),
            orderService: FakeOrderService(),
            exportService: fakeExport,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Unduh Rekap'));
      await tester.pumpAndSettle();

      // Tap Ekspor PDF
      await tester.tap(find.text('Ekspor PDF'));
      await tester.pumpAndSettle();

      expect(fakeExport.exportedFormats, contains('PDF'));
      expect(find.text('Laporan format PDF berhasil diekspor.'), findsOneWidget);
    });

    testWidgets('Menampilkan notifikasi galat jika ekspor gagal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeExport = FakeExportService()..shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: KasirDashboardScreen(
            dashboardService: FakeDashboardService(),
            orderService: FakeOrderService(),
            exportService: fakeExport,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Unduh Rekap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ekspor CSV'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal mengekspor laporan:'), findsOneWidget);
    });
  });
}
