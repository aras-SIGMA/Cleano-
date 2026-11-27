import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/dashboard_summary_model.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../../services/daily_report_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/export_service.dart';
import '../../services/order_service.dart';
import '../../utils/daily_report_composer.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/state_view.dart';

/// Layar Dashboard Kasir dengan hero omzet, grafik, metrik, dan ekspor.
class KasirDashboardScreen extends StatefulWidget {
  const KasirDashboardScreen({
    super.key,
    this.onNavigateToOrders,
    this.dashboardService,
    this.orderService,
    this.exportService,
  });

  final VoidCallback? onNavigateToOrders;
  final DashboardService? dashboardService;
  final OrderService? orderService;
  final ExportService? exportService;

  @override
  State<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends State<KasirDashboardScreen> {
  DashboardService get _dashboardService => widget.dashboardService ?? DashboardService.instance;
  OrderService get _orderService => widget.orderService ?? OrderService.instance;
  ExportService get _exportService => widget.exportService ?? ExportService.instance;

  DashboardSummaryModel? _summary;
  List<OrderModel> _activeOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter internal daftar order aktif
  String _orderFilter = 'semua'; // 'semua' | 'antre' | 'proses_cuci'
  int _selectedPeriodIndex = 1; // 0: Hari Ini, 1: 7 Hari Terakhir, 2: Bulan Ini

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summaryFuture = _dashboardService.getSummary();
      final activeOrdersFuture = _orderService.getOrders(status: 'aktif', pageSize: 10);

      final results = await Future.wait([summaryFuture, activeOrdersFuture]);

      if (mounted) {
        setState(() {
          _summary = results[0] as DashboardSummaryModel;
          final orderResult = results[1] as OrderListResult;
          _activeOrders = orderResult.items;
          _isLoading = false;
        });
        unawaited(_maybeRunDailyReport());
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isEn = context.l10n.localeName == 'en';
        setState(() {
          _errorMessage = isEn ? 'Failed to load dashboard data: $e' : 'Gagal memuat data dashboard: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Kirim laporan harian otomatis sekali sehari saat dashboard berhasil dimuat.
  Future<void> _maybeRunDailyReport() async {
    final summary = _summary;
    if (summary == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final content = DailyReportComposer.compose(
        summary: summary,
        orders: _activeOrders,
        day: DateTime.now(),
      );

      final service = DailyReportService(
        prefs,
        onDailyReportReady: ({required summary, required orders}) =>
            _exportService.exportReport(format: 'PDF', summary: summary, orders: orders),
      );

      final ran = await service.maybeRunDaily(summary: summary, orders: content.orders);
      if (!ran || !mounted) return;
      final isEn = context.l10n.localeName == 'en';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Daily report ready to share — ${content.comparisonLabel}'
                : 'Laporan harian siap dibagikan — ${content.comparisonLabel}',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // Laporan otomatis bersifat tambahan; dashboard tidak boleh terganggu.
    }
  }

  void _showExportDialog() {
    if (_summary == null) return;
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final total7Hari = _summary!.revenue7Days.fold<int>(0, (sum, d) => sum + d.dailyRevenue);

    final summaryRows = [
      (isEn ? 'Today Revenue' : 'Omzet Hari Ini', Formatters.rupiah(_summary!.todayRevenue)),
      (isEn ? '7-Day Total Revenue' : 'Total Omzet 7 Hari', Formatters.rupiah(total7Hari)),
      (l10n.metricActiveOrders, isEn ? '${_summary!.activeOrders} Orders' : '${_summary!.activeOrders} Pesanan'),
      (
        isEn ? 'Machine Capacity' : 'Kapasitas Mesin',
        isEn
            ? '${_summary!.availableMachines} / ${_summary!.totalOperationalMachines} Available'
            : '${_summary!.availableMachines} / ${_summary!.totalOperationalMachines} Tersedia',
      ),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Future<void> triggerExport(String format) async {
          Navigator.pop(ctx);
          try {
            await _exportService.exportReport(
              format: format,
              summary: _summary!,
              orders: _activeOrders,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.exportSuccess(format)),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.exportFailed(e.toString())),
                  backgroundColor: AppTheme.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.exportModalTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Text(
                          l10n.exportModalSubtitle,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < summaryRows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _buildModalRow(summaryRows[i].$1, summaryRows[i].$2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => triggerExport('CSV'),
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: Text(l10n.exportCsv),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => triggerExport('PDF'),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(l10n.exportPdf),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.dashboardTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FrostedGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              borderRadius: 20,
              blurSigma: 12,
              onTap: _summary != null ? _showExportDialog : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.downloadRecap,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.download_rounded, size: 16, color: AppTheme.textPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _summary == null) {
      return _buildErrorState();
    }

    final summary = _summary!;
    final filtered = _activeOrders.where((order) {
      if (_orderFilter == 'antre') return order.isAntre;
      if (_orderFilter == 'proses_cuci') return order.isProsesCuci;
      return true;
    }).toList();

    // Batasi lebar konten dan pusatkan pada layar desktop agar proporsional.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Horizontal Date Range Pill Selector
                          _buildPeriodPills(),
                          const SizedBox(height: 18),

                          // 2. Hero Big Metric & Capsule Bar Chart
                          _buildHeroChartSection(summary),
                          const SizedBox(height: 18),

                          // 3. 2x2 Metric Cards Grid
                          _buildMetricCards(summary, isWide),
                          const SizedBox(height: 22),

                          // 4. Header Bar Filter Pesanan Aktif
                          _buildActiveOrdersHeader(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // 5. Daftar Pesanan Aktif — Virtualized Lazy SliverList untuk performa 60 FPS
                  _buildOrdersSliver(filtered),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 110),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() => StateErrorView(message: _errorMessage!, onRetry: _loadData);

  Widget _buildOrdersSliver(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: FrostedGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            borderRadius: 20,
            blurSigma: 14,
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.noActiveOrdersInCategory,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ActiveOrderCard(order: orders[index]),
      ),
    );
  }

  Widget _buildPeriodPills() {
    final l10n = context.l10n;
    final periods = [l10n.periodToday, l10n.period7Days, l10n.periodThisMonth];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(periods.length, (idx) {
          final isSelected = _selectedPeriodIndex == idx;
          return Padding(
            padding: EdgeInsets.only(right: idx < periods.length - 1 ? 8 : 0),
            child: InkWell(
              onTap: () => setState(() => _selectedPeriodIndex = idx),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.88),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.25)
                          : const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    periods[idx],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeroChartSection(DashboardSummaryModel summary) {
    final rev7 = summary.revenue7Days;
    final total7Hari = rev7.fold<int>(0, (sum, d) => sum + d.dailyRevenue);
    final avgDaily = rev7.isNotEmpty ? (total7Hari / rev7.length).round() : 0;

    double maxRevenue = 0;
    int maxIndex = -1;
    for (int i = 0; i < rev7.length; i++) {
      if (rev7[i].dailyRevenue > maxRevenue) {
        maxRevenue = rev7[i].dailyRevenue.toDouble();
        maxIndex = i;
      }
    }
    final maxY = maxRevenue > 0 ? maxRevenue * 1.3 : 100000.0;

    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      blurSigma: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(total7Hari, avgDaily),
          const SizedBox(height: 24),
          SizedBox(height: 180, child: _buildBarChart(rev7, maxIndex, maxY)),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(int total7Hari, int avgDaily) {
    final isEn = context.l10n.localeName == 'en';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? '7-Day Total Revenue' : 'Total Omzet 7 Hari',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Formatters.rupiah(total7Hari),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (avgDaily > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${isEn ? 'Average' : 'Rata-rata'}: ${Formatters.rupiah(avgDaily)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
      ],
    );
  }

  Widget _buildBarChart(List<DailyRevenueModel> rev7, int maxIndex, double maxY) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    if (rev7.isEmpty) {
      return Center(
        child: Text(
          l10n.noRevenue7Days,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    return RepaintBoundary(
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= rev7.length) return const SizedBox.shrink();
                  final item = rev7[idx];
                  final parsed = DateTime.tryParse(item.orderDate);
                  final label = parsed != null ? DateFormat('d MMM').format(parsed) : item.orderDate;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.primary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = rev7[group.x];
                final dateParsed = DateTime.tryParse(item.orderDate);
                final formattedDate = dateParsed != null
                    ? DateFormat('dd MMM', isEn ? 'en_US' : 'id_ID').format(dateParsed)
                    : item.orderDate;
                return BarTooltipItem(
                  '$formattedDate\n${Formatters.rupiah(item.dailyRevenue)}\n(${item.totalTransactions} ${isEn ? 'transactions' : 'transaksi'})',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          barGroups: List.generate(rev7.length, (i) {
            final val = rev7[i].dailyRevenue.toDouble();
            final isPeak = i == maxIndex;

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: isPeak ? AppTheme.primary : const Color(0xFF93C5FD),
                  width: 18,
                  borderRadius: BorderRadius.circular(9),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMetricCards(DashboardSummaryModel summary, bool isWide) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final orderUnit = isEn ? 'Orders' : 'Pesanan';
    final cards = [
      _MetricPillCard(
        label: l10n.metricTodayRevenue,
        value: Formatters.rupiah(summary.todayRevenue),
      ),
      _MetricPillCard(
        label: l10n.metricActiveOrders,
        value: '${summary.activeOrders}',
        unit: orderUnit,
      ),
      _MetricPillCard(
        label: l10n.metricReadyOrders,
        value: '${summary.readyOrders}',
        unit: orderUnit,
      ),
      _MetricPillCard(
        label: l10n.metricAvailableMachines,
        value: '${summary.availableMachines}/${summary.totalOperationalMachines}',
        unit: l10n.readyShort,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveOrdersHeader() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.activeOrdersTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (widget.onNavigateToOrders != null)
              TextButton(
                onPressed: widget.onNavigateToOrders,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primary,
                ),
                child: Text(l10n.seeAll, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: FrostedGlassCard(
            padding: const EdgeInsets.all(4),
            borderRadius: 24,
            blurSigma: 12,
            child: Row(
              children: [
                _buildTogglePill('semua', l10n.filterAllCount(_activeOrders.length)),
                const SizedBox(width: 4),
                _buildTogglePill('antre', l10n.filterWaitingMachine),
                const SizedBox(width: 4),
                _buildTogglePill('proses_cuci', l10n.filterWashing),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTogglePill(String key, String label) {
    final isSelected = _orderFilter == key;

    return InkWell(
      onTap: () => setState(() => _orderFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Kartu metrik 2x2 bergaya Frosted Glass untuk ringkasan operasional kasir.
class _MetricPillCard extends StatelessWidget {
  const _MetricPillCard({
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      blurSigma: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu pesanan aktif dengan efek Frosted Glass & badge status
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    return FrostedGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      blurSigma: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderCode,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
              _buildStatusBadge(context, order),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${order.customerName} • ${order.serviceName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Formatters.berat(order.weight),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (order.isAntre && order.queueWaitMinutes > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Queue est.: ~${order.queueWaitMinutes} mins'
                        : 'Estimasi antrean: ~${order.queueWaitMinutes} menit',
                    style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (order.isProsesCuci && order.machineCode != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.rotate_right_rounded, size: 12, color: AppTheme.secondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isEn ? 'Machine' : 'Mesin'}: ${order.machineCode}'
                    '${order.machineFinishAt != null ? ' (${isEn ? 'Done' : 'Selesai'} ~${Formatters.jam(order.machineFinishAt!)})' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, OrderModel order) {
    final l10n = context.l10n;
    final (bg, fg, text) = switch (order) {
      _ when order.isAntre => (const Color(0xFFFEF3C7), const Color(0xFFB45309), l10n.filterWaitingMachine),
      _ when order.isProsesCuci => (const Color(0xFFE0F2FE), const Color(0xFF0369A1), l10n.filterWashing),
      _ when order.isSiapDiambil => (const Color(0xFFDCFCE7), const Color(0xFF15803D), l10n.statusReady),
      _ => (const Color(0xFFF1F5F9), AppTheme.textSecondary, order.status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
