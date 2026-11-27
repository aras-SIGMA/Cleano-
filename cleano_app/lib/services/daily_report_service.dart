import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_summary_model.dart';
import '../models/order_model.dart';

/// Penjaga pengiriman laporan harian kasir maksimal satu kali per hari.
class DailyReportService {
  DailyReportService(
    this._prefs, {
    required this.onDailyReportReady,
  });

  static const String _lastReportDateKey = 'cleano_last_report_date';

  final SharedPreferences _prefs;
  final DailyReportReadyCallback onDailyReportReady;

  /// Buat laporan harian sekali sehari saat dibuka; kembalikan true jika sukses.
  Future<bool> maybeRunDaily({
    required DashboardSummaryModel summary,
    required List<OrderModel> orders,
  }) async {
    final today = _todayString();
    final last = _prefs.getString(_lastReportDateKey);

    if (last == today) return false;

    try {
      await onDailyReportReady(summary: summary, orders: orders);
    } catch (_) {
      // Gagal = coba lagi besok. Jangan melempar ke pemanggil.
      return false;
    }

    // Tandai tanggal hanya setelah callback sukses.
    await _prefs.setString(_lastReportDateKey, today);
    return true;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Callback saat laporan harian siap diekspor.
typedef DailyReportReadyCallback = Future<void> Function({
  required DashboardSummaryModel summary,
  required List<OrderModel> orders,
});
