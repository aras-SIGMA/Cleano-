import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/models/next_queue_order_model.dart';
import 'package:cleano_app/models/order_model.dart';
import 'package:cleano_app/screens/kasir/kasir_orders_screen.dart';
import 'package:cleano_app/services/order_service.dart';

class MockOrderService implements OrderService {
  MockOrderService({
    List<OrderModel>? initialOrders,
  }) : orders = initialOrders ?? [];

  List<OrderModel> orders;
  int getOrdersCallCount = 0;
  String? lastStatusFilter;
  String? lastSearch;
  int? lastPage;

  // Gerbang per panggilan: entri ke-N menahan panggilan ke-N sampai di-release.
  // Dipakai uji balapan untuk mengatur urutan respons.
  final List<Completer<void>> gates = [];

  int? updatedOrderId;
  String? updatedStatus;

  int? relayedOrderId;
  int? relayedMachineId;

  OrderModel? customUpdateResult;

  @override
  Future<OrderListResult> getOrders({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 15,
  }) async {
    final callIndex = getOrdersCallCount++;
    lastStatusFilter = status;
    lastSearch = search;
    lastPage = page;

    if (callIndex < gates.length) {
      await gates[callIndex].future;
    }

    final q = search?.toLowerCase() ?? '';
    final filtered = orders.where((o) {
      final cocokStatus = status == null || status == 'semua' || o.status == status;
      final cocokCari = q.isEmpty ||
          o.orderCode.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q);
      return cocokStatus && cocokCari;
    }).toList();

