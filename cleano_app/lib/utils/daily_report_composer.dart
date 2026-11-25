import '../core/utils/formatters.dart';
import '../models/dashboard_summary_model.dart';
import '../models/order_model.dart';

/// Isi laporan harian: pesanan hari ini dan pembandingnya terhadap rata-rata
/// tujuh hari terakhir.
class DailyReportContent {
  const DailyReportContent({
    required this.orders,
    required this.totalToday,
    required this.transactionCount,
    required this.comparisonLabel,
  });

  /// Hanya pesanan yang dibuat pada hari yang diminta.
  final List<OrderModel> orders;
  final int totalToday;
  final int transactionCount;

  /// Contoh: "+Rp 50.000 vs rata-rata 7 hari", atau "Belum ada pembanding".
  final String comparisonLabel;
}

/// Penyusun isi laporan harian. Fungsi murni tanpa I/O, sehingga bisa diuji
/// tanpa widget.
///
/// Berkasnya sendiri ditulis oleh [ExportService], memakai jalur ekspor yang
/// sama dengan tombol "Unduh Rekap". Yang berbeda hanya cakupan datanya: satu
/// hari, bukan seluruh pesanan aktif.
class DailyReportComposer {
  const DailyReportComposer._();

  static DailyReportContent compose({
    required DashboardSummaryModel summary,
    required List<OrderModel> orders,
    required DateTime day,
  }) {
    final todayOrders = orders.where((o) => _isSameDay(o.createdAt, day)).toList();
    final totalToday = todayOrders.fold<int>(0, (sum, o) => sum + o.totalPrice);

    final revenue7 = summary.revenue7Days;
    final avg7 = revenue7.isEmpty
        ? 0
        : (revenue7.fold<int>(0, (s, d) => s + d.dailyRevenue) / revenue7.length).round();

    final selisih = totalToday - avg7;
    final comparisonLabel = avg7 <= 0
        ? 'Belum ada pembanding'
        : selisih >= 0
            ? '+${Formatters.rupiah(selisih)} vs rata-rata 7 hari'
            : '${Formatters.rupiah(selisih)} vs rata-rata 7 hari';

    return DailyReportContent(
      orders: todayOrders,
      totalToday: totalToday,
      transactionCount: todayOrders.length,
      comparisonLabel: comparisonLabel,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
