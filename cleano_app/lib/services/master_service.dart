import '../core/constants/api_constants.dart';
import '../models/machine_model.dart';
import '../models/reward_model.dart';
import '../models/service_model.dart';
import 'api_service.dart';

/// Service manajemen master data outlet (Layanan, Mesin, dan Promo Rewards).
class MasterService {
  MasterService({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  static final MasterService instance = MasterService();
  final ApiService _api;

  // ==========================================
  // MASTER LAYANAN
  // ==========================================

  Future<List<ServiceModel>> getServices() async {
    final res = await _api.get(ApiConstants.services);
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      return (payload['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => ServiceModel.fromJson(m))
          .toList();
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
      return ServiceModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal memperbarui data layanan.');
  }

  Future<void> deleteService(int id) async {
    await _api.delete('${ApiConstants.services}/$id');
  }

  // ==========================================
  // MASTER MESIN
  // ==========================================

  Future<List<MachineModel>> getMachines() async {
    final res = await _api.get(ApiConstants.machines);
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      return (payload['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => MachineModel.fromJson(m))
          .toList();
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
