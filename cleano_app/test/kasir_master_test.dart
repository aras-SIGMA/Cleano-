import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/core/theme/app_theme.dart';
import 'package:cleano_app/models/machine_model.dart';
import 'package:cleano_app/models/reward_model.dart';
import 'package:cleano_app/models/service_model.dart';
import 'package:cleano_app/screens/kasir/kasir_master_screen.dart';
import 'package:cleano_app/services/api_service.dart';
import 'package:cleano_app/services/master_service.dart';

class MockMasterService implements MasterService {
  MockMasterService({
    List<ServiceModel>? services,
    List<MachineModel>? machines,
    List<RewardModel>? rewards,
  })  : _services = services ?? [],
        _machines = machines ?? [],
        _rewards = rewards ?? [];

  final List<ServiceModel> _services;
  final List<MachineModel> _machines;
  final List<RewardModel> _rewards;

  int? deletedServiceId;
  int? updatedMachineId;
  String? updatedMachineStatus;
  int? toggledRewardId;
  bool shouldThrow409OnDelete = false;

  String? createdServiceName;
  int? createdServicePrice;
  int? updatedServiceId;
  int? updatedServicePrice;

  @override
  Future<ServiceModel> createService({
    required String name,
    required int pricePerKg,
    required int washDurationMinutes,
    required int estimatedHours,
    required bool requiresMachine,
    String? description,
  }) async {
    createdServiceName = name;
    createdServicePrice = pricePerKg;
    final created = ServiceModel(
      id: _services.length + 1,
      name: name,
      pricePerKg: pricePerKg,
      washDurationMinutes: washDurationMinutes,
      estimatedHours: estimatedHours,
      requiresMachine: requiresMachine,
      description: description,
    );
    _services.add(created);
    return created;
  }

  @override
  Future<ServiceModel> updateService(
    int id, {
    String? name,
    int? pricePerKg,
    int? washDurationMinutes,
    int? estimatedHours,
    bool? requiresMachine,
    String? description,
  }) async {
    updatedServiceId = id;
    updatedServicePrice = pricePerKg;
    final s = _services.firstWhere((x) => x.id == id);
    final updated = ServiceModel(
      id: s.id,
      name: name ?? s.name,
      pricePerKg: pricePerKg ?? s.pricePerKg,
      washDurationMinutes: washDurationMinutes ?? s.washDurationMinutes,
      estimatedHours: estimatedHours ?? s.estimatedHours,
      requiresMachine: requiresMachine ?? s.requiresMachine,
      description: description ?? s.description,
    );
    _services[_services.indexWhere((x) => x.id == id)] = updated;
    return updated;
  }

  @override
  Future<List<ServiceModel>> getServices({bool forceRefresh = false}) async {
    return _services;
  }

  @override
  Future<List<MachineModel>> getMachines({bool forceRefresh = false}) async {
    return _machines;
  }

  @override
  Future<List<RewardModel>> getRewards({bool onlyActive = false}) async {
    return onlyActive ? _rewards.where((r) => r.isActive).toList() : _rewards;
  }

  @override
  Future<void> deleteService(int id) async {
    if (shouldThrow409OnDelete) {
      throw const ApiException('Layanan masih digunakan.', statusCode: 409);
    }
    deletedServiceId = id;
    _services.removeWhere((s) => s.id == id);
  }

  @override
  Future<MachineModel> updateMachine(int id, {String? status, DateTime? estimatedFinishAt}) async {
    updatedMachineId = id;
    updatedMachineStatus = status;
    final m = _machines.firstWhere((x) => x.id == id);
    final updated = MachineModel(
      id: m.id,
      machineCode: m.machineCode,
      status: status ?? m.status,
      capacityKg: m.capacityKg,
      estimatedFinishAt: estimatedFinishAt ?? m.estimatedFinishAt,
    );
    final idx = _machines.indexWhere((x) => x.id == id);
    _machines[idx] = updated;
    return updated;
  }

