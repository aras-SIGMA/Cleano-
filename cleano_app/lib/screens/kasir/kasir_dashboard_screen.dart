import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/dashboard_summary_model.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/order_service.dart';

/// Layar Dashboard Utama Kasir Cleano:
/// - 4 Kartu Metrik Operasional (Omzet, Pesanan Aktif, Siap Diambil, Kapasitas Mesin)
/// - Grafik Batang Tren Omzet 7 Hari (fl_chart)
/// - Daftar Ringkas Pesanan Aktif
/// - Pull-to-Refresh & Ekspor Ringkasan Laporan
class KasirDashboardScreen extends StatefulWidget {
  const KasirDashboardScreen({
    super.key,
    this.onNavigateToOrders,
    this.onNavigateToPos,
    this.dashboardService,
    this.orderService,
  });

  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToPos;
  final DashboardService? dashboardService;
  final OrderService? orderService;

  @override
  State<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends State<KasirDashboardScreen> {
  DashboardService get _dashboardService => widget.dashboardService ?? DashboardService.instance;
  OrderService get _orderService => widget.orderService ?? OrderService.instance;

  DashboardSummaryModel? _summary;
  List<OrderModel> _activeOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final activeOrdersFuture = _orderService.getOrders(status: 'aktif', pageSize: 5);

      final results = await Future.wait([summaryFuture, activeOrdersFuture]);

      if (mounted) {
        setState(() {
          _summary = results[0] as DashboardSummaryModel;
          final orderResult = results[1] as OrderListResult;
          _activeOrders = orderResult.items;
          _isLoading = false;
        });
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
        setState(() {
          _errorMessage = 'Gagal memuat data dashboard: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showExportDialog() {
    if (_summary == null) return;
    final total7Hari = _summary!.revenue7Days.fold<int>(0, (sum, d) => sum + d.dailyRevenue);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ekspor Ringkasan Laporan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Unduh rekap operasional kasir Cleano',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Omzet Hari Ini', Formatters.rupiah(_summary!.todayRevenue)),
                    const SizedBox(height: 8),
                    _buildModalRow('Total Omzet 7 Hari', Formatters.rupiah(total7Hari)),
                    const SizedBox(height: 8),
                    _buildModalRow('Pesanan Aktif', '${_summary!.activeOrders} Pesanan'),
                    const SizedBox(height: 8),
                    _buildModalRow(
                      'Kapasitas Mesin',
                      '${_summary!.availableMachines} / ${_summary!.totalOperationalMachines} Tersedia',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ekspor format CSV disiapkan.'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('Ekspor CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ekspor format PDF disiapkan.'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Ekspor PDF'),
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
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Kasir',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              'Ringkasan Operasional Cleano',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Ekspor Laporan',
            onPressed: _summary != null ? _showExportDialog : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: widget.onNavigateToPos != null
          ? FloatingActionButton.extended(
              onPressed: widget.onNavigateToPos,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text(
                'POS Baru',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary!;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 4 Kartu Metrik Operasional
                _buildMetricCards(summary, isWide),
                const SizedBox(height: 20),

                // 2. Grafik Batang Tren Omzet 7 Hari
                _buildRevenueChartCard(summary),
                const SizedBox(height: 20),

                // 3. Daftar Ringkas Order Aktif
                _buildActiveOrdersCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCards(DashboardSummaryModel summary, bool isWide) {
    final cards = [
      _MetricCard(
        title: 'Omzet Hari Ini',
        value: Formatters.rupiah(summary.todayRevenue),
        subtitle: 'Pendapatan lunas hari ini',
        icon: Icons.payments_rounded,
        iconColor: AppTheme.primary,
        bgColor: AppTheme.surfaceSubtle,
      ),
      _MetricCard(
        title: 'Pesanan Aktif',
        value: '${summary.activeOrders}',
        subtitle: 'Antre & proses cuci',
        icon: Icons.local_laundry_service_rounded,
        iconColor: AppTheme.secondary,
        bgColor: const Color(0xFFF0F9FF),
      ),
      _MetricCard(
        title: 'Siap Diambil',
        value: '${summary.readyOrders}',
        subtitle: 'Menunggu pelanggan',
        icon: Icons.check_circle_rounded,
        iconColor: AppTheme.success,
        bgColor: const Color(0xFFF0FDF4),
      ),
      _MetricCard(
        title: 'Kapasitas Mesin',
        value: '${summary.availableMachines}/${summary.totalOperationalMachines}',
        subtitle: 'Mesin cuci siap pakai',
        icon: Icons.precision_manufacturing_rounded,
        iconColor: AppTheme.accent,
        bgColor: const Color(0xFFFFFBEB),
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: cards,
    );
  }

  Widget _buildRevenueChartCard(DashboardSummaryModel summary) {
    final rev7 = summary.revenue7Days;
    final total7Hari = rev7.fold<int>(0, (sum, d) => sum + d.dailyRevenue);

    // Cari nilai tertinggi untuk batas sumbu Y
    double maxRevenue = 0;
    for (final d in rev7) {
      if (d.dailyRevenue > maxRevenue) maxRevenue = d.dailyRevenue.toDouble();
    }
    // Beri batas atas dengan padding 20%
    final maxY = maxRevenue > 0 ? maxRevenue * 1.25 : 100000.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Omzet 7 Hari Terakhir',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Grafik akumulasi transaksi harian',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: ${Formatters.rupiah(total7Hari)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 190,
            child: rev7.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data pendapatan 7 hari terakhir.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
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
                              final label = parsed != null ? DateFormat('d/M').format(parsed) : item.orderDate;
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
                                ? DateFormat('dd MMM', 'id_ID').format(dateParsed)
                                : item.orderDate;
                            return BarTooltipItem(
                              '$formattedDate\n${Formatters.rupiah(item.dailyRevenue)}\n(${item.totalTransactions} order)',
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
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              gradient: const LinearGradient(
                                colors: [AppTheme.primary, AppTheme.secondary],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 16,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Pesanan Aktif',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_activeOrders.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onNavigateToOrders != null)
                TextButton(
                  onPressed: widget.onNavigateToOrders,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primary,
                  ),
                  child: const Text('Lihat Semua >', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_activeOrders.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Tidak ada cucian antre atau sedang diproses.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Seluruh pesanan aktif telah siap diambil atau selesai.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeOrders.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final order = _activeOrders[index];
                return _ActiveOrderItem(order: order);
              },
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderItem extends StatelessWidget {
  const _ActiveOrderItem({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              ),
            ),
            _buildStatusBadge(order),
          ],
        ),
        const SizedBox(height: 4),
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
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        if (order.isAntre && order.queueWaitMinutes > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.accent),
              const SizedBox(width: 4),
              Text(
                'Estimasi antrean tunggu: ~${order.queueWaitMinutes} menit',
                style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
        if (order.isProsesCuci && order.machineCode != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.rotate_right_rounded, size: 12, color: AppTheme.secondary),
              const SizedBox(width: 4),
              Text(
                'Mesin: ${order.machineCode}'
                '${order.machineFinishAt != null ? ' (Selesai ~${Formatters.jam(order.machineFinishAt!)})' : ''}',
                style: const TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(OrderModel order) {
    Color bg;
    Color fg;
    String text;

    if (order.isAntre) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      text = 'Antre Cuci';
    } else if (order.isProsesCuci) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      text = 'Proses Cuci';
    } else if (order.isSiapDiambil) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      text = 'Siap Diambil';
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = AppTheme.textSecondary;
      text = order.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
