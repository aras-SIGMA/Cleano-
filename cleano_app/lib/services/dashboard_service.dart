import '../core/constants/api_constants.dart';
import '../models/dashboard_summary_model.dart';
import 'api_service.dart';

/// Service ringkasan dashboard metrik kasir (omzet, pesanan aktif, mesin, grafik 7 hari).
class DashboardService {
  DashboardService({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  static final DashboardService instance = DashboardService();
  final ApiService _api;

  /// Membaca ringkasan 4 kartu metrik dan tren omzet 7 hari terakhir.
  Future<DashboardSummaryModel> getSummary() async {
    final res = await _api.get(ApiConstants.dashboardSummary);
    final payload = res.data;

    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return DashboardSummaryModel.fromJson(payload['data'] as Map<String, dynamic>);
    }

    throw const ApiException('Gagal memuat ringkasan dashboard.');
  }
}
