import '../core/constants/api_constants.dart';
import '../models/machine_model.dart';
import '../models/reward_model.dart';
import '../models/service_model.dart';
import 'api_service.dart';

/// Service manajemen master data outlet (Layanan, Mesin, dan Promo Rewards)
/// dengan in-memory caching untuk mengurangi query redundan dan meningkatkan responsivitas POS.
class MasterService {
  MasterService({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  static final MasterService instance = MasterService();
  final ApiService _api;

  // In-memory cache
  List<ServiceModel>? _cachedServices;
  DateTime? _servicesCacheTime;

  List<MachineModel>? _cachedMachines;
  DateTime? _machinesCacheTime;

  static const _cacheDuration = Duration(minutes: 3);

  void invalidateCache() {
    _cachedServices = null;
    _servicesCacheTime = null;
    _cachedMachines = null;
    _machinesCacheTime = null;
  }

  // ==========================================
  // MASTER LAYANAN
  // ==========================================

  Future<List<ServiceModel>> getServices({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedServices != null &&
        _servicesCacheTime != null &&
        now.difference(_servicesCacheTime!) < _cacheDuration) {
      return _cachedServices!;
    }

    final res = await _api.get(ApiConstants.services);
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      final list = (payload['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => ServiceModel.fromJson(m))
          .toList();
      _cachedServices = list;
      _servicesCacheTime = now;
      return list;
    }
    return [];
  }

  Future<ServiceModel> createService({
    required String name,
    required int pricePerKg,
    required int washDurationMinutes,
    required int estimatedHours,
    required bool requiresMachine,
    String? description,
  }) async {
    final res = await _api.post(
      ApiConstants.services,
      data: {
        'name': name.trim(),
        'price_per_kg': pricePerKg,
        'wash_duration_minutes': washDurationMinutes,
        'estimated_hours': estimatedHours,
        'requires_machine': requiresMachine ? 1 : 0,
        if (description != null && description.isNotEmpty) 'description': description.trim(),
      },
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      invalidateCache();
      return ServiceModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal menambahkan layanan baru.');
  }

  Future<ServiceModel> updateService(
    int id, {
    required String name,
    required int pricePerKg,
    required int washDurationMinutes,
    required int estimatedHours,
    required bool requiresMachine,
    String? description,
  }) async {
    final res = await _api.put(
      '${ApiConstants.services}/$id',
      data: {
        'name': name.trim(),
        'price_per_kg': pricePerKg,
        'wash_duration_minutes': washDurationMinutes,
        'estimated_hours': estimatedHours,
        'requires_machine': requiresMachine ? 1 : 0,
        'description': description?.trim(),
      },
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      invalidateCache();
      return ServiceModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal memperbarui data layanan.');
  }

  Future<void> deleteService(int id) async {
    await _api.delete('${ApiConstants.services}/$id');
    invalidateCache();
  }

  // ==========================================
  // MASTER MESIN
  // ==========================================

  Future<List<MachineModel>> getMachines({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedMachines != null &&
        _machinesCacheTime != null &&
        now.difference(_machinesCacheTime!) < _cacheDuration) {
      return _cachedMachines!;
    }

    final res = await _api.get(ApiConstants.machines);
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      final list = (payload['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => MachineModel.fromJson(m))
          .toList();
      _cachedMachines = list;
      _machinesCacheTime = now;
      return list;
    }
    return [];
  }

  Future<MachineModel> createMachine({
    required String machineCode,
    required double capacityKg,
    String status = 'tersedia',
  }) async {
    final res = await _api.post(
      ApiConstants.machines,
      data: {
        'machine_code': machineCode.trim().toUpperCase(),
        'capacity_kg': capacityKg,
        'status': status,
      },
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      invalidateCache();
      return MachineModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal menambahkan mesin baru.');
  }

  Future<MachineModel> updateMachine(
    int id, {
    String? status,
    DateTime? estimatedFinishAt,
  }) async {
    final res = await _api.patch(
      '${ApiConstants.machines}/$id',
      data: {
        'status': ?status,
        if (estimatedFinishAt != null)
          'estimated_finish_at':
              '${estimatedFinishAt.toIso8601String().substring(0, 10)} ${estimatedFinishAt.toIso8601String().substring(11, 19)}',
      },
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      invalidateCache();
      return MachineModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal memperbarui data mesin.');
  }

  // ==========================================
  // MASTER REWARDS
  // ==========================================

  Future<List<RewardModel>> getRewards({bool onlyActive = false}) async {
    final res = await _api.get(
      ApiConstants.rewards,
      query: onlyActive ? {'is_active': 1} : null,
    );
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      return (payload['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => RewardModel.fromJson(m))
          .toList();
    }
    return [];
  }

  Future<RewardModel> createReward({
    required String title,
    String? description,
    required int pointsRequired,
    required int discountAmount,
    bool isActive = true,
  }) async {
    final res = await _api.post(
      ApiConstants.rewards,
      data: {
        'title': title.trim(),
        'description': description?.trim(),
        'points_required': pointsRequired,
        'discount_amount': discountAmount,
        'is_active': isActive ? 1 : 0,
      },
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return RewardModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal menambahkan promo reward.');
  }

  Future<RewardModel> updateReward(
    int id, {
    required String title,
    String? description,
    required int pointsRequired,
    required int discountAmount,
  }) async {
    final res = await _api.put(
      '${ApiConstants.rewards}/$id',
      data: {
        'title': title.trim(),
        'description': description?.trim(),
        'points_required': pointsRequired,
        'discount_amount': discountAmount,
      },
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return RewardModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal memperbarui promo reward.');
  }

  Future<RewardModel> toggleRewardActive(int id) async {
    final res = await _api.patch('${ApiConstants.rewards}/$id/toggle');
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return RewardModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal mengubah status aktif reward.');
  }
}
