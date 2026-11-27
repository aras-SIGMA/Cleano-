import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/next_queue_order_model.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../../services/order_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/order_list_item_card.dart';
import '../../widgets/state_view.dart';

/// Layar Manajemen Pesanan & Estafet Mesin 1-Tap (M5) untuk kasir.
class KasirOrdersScreen extends StatefulWidget {
  const KasirOrdersScreen({
    super.key,
    this.orderService,
    this.initialStatus,
  });

  final OrderService? orderService;
  final String? initialStatus;

  @override
  State<KasirOrdersScreen> createState() => _KasirOrdersScreenState();
}

class _KasirOrdersScreenState extends State<KasirOrdersScreen> {
  OrderService get _orderService => widget.orderService ?? OrderService.instance;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Filter state
  late String _selectedStatus; // 'semua' | 'antre' | 'proses_cuci' | 'sedang_diproses' | 'siap_diambil' | 'selesai'
  String _searchInput = ''; // isi kotak ketik (langsung)
  String _searchQuery = ''; // yang benar-benar dikirim ke server

  // Data state
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  int _totalPages = 1;
  int _totalOrders = 0;
  int _requestSeq = 0;

  // Processing state for individual order action
  final Set<int> _actionLoadingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? 'semua';
    _scrollController.addListener(_onScroll);
    _loadOrders(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && !_isLoading && _page < _totalPages) {
        _loadOrders(reset: false);
      }
    }
  }

  Future<void> _loadOrders({bool reset = false}) async {
    // Buang respons permintaan lama menggunakan nomor urut agar tab tetap akurat.
    final seq = ++_requestSeq;

    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final targetPage = reset ? 1 : _page + 1;
      final statusParam = _selectedStatus == 'semua' ? null : _selectedStatus;

      final result = await _orderService.getOrders(
        status: statusParam,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: targetPage,
        pageSize: 15,
      );

      if (!mounted || seq != _requestSeq) return;
      setState(() {
        if (reset) {
          _orders = result.items;
        } else {
          _orders.addAll(result.items);
        }
        _page = result.page;
        _totalPages = result.totalPages;
        _totalOrders = result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      final isEn = context.l10n.localeName == 'en';
      setState(() {
        _errorMessage = isEn ? 'Failed to load orders: $e' : 'Gagal memuat daftar pesanan: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// Kirim pencarian ke server setelah jeda ketik agar mencakup semua halaman.
  void _onSearchChanged(String value) {
    final q = value.trim();
    setState(() => _searchInput = q);
    _searchDebounce?.cancel();
    if (q == _searchQuery) return;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = q);
      _loadOrders(reset: true);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchInput = '';
      _searchQuery = '';
    });
    _loadOrders(reset: true);
  }

  /// Transisi Proses Cuci -> Siap Diambil sekaligus membebaskan mesin untuk estafet.
  Future<void> _handleMarkReady(OrderModel order) async {
    final isEn = context.l10n.localeName == 'en';
    final freedMachineId = order.machineId;
    final freedMachineCode = order.machineCode ?? (isEn ? 'Machine' : 'Mesin');

    setState(() => _actionLoadingOrderIds.add(order.id));

    try {
      final updated = await _orderService.updateStatus(order.id, 'siap_diambil');

      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Order ${order.orderCode} marked Ready for Pickup.'
                : 'Pesanan ${order.orderCode} ditandai Siap Diambil.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );

      // Periksa apakah ada pesanan antre yang siap menempati mesin kosong.
      if (updated.nextQueueOrder != null && freedMachineId != null) {
        await _showEstafetConfirmationDialog(
          freedMachineId: freedMachineId,
          freedMachineCode: freedMachineCode,
          nextOrder: updated.nextQueueOrder!,
        );
      }

      // Muat ulang daftar
      _loadOrders(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Failed to update status: $e' : 'Gagal memperbarui status: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  /// Dialog konfirmasi Estafet Mesin 1-Tap untuk memproses antrean terdepan.
  Future<void> _showEstafetConfirmationDialog({
    required int freedMachineId,
    required String freedMachineCode,
    required NextQueueOrderModel nextOrder,
  }) async {
    final isEn = context.l10n.localeName == 'en';
    final shouldRelay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.sync_rounded, color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Machine $freedMachineCode Is Now Free!' : 'Mesin $freedMachineCode Kini Kosong!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    isEn ? 'Auto Relay Recommendation' : 'Rekomendasi Estafet Otomatis',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nextOrder.orderCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isEn ? 'Next in Queue' : 'Antrean Terdepan',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isEn ? 'Customer' : 'Pelanggan'}: ${nextOrder.customerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${nextOrder.serviceName} • ${Formatters.berat(nextOrder.weight)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isEn
                  ? 'Load this queued laundry into the washing machine drum now so the machine timer starts immediately?'
                  : 'Masukkan pakaian antrean ini ke dalam drum mesin cuci sekarang agar timer mesin langsung berjalan?',
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(isEn ? 'Later' : 'Nanti Saja', style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(isEn ? 'Yes, Start Washing Now' : 'Ya, Mulai Cuci Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );

    if (shouldRelay == true) {
      try {
        await _orderService.confirmRelay(nextOrder.id, freedMachineId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn
                  ? 'Laundry ${nextOrder.orderCode} started washing in $freedMachineCode.'
                  : 'Cucian ${nextOrder.orderCode} mulai dicuci di $freedMachineCode.',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Failed to confirm relay: $e' : 'Gagal konfirmasi estafet: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  /// Transisi Siap Diambil -> Selesai sekaligus memicu pemberian poin otomatis.
  Future<void> _handleCompleteOrder(OrderModel order) async {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEn ? 'Complete Order?' : 'Selesaikan Pesanan?'),
        content: Text(
          isEn
              ? 'Make sure laundry ${order.orderCode} has been handed over to ${order.customerName}.\n\n'
                  'Status will be changed to Completed and customer loyalty points will be added automatically.'
              : 'Pastikan cucian ${order.orderCode} telah diserahkan kepada ${order.customerName}.\n\n'
                  'Status akan diubah menjadi Selesai dan poin loyalti pelanggan akan ditambahkan secara otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? 'Yes, Complete' : 'Ya, Selesaikan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoadingOrderIds.add(order.id));

    try {
      await _orderService.updateStatus(order.id, 'selesai');

      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Order ${order.orderCode} completed successfully.' : 'Pesanan ${order.orderCode} berhasil diselesaikan.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );

      _loadOrders(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Failed to complete order: $e' : 'Gagal menyelesaikan pesanan: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  /// Batalkan pesanan belum lunas dengan konfirmasi karena status batal bersifat final.
  Future<void> _handleCancelOrder(OrderModel order) async {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEn ? 'Cancel Order?' : 'Batalkan Pesanan?'),
        content: Text(
          isEn
              ? 'Order ${order.orderCode} for ${order.customerName} will be cancelled.\n\n'
                  'Cancelled status is permanent and cannot be undone. '
                  'The assigned machine will be released if currently washing.'
              : 'Pesanan ${order.orderCode} atas nama ${order.customerName} akan dibatalkan.\n\n'
                  'Status Batal bersifat permanen dan tidak bisa dikembalikan. '
                  'Mesin yang dipakai akan dilepas bila pesanan sedang dicuci.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? 'Yes, Cancel' : 'Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoadingOrderIds.add(order.id));

    try {
      await _orderService.updateStatus(order.id, 'batal');

      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Order ${order.orderCode} cancelled.' : 'Pesanan ${order.orderCode} dibatalkan.'),
          backgroundColor: AppTheme.danger,
        ),
      );

      _loadOrders(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Failed to cancel order: $e' : 'Gagal membatalkan pesanan: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  /// Sinkronisasi status pembayaran Midtrans secara manual bila pelanggan sudah membayar via QRIS/VA.
  Future<void> _handleSyncPayment(OrderModel order) async {
    final isEn = context.l10n.localeName == 'en';
    setState(() => _actionLoadingOrderIds.add(order.id));

    try {
      final updated = await _orderService.syncPayment(order.id);

      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));

      final isPaid = updated.paymentStatus == 'lunas';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPaid
                ? (isEn
                    ? 'Payment for order ${order.orderCode} verified as PAID.'
                    : 'Pembayaran pesanan ${order.orderCode} berhasil diverifikasi LUNAS.')
                : (isEn
                    ? 'Payment is still unpaid at the gateway.'
                    : 'Status pembayaran masih belum lunas di gateway.'),
          ),
          backgroundColor: isPaid ? AppTheme.success : AppTheme.accent,
        ),
      );

      _loadOrders(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Failed to check payment status: $e' : 'Gagal cek status pembayaran: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          isEn ? 'Orders & Relay' : 'Pesanan & Estafet',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: l10n.refreshData,
            onPressed: () => _loadOrders(reset: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          RefreshIndicator(
            onRefresh: () => _loadOrders(reset: true),
            color: AppTheme.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Kotak Pencarian Cepat
                        _buildSearchBar(),
                        const SizedBox(height: 14),

                        // 2. Baris Tab Filter Status
                        _buildFilterTabs(),
                        const SizedBox(height: 12),

                        // 3. Ringkasan Jumlah
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEn
                                  ? 'Showing ${_orders.length} of $_totalOrders orders'
                                  : 'Menampilkan ${_orders.length} dari $_totalOrders pesanan',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            if (_isLoading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Daftar Pesanan Virtualized
                if (_isLoading && _orders.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null && _orders.isEmpty)
                  SliverFillRemaining(
                    child: _buildErrorState(),
                  )
                else if (_orders.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: _orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final isActionLoading = _actionLoadingOrderIds.contains(order.id);

                        return OrderListItemCard(
                          order: order,
                          isActionLoading: isActionLoading,
                          onMarkReady: () => _handleMarkReady(order),
                          onComplete: () => _handleCompleteOrder(order),
                          onSyncPayment: () => _handleSyncPayment(order),
                          onCancel: () => _handleCancelOrder(order),
                        );
                      },
                    ),
                  ),
                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 110),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isEn = context.l10n.localeName == 'en';
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      borderRadius: 18,
      blurSigma: 12,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          icon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
          hintText: isEn ? 'Search order code (CLN-...), name, or phone...' : 'Cari kode order (CLN-...), nama, atau HP...',
          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          border: InputBorder.none,
          isDense: true,
          suffixIcon: _searchInput.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                  onPressed: _clearSearch,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final l10n = context.l10n;
    final filterTabs = [
      ('semua', l10n.statusAll),
      ('antre', l10n.statusQueue),
      ('proses_cuci', l10n.statusWashing),
      ('sedang_diproses', l10n.statusProcessing),
      ('siap_diambil', l10n.statusReady),
      ('selesai', l10n.statusDone),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filterTabs.map((tab) {
          final isSelected = _selectedStatus == tab.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                if (_selectedStatus != tab.$1) {
                  setState(() => _selectedStatus = tab.$1);
                  _loadOrders(reset: true);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.25)
                          : const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  tab.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isEn = context.l10n.localeName == 'en';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FrostedGlassCard(
          padding: const EdgeInsets.all(32),
          borderRadius: 24,
          blurSigma: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inbox_rounded, size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                isEn ? 'No Orders' : 'Tidak Ada Pesanan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? (isEn
                        ? 'No orders found matching "$_searchQuery".'
                        : 'Tidak ditemukan pesanan dengan kata kunci "$_searchQuery".')
                    : (isEn
                        ? 'No orders in this filter category yet.'
                        : 'Belum ada pesanan pada kategori filter ini.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isEn = context.l10n.localeName == 'en';
    return StateErrorView(
      message: _errorMessage ?? (isEn ? 'An error occurred.' : 'Terjadi kesalahan.'),
      onRetry: () => _loadOrders(reset: true),
    );
  }
}
