import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/order_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/state_view.dart';
import '../../widgets/tracking_order_card.dart';

/// Layar Pelacakan Cucian Real-Time & Riwayat Transaksi Pelanggan (M7).
class PelangganTrackingScreen extends StatefulWidget {
  const PelangganTrackingScreen({
    super.key,
    this.orderService,
    this.user,
    this.onLogout,
  });

  final OrderService? orderService;

  /// Profil pelanggan dari induk; tampilkan keterangan resmi jika masih null.
  final UserModel? user;

  final VoidCallback? onLogout;

  @override
  State<PelangganTrackingScreen> createState() => _PelangganTrackingScreenState();
}

class _PelangganTrackingScreenState extends State<PelangganTrackingScreen> with SingleTickerProviderStateMixin {
  OrderService get _orderService => widget.orderService ?? OrderService.instance;

  late TabController _tabController;

  List<OrderModel> _activeOrders = [];
  List<OrderModel> _historyOrders = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activeFuture = _orderService.getOrders(status: 'aktif', pageSize: 20);
      final historyFuture = _orderService.getOrders(status: 'selesai', pageSize: 20);

      final results = await Future.wait([activeFuture, historyFuture]);

      if (mounted) {
        setState(() {
          _activeOrders = results[0].items;
          _historyOrders = results[1].items;
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
        final isEn = context.l10n.localeName == 'en';
        setState(() {
          _errorMessage = isEn
              ? 'Failed to load laundry status: $e'
              : 'Gagal memuat status cucian: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showOrderDetailBottomSheet(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = ctx.l10n;
        final isEn = l10n.localeName == 'en';
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.tanggal(order.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Foto kondisi awal drop-off jika ada
                if (ApiConstants.resolveMediaUrl(order.imageUrl) case final imageUrl?) ...[
                  Text(
                    l10n.dropoffPhotoTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Catatan khusus
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEn ? 'Notes: ${order.notes!}' : 'Catatan: ${order.notes!}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Rincian Biaya
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildCostRow(l10n.serviceLabel, order.serviceName),
                      const SizedBox(height: 6),
                      _buildCostRow(l10n.weightLabel, Formatters.berat(order.weight)),
                      const SizedBox(height: 6),
                      _buildCostRow('Subtotal', Formatters.rupiah(order.subtotalPrice)),
                      if (order.discountAmount > 0) ...[
                        const SizedBox(height: 6),
                        _buildCostRow(
                          isEn
                              ? 'Voucher Discount (${order.voucherCode ?? 'PROMO'})'
                              : 'Potongan Voucher (${order.voucherCode ?? 'PROMO'})',
                          '- ${Formatters.rupiah(order.discountAmount)}',
                          isDiscount: true,
                        ),
                      ],
                      const Divider(height: 20),
                      _buildCostRow(
                        l10n.totalPaymentLabel,
                        Formatters.rupiah(order.totalPrice),
                        isTotal: true,
                      ),
                      const SizedBox(height: 6),
                      _buildCostRow(
                        l10n.methodStatusLabel,
                        '${order.paymentMethod.toUpperCase()} • ${order.paymentStatus.toUpperCase()}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCostRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isDiscount
                ? AppTheme.success
                : (isTotal ? AppTheme.primary : AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklySummary = _buildWeeklySummary();
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: Stack(
        children: [
          const AmbientBackground(),
          // Batasi lebar konten dan pusatkan pada layar desktop agar nyaman dibaca.
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 1. Header Pelanggan: Sapaan, Badge Tier, & Poin
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        sliver: SliverToBoxAdapter(
                          child: _buildCustomerHeader(),
                        ),
                      ),

                      // 2. Ringkasan Aktivitas 7 Hari Terakhir
                      if (weeklySummary != null)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          sliver: SliverToBoxAdapter(child: weeklySummary),
                        ),

                      // 3. Tab Bar: Pesanan Aktif vs Riwayat
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildTabBar(),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      // 4. Konten Daftar Pesanan
                      if (_isLoading && _activeOrders.isEmpty && _historyOrders.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorMessage != null && _activeOrders.isEmpty && _historyOrders.isEmpty)
                        SliverFillRemaining(
                          child: _buildErrorState(),
                        )
                      else
                        _buildTabContent(),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader() {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final user = widget.user;
    if (user == null) {
      return FrostedGlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        blurSigma: 14,
        child: Row(
          children: [
            const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEn ? 'Profile not loaded yet.' : 'Profil belum termuat.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            if (widget.onLogout != null)
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
                tooltip: l10n.logout,
                onPressed: widget.onLogout,
              ),
          ],
        ),
      );
    }

    final (tierBg, tierFg) = switch (user.tier.toLowerCase()) {
      'platinum' => (const Color(0xFFE0E7FF), const Color(0xFF3730A3)),
      'gold' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };

    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      blurSigma: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.helloGreeting(user.name),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tier ${user.tier.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: tierFg,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.pointsBalanceLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.points} ${l10n.pointsUnit}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onLogout != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
              tooltip: l10n.logout,
              onPressed: widget.onLogout,
            ),
          ],
        ],
      ),
    );
  }

  /// Ringkas aktivitas 7 hari terakhir dari 20 riwayat pesanan yang dimuat.
  Widget? _buildWeeklySummary() {
    if (_historyOrders.isEmpty) return null;

    final l10n = context.l10n;
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final recent =
        _historyOrders.where((o) => !o.createdAt.isBefore(since)).toList();

    final totalBerat = recent.fold<double>(0, (sum, o) => sum + o.weight);
    final totalPoin = recent.fold<int>(0, (sum, o) => sum + o.pointsAwarded);

    return FrostedGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      blurSigma: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.weeklyActivityTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                l10n.fromRecentHistory,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildWeeklyMetric('${recent.length}', l10n.laundryCountLabel),
              _buildWeeklyDivider(),
              _buildWeeklyMetric(Formatters.berat(totalBerat), l10n.totalWeightLabel),
              _buildWeeklyDivider(),
              _buildWeeklyMetric('$totalPoin', l10n.pointsEarnedLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyDivider() => Container(
        width: 1,
        height: 34,
        color: AppTheme.border,
      );

  Widget _buildWeeklyMetric(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: l10n.activeLaundryTab(_activeOrders.length)),
          Tab(text: l10n.completedHistoryTab(_historyOrders.length)),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final l10n = context.l10n;
    final isAktifTab = _tabController.index == 0;
    final orders = isAktifTab ? _activeOrders : _historyOrders;

    if (orders.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: StateEmptyView(
          message: isAktifTab ? l10n.noActiveLaundry : l10n.noCompletedHistory,
          icon: isAktifTab ? Icons.check_circle_outline_rounded : Icons.history_rounded,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return TrackingOrderCard(
            order: order,
            isHistory: !isAktifTab,
            onTap: () => _showOrderDetailBottomSheet(order),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() => StateErrorView(message: _errorMessage!, onRetry: _loadData);
}
