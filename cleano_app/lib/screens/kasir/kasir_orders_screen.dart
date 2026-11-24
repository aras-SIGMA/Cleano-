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
import '../../widgets/order_list_item_card.dart';
import '../../widgets/state_view.dart';

/// Layar Kasir: Manajemen Pesanan & Estafet Mesin 1-Tap (M5).
/// - Tab filter: Semua, Antre, Proses Cuci, Siap Diambil, Selesai
/// - Pencarian cepat nomor order / nama pelanggan
/// - Aksi transisi status:
///   1. 'proses_cuci' -> 'siap_diambil' (membebaskan mesin cuci)
///   2. Auto-recommend Modal Estafet 1-Tap jika respons memuat `next_queue_order`
///   3. 'siap_diambil' -> 'selesai' (konfirmasi serah terima cucian & catat poin)
/// - Paginasi / lazy infinite scroll & Pull-to-refresh
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

  static const List<(String, String)> _filterTabs = [
    ('semua', 'Semua'),
    ('antre', 'Antre'),
    ('proses_cuci', 'Proses Cuci'),
    ('sedang_diproses', 'Sedang Diproses'),
    ('siap_diambil', 'Siap Diambil'),
    ('selesai', 'Selesai'),
  ];

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
    // Setiap permintaan mengambil nomor urut. Respons yang nomornya bukan lagi
    // yang terbaru dibuang: kalau kasir berpindah tab cepat, dua permintaan
    // berjalan bersamaan dan yang selesai terakhir belum tentu yang benar.
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
      setState(() {
        _errorMessage = 'Gagal memuat daftar pesanan: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// Pencarian dikirim ke server setelah jeda ketik. Menyaring di klien hanya
  /// benar untuk halaman yang sudah dimuat, jadi order di halaman berikutnya
  /// tidak akan pernah ditemukan.
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

  /// Transisi 1: Proses Cuci -> Siap Diambil.
  /// Membebaskan unit mesin dan mendeteksi apakah ada antrean berikutnya (estafet).
  Future<void> _handleMarkReady(OrderModel order) async {
    final freedMachineId = order.machineId;
    final freedMachineCode = order.machineCode ?? 'Mesin';

    setState(() => _actionLoadingOrderIds.add(order.id));

    try {
      final updated = await _orderService.updateStatus(order.id, 'siap_diambil');

      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan ${order.orderCode} ditandai Siap Diambil.'),
          backgroundColor: AppTheme.success,
        ),
      );

      // Cek apakah ada antrean yang menunggu mesin cuci yang baru saja kosong (Estafet)
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
        SnackBar(content: Text('Gagal memperbarui status: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  /// Dialog Konfirmasi Estafet Mesin 1-Tap:
  /// Menawarkan kasir untuk langsung memasukkan antrean terdepan ke mesin yang baru saja kosong.
  Future<void> _showEstafetConfirmationDialog({
    required int freedMachineId,
    required String freedMachineCode,
    required NextQueueOrderModel nextOrder,
  }) async {
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
                    'Mesin $freedMachineCode Kini Kosong!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    'Rekomendasi Estafet Otomatis',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                        child: const Text(
                          'Antrean Terdepan',
                          style: TextStyle(
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
                    'Pelanggan: ${nextOrder.customerName}',
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
            const Text(
              'Masukkan pakaian antrean ini ke dalam drum mesin cuci sekarang agar timer mesin langsung berjalan?',
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
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
            child: const Text('Nanti Saja', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Ya, Mulai Cuci Sekarang'),
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
            content: Text('Cucian ${nextOrder.orderCode} mulai dicuci di $freedMachineCode.'),
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
          SnackBar(content: Text('Gagal konfirmasi estafet: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  /// Transisi 2: Siap Diambil -> Selesai.
  /// Menandai penyerahan cucian kepada pelanggan dan memicu pemberian poin loyalti otomatis.
  Future<void> _handleCompleteOrder(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Selesaikan Pesanan?'),
        content: Text(
          'Pastikan cucian ${order.orderCode} telah diserahkan kepada ${order.customerName}.\n\n'
          'Status akan diubah menjadi Selesai dan poin loyalti pelanggan akan ditambahkan secara otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Selesaikan'),
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
          content: Text('Pesanan ${order.orderCode} berhasil diselesaikan.'),
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
        SnackBar(content: Text('Gagal menyelesaikan pesanan: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  /// Membatalkan pesanan yang belum dilunaskan. Status 'batal' final (L-06),
  /// jadi konfirmasi dulu — tidak ada jalan untuk menghidupkan kembali.
  Future<void> _handleCancelOrder(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Pesanan?'),
        content: Text(
          'Pesanan ${order.orderCode} atas nama ${order.customerName} akan dibatalkan.\n\n'
          'Status Batal bersifat permanen dan tidak bisa dikembalikan. '
          'Mesin yang dipakai akan dilepas bila pesanan sedang dicuci.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Batalkan'),
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
          content: Text('Pesanan ${order.orderCode} dibatalkan.'),
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
        SnackBar(content: Text('Gagal membatalkan pesanan: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  /// Sinkronisasi status pembayaran Midtrans secara manual bila pelanggan sudah membayar via QRIS/VA.
  Future<void> _handleSyncPayment(OrderModel order) async {
    setState(() => _actionLoadingOrderIds.add(order.id));

    try {
      final updated = await _orderService.syncPayment(order.id);

      if (!mounted) return;
      setState(() => _actionLoadingOrderIds.remove(order.id));

      final isPaid = updated.paymentStatus == 'lunas';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPaid
              ? 'Pembayaran pesanan ${order.orderCode} berhasil diverifikasi LUNAS.'
              : 'Status pembayaran masih belum lunas di gateway.'),
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
        SnackBar(content: Text('Gagal cek status pembayaran: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Pesanan & Estafet',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: 'Segarkan Data',
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
                              'Menampilkan ${_orders.length} dari $_totalOrders pesanan',
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
          hintText: 'Cari kode order (CLN-...), nama, atau HP...',
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _filterTabs.map((tab) {
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
              const Text(
                'Tidak Ada Pesanan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Tidak ditemukan pesanan dengan kata kunci "$_searchQuery".'
                    : 'Belum ada pesanan pada kategori filter ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() => StateErrorView(
        message: _errorMessage ?? 'Terjadi kesalahan.',
        onRetry: () => _loadOrders(reset: true),
      );
}