    return OrderListResult(
      items: filtered,
      page: page,
      pageSize: pageSize,
      total: filtered.length,
      totalPages: 1,
    );
  }

  @override
  Future<OrderModel> updateStatus(int id, String status) async {
    updatedOrderId = id;
    updatedStatus = status;

    if (customUpdateResult != null) {
      return customUpdateResult!;
    }

    final order = orders.firstWhere((o) => o.id == id);
    return OrderModel(
      id: order.id,
      orderCode: order.orderCode,
      userId: order.userId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      memberCode: order.memberCode,
      customerTier: order.customerTier,
      customerCurrentTier: order.customerCurrentTier,
      serviceId: order.serviceId,
      serviceName: order.serviceName,
      pricePerKg: order.pricePerKg,
      requiresMachine: order.requiresMachine,
      machineId: status == 'siap_diambil' ? null : order.machineId,
      machineCode: status == 'siap_diambil' ? null : order.machineCode,
      weight: order.weight,
      subtotalPrice: order.subtotalPrice,
      discountAmount: order.discountAmount,
      totalPrice: order.totalPrice,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      status: status,
      queueWaitMinutes: order.queueWaitMinutes,
      pointsAwarded: order.pointsAwarded,
      createdAt: order.createdAt,
    );
  }

  @override
  Future<OrderModel> confirmRelay(int id, int machineId) async {
    relayedOrderId = id;
    relayedMachineId = machineId;

    final order = orders.firstWhere((o) => o.id == id);
    return OrderModel(
      id: order.id,
      orderCode: order.orderCode,
      userId: order.userId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      memberCode: order.memberCode,
      customerTier: order.customerTier,
      customerCurrentTier: order.customerCurrentTier,
      serviceId: order.serviceId,
      serviceName: order.serviceName,
      pricePerKg: order.pricePerKg,
      requiresMachine: order.requiresMachine,
      machineId: machineId,
      machineCode: 'MC-01',
      weight: order.weight,
      subtotalPrice: order.subtotalPrice,
      discountAmount: order.discountAmount,
      totalPrice: order.totalPrice,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      status: 'proses_cuci',
      queueWaitMinutes: 0,
      pointsAwarded: order.pointsAwarded,
      createdAt: order.createdAt,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  OrderModel createFakeOrder({
    required int id,
    required String code,
    required String customerName,
    required String status,
    int? machineId,
    String? machineCode,
    int queueWait = 0,
    String paymentStatus = 'lunas',
    String paymentMethod = 'tunai',
  }) {
    return OrderModel(
      id: id,
      orderCode: code,
      userId: 10 + id,
      customerName: customerName,
      customerPhone: '081234567890',
      memberCode: 'MBR-000$id',
      customerTier: 'Gold',
      customerCurrentTier: 'Gold',
      serviceId: 1,
      serviceName: 'Cuci Komplit Reguler',
      pricePerKg: 7000,
      requiresMachine: true,
      machineId: machineId,
      machineCode: machineCode,
      weight: 3.5,
      subtotalPrice: 24500,
      discountAmount: 0,
      totalPrice: 24500,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      status: status,
      queueWaitMinutes: queueWait,
      pointsAwarded: 2,
      createdAt: DateTime.now(),
    );
  }

  group('KasirOrdersScreen (M5)', () {
    testWidgets('menampilkan filter tab, daftar pesanan, status badge dan info mesin', (tester) async {
      final mock = MockOrderService(initialOrders: [
        createFakeOrder(id: 1, code: 'CLN-20261120-0001', customerName: 'Rina Marlina', status: 'proses_cuci', machineId: 1, machineCode: 'MC-01'),
        createFakeOrder(id: 2, code: 'CLN-20261120-0002', customerName: 'Budi Santoso', status: 'antre', queueWait: 25),
        createFakeOrder(id: 3, code: 'CLN-20261120-0003', customerName: 'Dewi Lestari', status: 'siap_diambil'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: KasirOrdersScreen(orderService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Cek judul layar
      expect(find.text('Pesanan & Estafet'), findsOneWidget);

      // Cek semua tab filter (bisa muncul juga di status badge)
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Antre'), findsWidgets);
      expect(find.text('Proses Cuci'), findsWidgets);
      expect(find.text('Siap Diambil'), findsWidgets);
      expect(find.text('Selesai'), findsOneWidget);

      // Cek pesanan muncul
      expect(find.text('CLN-20261120-0001'), findsOneWidget);
      expect(find.text('Rina Marlina'), findsOneWidget);
      expect(find.textContaining('Mesin: MC-01'), findsOneWidget);

      expect(find.text('CLN-20261120-0002'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.textContaining('~25 menit'), findsOneWidget);

      expect(find.text('CLN-20261120-0003'), findsOneWidget);
      expect(find.text('Dewi Lestari'), findsOneWidget);

      // Cek tombol aksi
      expect(find.text('Tandai Siap Diambil'), findsOneWidget);
      expect(find.text('Selesaikan Pesanan'), findsOneWidget);
    });

    testWidgets('mengubah tab filter memanggil getOrders dengan status yang sesuai', (tester) async {
      final mock = MockOrderService(initialOrders: [
        createFakeOrder(id: 1, code: 'CLN-001', customerName: 'Rina', status: 'proses_cuci', machineId: 1, machineCode: 'MC-01'),
        createFakeOrder(id: 2, code: 'CLN-002', customerName: 'Budi', status: 'antre'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: KasirOrdersScreen(orderService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 'Semua' aktif awal -> 2 order
      expect(find.text('CLN-001'), findsOneWidget);
      expect(find.text('CLN-002'), findsOneWidget);

      // Klik tab 'Antre' menggunakan widgetWithText InkWell
      await tester.tap(find.widgetWithText(InkWell, 'Antre'));
      await tester.pumpAndSettle();

      expect(mock.lastStatusFilter, 'antre');
      expect(find.text('CLN-002'), findsOneWidget);
      expect(find.text('CLN-001'), findsNothing);
    });

    testWidgets('tombol "Tandai Siap Diambil" memicu dialog estafet saat ada antrean berikutnya', (tester) async {
      final orderProsesCuci = createFakeOrder(
        id: 1,
        code: 'CLN-20261120-0001',
        customerName: 'Rina Marlina',
        status: 'proses_cuci',
        machineId: 2,
        machineCode: 'MC-02',
      );
      final orderAntre = createFakeOrder(
        id: 5,
        code: 'CLN-20261120-0005',
        customerName: 'Ahmad Faiz',
        status: 'antre',
      );

      final mock = MockOrderService(initialOrders: [orderProsesCuci, orderAntre]);

      // Mock hasil updateStatus yang menyertakan next_queue_order
      mock.customUpdateResult = OrderModel(
        id: orderProsesCuci.id,
        orderCode: orderProsesCuci.orderCode,
        userId: orderProsesCuci.userId,
        customerName: orderProsesCuci.customerName,
        customerPhone: orderProsesCuci.customerPhone,
        memberCode: orderProsesCuci.memberCode,
        customerTier: orderProsesCuci.customerTier,
        customerCurrentTier: orderProsesCuci.customerCurrentTier,
        serviceId: orderProsesCuci.serviceId,
        serviceName: orderProsesCuci.serviceName,
        pricePerKg: orderProsesCuci.pricePerKg,
        requiresMachine: orderProsesCuci.requiresMachine,
        machineId: null,
        machineCode: null,
        weight: orderProsesCuci.weight,
        subtotalPrice: orderProsesCuci.subtotalPrice,
        discountAmount: orderProsesCuci.discountAmount,
        totalPrice: orderProsesCuci.totalPrice,
        paymentMethod: orderProsesCuci.paymentMethod,
        paymentStatus: orderProsesCuci.paymentStatus,
        status: 'siap_diambil',
        queueWaitMinutes: 0,
        pointsAwarded: orderProsesCuci.pointsAwarded,
        createdAt: orderProsesCuci.createdAt,
        nextQueueOrder: const NextQueueOrderModel(
          id: 5,
          orderCode: 'CLN-20261120-0005',
          weight: 4.2,
          customerName: 'Ahmad Faiz',
          serviceName: 'Cuci Kering Setrika',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KasirOrdersScreen(orderService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Klik tombol Tandai Siap Diambil
      final markReadyBtn = find.text('Tandai Siap Diambil');
      expect(markReadyBtn, findsOneWidget);
      await tester.tap(markReadyBtn);
      await tester.pumpAndSettle();

      // Verifikasi updateStatus dipanggil
      expect(mock.updatedOrderId, 1);
      expect(mock.updatedStatus, 'siap_diambil');

      // Verifikasi Modal Estafet muncul
      expect(find.text('Mesin MC-02 Kini Kosong!'), findsOneWidget);
      expect(find.text('Ahmad Faiz'), findsWidgets);
      expect(find.text('Cuci Kering Setrika • 4,20 kg'), findsOneWidget);
      expect(find.text('Ya, Mulai Cuci Sekarang'), findsOneWidget);
      expect(find.text('Nanti Saja'), findsOneWidget);

      // Klik "Ya, Mulai Cuci Sekarang"
      await tester.tap(find.text('Ya, Mulai Cuci Sekarang'));
      await tester.pumpAndSettle();

      // Verifikasi confirmRelay dipanggil dengan id antrean 5 dan machineId 2
      expect(mock.relayedOrderId, 5);
      expect(mock.relayedMachineId, 2);
    });

    testWidgets('tombol "Selesaikan Pesanan" menampilkan konfirmasi dan memanggil updateStatus', (tester) async {
      final mock = MockOrderService(initialOrders: [
        createFakeOrder(
          id: 3,
          code: 'CLN-20261120-0003',
          customerName: 'Dewi Lestari',
          status: 'siap_diambil',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: KasirOrdersScreen(orderService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Klik tombol Selesaikan Pesanan
      final completeBtn = find.text('Selesaikan Pesanan');
      expect(completeBtn, findsOneWidget);
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      // Dialog konfirmasi muncul
      expect(find.text('Selesaikan Pesanan?'), findsOneWidget);
      expect(find.text('Ya, Selesaikan'), findsOneWidget);

      // Konfirmasi
      await tester.tap(find.text('Ya, Selesaikan'));
      await tester.pumpAndSettle();

      expect(mock.updatedOrderId, 3);
      expect(mock.updatedStatus, 'selesai');
    });

    testWidgets('order sedang_diproses punya label badge dan tombol Siap Diambil', (tester) async {
      final mock = MockOrderService(initialOrders: [
        createFakeOrder(
          id: 9,
          code: 'CLN-20261120-0009',
          customerName: 'Sari Utami',
          status: 'sedang_diproses',
        ),
      ]);

      await tester.pumpWidget(MaterialApp(home: KasirOrdersScreen(orderService: mock)));
      await tester.pumpAndSettle();

      // Badge tidak boleh menampilkan enum mentah.
      expect(find.text('Sedang Diproses'), findsWidgets);
      expect(find.text('sedang_diproses'), findsNothing);

      // Dan ada jalan maju: sedang_diproses -> siap_diambil.
      final readyBtn = find.text('Tandai Siap Diambil');
      expect(readyBtn, findsOneWidget);
      await tester.tap(readyBtn);
      await tester.pumpAndSettle();

      expect(mock.updatedOrderId, 9);
      expect(mock.updatedStatus, 'siap_diambil');
    });

    testWidgets('kata kunci pencarian dikirim ke server, bukan disaring di klien', (tester) async {
      final mock = MockOrderService(initialOrders: [
        createFakeOrder(id: 1, code: 'CLN-001', customerName: 'Rina', status: 'proses_cuci'),
        createFakeOrder(id: 2, code: 'CLN-002', customerName: 'Budi', status: 'proses_cuci'),
      ]);

      await tester.pumpWidget(MaterialApp(home: KasirOrdersScreen(orderService: mock)));
      await tester.pumpAndSettle();
      expect(mock.lastSearch, isNull);

      await tester.enterText(find.byType(TextField), 'budi');
      // Debounce 350 ms: sebelum lewat, server belum dipanggil lagi.
      await tester.pump(const Duration(milliseconds: 200));
      expect(mock.lastSearch, isNull);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(mock.lastSearch, 'budi');
      expect(find.text('CLN-002'), findsOneWidget);
      expect(find.text('CLN-001'), findsNothing);

      // Tombol hapus mengembalikan daftar penuh tanpa kata kunci.
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(mock.lastSearch, isNull);
      expect(find.text('CLN-001'), findsOneWidget);
    });

    testWidgets('respons lama tidak menimpa hasil filter terbaru', (tester) async {
      final mock = MockOrderService(initialOrders: [
        createFakeOrder(id: 1, code: 'CLN-ANTRE', customerName: 'Antre', status: 'antre'),
        createFakeOrder(id: 2, code: 'CLN-CUCI', customerName: 'Cuci', status: 'proses_cuci'),
      ]);
      // Panggilan 0 (muat awal) langsung lolos; panggilan 1 & 2 ditahan.
      mock.gates.addAll([Completer<void>()..complete(), Completer<void>(), Completer<void>()]);

      await tester.pumpWidget(MaterialApp(home: KasirOrdersScreen(orderService: mock)));
      await tester.pumpAndSettle();
      expect(find.text('CLN-ANTRE'), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Antre'));
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, 'Proses Cuci'));
      await tester.pump();

      // Respons terbaru (Proses Cuci) datang lebih dulu.
      mock.gates[2].complete();
      await tester.pumpAndSettle();
      expect(find.text('CLN-CUCI'), findsOneWidget);

      // Respons lama (Antre) baru tiba setelahnya — harus dibuang.
      mock.gates[1].complete();
      await tester.pumpAndSettle();
      expect(find.text('CLN-CUCI'), findsOneWidget);
      expect(find.text('CLN-ANTRE'), findsNothing);
    });
  });
}