  @override
  Future<RewardModel> toggleRewardActive(int id) async {
    toggledRewardId = id;
    final r = _rewards.firstWhere((x) => x.id == id);
    final updated = RewardModel(
      id: r.id,
      title: r.title,
      description: r.description,
      pointsRequired: r.pointsRequired,
      discountAmount: r.discountAmount,
      isActive: !r.isActive,
    );
    final idx = _rewards.indexWhere((x) => x.id == id);
    _rewards[idx] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('KasirMasterScreen (M6)', () {
    testWidgets('menampilkan 3 tab pill dan memuat daftar layanan pada tab awal', (tester) async {
      final mock = MockMasterService(
        services: [
          const ServiceModel(
            id: 1,
            name: 'Cuci Komplit Reguler',
            pricePerKg: 7000,
            washDurationMinutes: 45,
            estimatedHours: 24,
            requiresMachine: true,
            description: 'Cuci bersih, wangi, rapi',
          ),
          const ServiceModel(
            id: 2,
            name: 'Setrika & Lipat Saja',
            pricePerKg: 4000,
            washDurationMinutes: 0,
            estimatedHours: 12,
            requiresMachine: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Cek judul
      expect(find.text('Kelola Toko'), findsOneWidget);

      // Cek 3 tab pill
      expect(find.textContaining('Layanan ('), findsOneWidget);
      expect(find.textContaining('Mesin ('), findsOneWidget);
      expect(find.textContaining('Rewards ('), findsOneWidget);

      // Cek konten layanan
      expect(find.text('Cuci Komplit Reguler'), findsOneWidget);
      expect(find.text('Setrika & Lipat Saja'), findsOneWidget);
      expect(find.text('Pakai Mesin'), findsOneWidget);
      expect(find.text('Tanpa Mesin'), findsOneWidget);
      expect(find.text('Rp 7.000 / kg'), findsOneWidget);

      // Cek FAB
      expect(find.text('Layanan Baru'), findsOneWidget);
    });

    testWidgets('berpindah ke Tab Mesin dan mengubah status operasional mesin', (tester) async {
      final mock = MockMasterService(
        machines: [
          const MachineModel(
            id: 1,
            machineCode: 'MC-01',
            status: 'tersedia',
            capacityKg: 7.0,
          ),
          const MachineModel(
            id: 2,
            machineCode: 'MC-02',
            status: 'digunakan',
            capacityKg: 10.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Klik tab Mesin
      await tester.tap(find.textContaining('Mesin'));
      await tester.pumpAndSettle();

      // Cek daftar mesin
      expect(find.text('MC-01'), findsOneWidget);
      expect(find.text('MC-02'), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);
      expect(find.text('Sedang Digunakan'), findsOneWidget);

      // Mesin tersedia punya tombol 'Perawatan'
      final maintBtn = find.text('Perawatan');
      expect(maintBtn, findsOneWidget);

      await tester.tap(maintBtn);
      await tester.pumpAndSettle();

      // Dialog konfirmasi ubah status muncul
      expect(find.text('Ubah Status'), findsOneWidget);
      await tester.tap(find.text('Ubah Status'));
      await tester.pumpAndSettle();

      // Verifikasi updateMachine terpanggil dengan maintenance
      expect(mock.updatedMachineId, 1);
      expect(mock.updatedMachineStatus, 'maintenance');
    });

    // Uji regresi: tombol Perawatan di Row tidak error lebar tak terbatas.
    testWidgets('tab mesin ter-render dengan tema aplikasi (tombol lebar terbatas)',
        (tester) async {
      final mock = MockMasterService(
        machines: [
          const MachineModel(
            id: 1,
            machineCode: 'MC-01',
            status: 'tersedia',
            capacityKg: 8.0,
          ),
          const MachineModel(
            id: 4,
            machineCode: 'MC-04',
            status: 'maintenance',
            capacityKg: 7.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mesin'));
      await tester.pumpAndSettle();

      // Kedua tombol harus ada dan frame harus selesai tanpa exception layout.
      expect(tester.takeException(), isNull);
      expect(find.text('Perawatan'), findsOneWidget);
      expect(find.text('Aktifkan'), findsOneWidget);
    });

    testWidgets('berpindah ke Tab Rewards dan men-toggle status aktif kupon', (tester) async {
      final mock = MockMasterService(
        rewards: [
          const RewardModel(
            id: 1,
            title: 'Potongan Hemat Rp 5.000',
            description: 'Kupon promo cuci hemat',
            pointsRequired: 100,
            discountAmount: 5000,
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Klik tab Rewards
      await tester.tap(find.textContaining('Rewards'));
      await tester.pumpAndSettle();

      // Cek item reward
      expect(find.text('Potongan Hemat Rp 5.000'), findsOneWidget);
      expect(find.text('100 Poin'), findsOneWidget);
      expect(find.text('Potongan Rp 5.000'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);

      // Klik tombol Nonaktifkan
      final toggleBtn = find.text('Nonaktifkan');
      expect(toggleBtn, findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(mock.toggledRewardId, 1);
    });

    testWidgets('menghapus layanan yang masih dipakai pesanan menampilkan pesan edukatif 409', (tester) async {
      final mock = MockMasterService(
        services: [
          const ServiceModel(
            id: 1,
            name: 'Cuci Komplit Reguler',
            pricePerKg: 7000,
            washDurationMinutes: 45,
            estimatedHours: 24,
            requiresMachine: true,
          ),
        ],
      );
      mock.shouldThrow409OnDelete = true;

      await tester.pumpWidget(
        MaterialApp(
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      // Klik Hapus
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Konfirmasi dialog
      expect(find.text('Hapus Layanan?'), findsOneWidget);
      final confirmHapusBtn = find.widgetWithText(ElevatedButton, 'Hapus');
      await tester.tap(confirmHapusBtn);
      await tester.pumpAndSettle();

      // Muncul pesan snackbar 409 yang ramah
      expect(
        find.textContaining('Layanan tidak dapat dihapus karena masih tercatat'),
        findsOneWidget,
      );
    });

    testWidgets('form layanan baru mengirim data ke server dan menyegarkan daftar', (tester) async {
      final mock = MockMasterService();

      await tester.pumpWidget(
        MaterialApp(
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Layanan Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Layanan Baru'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Nama Layanan *'), 'Cuci Selimut');
      await tester.enterText(find.widgetWithText(TextField, 'Tarif / kg (Rp) *'), '9000');
      await tester.tap(find.text('Simpan Layanan'));
      await tester.pumpAndSettle();

      expect(mock.createdServiceName, 'Cuci Selimut');
      expect(mock.createdServicePrice, 9000);
      expect(find.text('Layanan berhasil ditambahkan.'), findsOneWidget);
      expect(find.text('Cuci Selimut'), findsOneWidget);
    });

    testWidgets('form edit layanan mengirim id dan tarif baru', (tester) async {
      final mock = MockMasterService(
        services: [
          const ServiceModel(
            id: 7,
            name: 'Cuci Komplit Reguler',
            pricePerKg: 7000,
            washDurationMinutes: 45,
            estimatedHours: 24,
            requiresMachine: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KasirMasterScreen(masterService: mock),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Layanan'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Tarif / kg (Rp) *'), '8500');
      await tester.tap(find.text('Perbarui Layanan'));
      await tester.pumpAndSettle();

      expect(mock.updatedServiceId, 7);
      expect(mock.updatedServicePrice, 8500);
      expect(find.text('Rp 8.500 / kg'), findsOneWidget);
    });
  });
}
