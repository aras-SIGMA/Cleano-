import '../core/constants/api_constants.dart';
import '../models/reward_model.dart';
import '../models/voucher_model.dart';
import 'api_service.dart';

/// Hasil pembacaan daftar voucher pelanggan (aktif vs riwayat terpakai).
class MyVouchersResult {
  const MyVouchersResult({
    required this.active,
    required this.history,
    required this.total,
  });

  final List<VoucherModel> active;
  final List<VoucherModel> history;
  final int total;
}

/// Service katalog promo rewards, penukaran poin, dan riwayat voucher pelanggan.
class RewardService {
  RewardService({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  static final RewardService instance = RewardService();
  final ApiService _api;

  /// Membaca katalog promo reward yang aktif untuk ditukar pelanggan.
  Future<List<RewardModel>> getCatalog() async {
    final res = await _api.get(
      ApiConstants.rewards,
      query: {'is_active': 1},
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

  /// Menukarkan poin pelanggan dengan voucher reward baru.
  Future<VoucherModel> redeem(int rewardId) async {
    final res = await _api.post(
      ApiConstants.rewardRedeem,
      data: {'reward_id': rewardId},
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      final data = payload['data'] as Map<String, dynamic>;
      final rawVoucher = data['voucher'];
      if (rawVoucher is Map<String, dynamic>) {
        return VoucherModel.fromJson(rawVoucher);
      }
    }
    throw const ApiException('Gagal menukarkan poin reward.');
  }

  /// Membaca seluruh voucher milik pelanggan yang sedang login (aktif vs sudah terpakai).
  Future<MyVouchersResult> getMyVouchers() async {
    final res = await _api.get(ApiConstants.rewardMyVouchers);
    final payload = res.data;

    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      final data = payload['data'] as Map<String, dynamic>;

      final rawActive = data['active'];
      List<VoucherModel> activeList = [];
      if (rawActive is List) {
        activeList = rawActive
            .whereType<Map<String, dynamic>>()
            .map((v) => VoucherModel.fromJson(v))
            .toList();
      }

      final rawHistory = data['history'];
      List<VoucherModel> historyList = [];
      if (rawHistory is List) {
        historyList = rawHistory
            .whereType<Map<String, dynamic>>()
            .map((v) => VoucherModel.fromJson(v))
            .toList();
      }

      final total = data['total'] is int ? data['total'] as int : (activeList.length + historyList.length);

      return MyVouchersResult(active: activeList, history: historyList, total: total);
    }

    return const MyVouchersResult(active: [], history: [], total: 0);
  }
}
