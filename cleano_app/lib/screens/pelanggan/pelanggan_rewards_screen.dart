import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/reward_model.dart';
import '../../models/user_model.dart';
import '../../models/voucher_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/reward_service.dart';
import '../../services/session_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';

/// Layar Loyalti & Hadiah Pelanggan (M9).
/// - Banner poin & progress bar ke tier berikutnya (100 Gold, 300 Platinum).
/// - Info bonus 2x poin (berat >= 5 kg atau layanan Express).
/// - Sub-tab Katalog: tombol "Tukar Poin" aktif jika poin cukup, dialog konfirmasi -> POST /api/rewards/redeem.
/// - Sub-tab Voucher Saya: QR code CLN-VCR-XXXX + kode teks + nominal + badge 1x Pakai.
/// - Riwayat voucher terpakai dengan tampilan redup (dimmed).
class PelangganRewardsScreen extends StatefulWidget {
  const PelangganRewardsScreen({
    super.key,
    this.rewardService,
    this.sessionService,
    this.authService,
    this.user,
    this.onLogout,
  });

  final RewardService? rewardService;
  final SessionService? sessionService;
  final AuthService? authService;

  /// Profil dari navigasi induk. Bila diisi, pemuatan pertama tidak mengambil
  /// `/users/me` lagi — induk sudah memuatnya sekali untuk seluruh portal.
  /// Refresh dan klaim voucher tetap membaca profil terbaru dari server.
  final UserModel? user;

  final VoidCallback? onLogout;

  @override
  State<PelangganRewardsScreen> createState() => _PelangganRewardsScreenState();
}

class _PelangganRewardsScreenState extends State<PelangganRewardsScreen>
    with SingleTickerProviderStateMixin {
  RewardService get _rewardService => widget.rewardService ?? RewardService.instance;
  SessionService get _sessionService => widget.sessionService ?? SessionService.instance;
  AuthService get _authService => widget.authService ?? AuthService.instance;

  late TabController _tabController;

  UserModel? _user;
  List<RewardModel> _catalog = [];
  List<VoucherModel> _activeVouchers = [];
  List<VoucherModel> _historyVouchers = [];

  bool _isLoading = true;
  bool _isRedeeming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _user = widget.user;
    _loadData(refreshProfile: _user == null);
  }

  @override
  void didUpdateWidget(PelangganRewardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Induk memuat ulang profil setelah tab ini terpasang. State dipertahankan
    // IndexedStack, jadi initState tidak jalan lagi. Pakai identitas objek:
    // `UserModel ==` hanya melihat id dan email, bukan poin/tier.
    if (widget.user != null && !identical(widget.user, oldWidget.user)) {
      _user = widget.user;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refreshProfile = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Profil: kiriman induk dipakai apa adanya saat pemuatan pertama.
      //    Cache hanya dibaca bila belum ada profil sama sekali, supaya nilai
      //    lama tidak menimpa data yang lebih baru.
      if (_user == null) {
        final cached = await _sessionService.getUser();
        if (mounted && cached != null) {
          setState(() => _user = cached);
        }
      }

      // Saldo poin berubah tanpa lewat layar ini (klaim voucher, order selesai),
      // jadi refresh dan aksi klaim wajib membaca ulang profil dari server.
      final freshUserFuture = refreshProfile
          ? _authService.getMe().then((fresh) {
              if (mounted && fresh != null) {
                setState(() => _user = fresh);
              }
            }).catchError((_) {})
          : Future<void>.value();

      // 2. Ambil katalog reward dan voucher saya
      final catalogFuture = _rewardService.getCatalog();
      final vouchersFuture = _rewardService.getMyVouchers();

      final results = await Future.wait([catalogFuture, vouchersFuture, freshUserFuture]);

      if (mounted) {
        setState(() {
          _catalog = results[0] as List<RewardModel>;
          final vResult = results[1] as MyVouchersResult;
          _activeVouchers = vResult.active;
          _historyVouchers = vResult.history;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat hadiah. Periksa koneksi Anda.';
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleRedeem(RewardModel reward) async {
    final userPoints = _user?.points ?? 0;
    if (userPoints < reward.pointsRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Poin tidak mencukupi untuk menukar ${reward.title}.'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Tampilkan modal dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Tukar Poin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tukarkan poin Anda dengan reward:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Potongan: ${Formatters.rupiah(reward.discountAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Poin Dibutuhkan:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(
                  '-${reward.pointsRequired} Poin',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.danger),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sisa Saldo Poin:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(
                  '${userPoints - reward.pointsRequired} Poin',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tukar Sekarang'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isRedeeming = true);

    try {
      final newVoucher = await _rewardService.redeem(reward.id);

      // Refresh data profil dan daftar voucher setelah klaim sukses
      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat! Voucher ${newVoucher.voucherCode} berhasil diklaim.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Lihat Voucher',
            textColor: Colors.white,
            onPressed: () {
              _tabController.animateTo(1);
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal menukarkan hadiah. Periksa koneksi Anda.'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  void _showVoucherQrModal(VoucherModel voucher) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    voucher.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: voucher.voucherCode,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'QR Voucher ${voucher.voucherCode}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    voucher.voucherCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Potongan: ${Formatters.rupiah(voucher.discountAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.success,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tunjukkan QR ini ke kasir saat memesan cucian.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Header Bar
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loyalti & Hadiah',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Kumpulkan Poin & Dapatkan Promo Menarik',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          if (widget.onLogout != null)
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                              tooltip: 'Logout',
                              onPressed: widget.onLogout,
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Banner Poin & Progress Tier Bar
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _buildPointsTierBanner(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // 3. Info Bonus 2x Poin
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _buildBonusPointsInfoCard(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 4. Tab Bar (Katalog Hadiah vs Voucher Saya)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _buildTabBar(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // 5. Konten Sub-Tab
                  if (_isLoading && _catalog.isEmpty && _activeVouchers.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null && _catalog.isEmpty && _activeVouchers.isEmpty)
                    SliverFillRemaining(
                      child: _buildErrorState(),
                    )
                  else
                    _buildTabContent(),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          if (_isRedeeming)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Banner Poin dan Progress Bar ke Tier Berikutnya (100 Gold, 300 Platinum)
  Widget _buildPointsTierBanner() {
    final points = _user?.points ?? 0;
    final currentTier = _user?.tier.toLowerCase() ?? 'silver';

    // Logika tier progress:
    // Silver (< 100): target 100 Gold
    // Gold (100 - 299): target 300 Platinum
    // Platinum (>= 300): tier tertinggi
    final (String nextTierName, int pointsNeeded, double progressFraction) = switch (currentTier) {
      'platinum' => ('Maksimal', 0, 1.0),
      'gold' => ('Platinum', (300 - points).clamp(0, 300), ((points - 100) / 200.0).clamp(0.0, 1.0)),
      _ => ('Gold', (100 - points).clamp(0, 100), (points / 100.0).clamp(0.0, 1.0)),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SALDO POIN SAYA',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '$points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Poin',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'TIER ${(_user?.tier ?? 'SILVER').toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Progress Bar ke Tier Berikutnya
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentTier == 'platinum'
                            ? 'Tingkat Keanggotaan Tertinggi'
                            : '$pointsNeeded Poin lagi menuju $nextTierName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(progressFraction * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Info Bonus 2x Poin (Berat >= 5 kg atau Express)
  Widget _buildBonusPointsInfoCard() {
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 18,
      blurSigma: 12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonus 2x Poin Loyalti ⚡',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Otomatis dapatkan 2x poin untuk cucian berat ≥ 5 kg atau layanan Express!',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
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
          Tab(text: 'Katalog Hadiah (${_catalog.length})'),
          Tab(text: 'Voucher Saya (${_activeVouchers.length})'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final isKatalog = _tabController.index == 0;

    if (isKatalog) {
      return _buildCatalogTab();
    } else {
      return _buildMyVouchersTab();
    }
  }

  /// Sub-tab 1: Katalog Hadiah
  Widget _buildCatalogTab() {
    if (_catalog.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Belum ada reward voucher yang tersedia saat ini.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final userPoints = _user?.points ?? 0;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: _catalog.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final reward = _catalog[index];
          final canRedeem = userPoints >= reward.pointsRequired;

          return FrostedGlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            blurSigma: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reward.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reward.description,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Diskon ${Formatters.rupiah(reward.discountAmount)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${reward.pointsRequired} Poin',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: canRedeem ? () => _handleRedeem(reward) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: canRedeem ? 2 : 0,
                      ),
                      child: Text(
                        canRedeem ? 'Tukar Poin' : 'Poin Kurang',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Sub-tab 2: Voucher Saya (Voucher Aktif vs Riwayat Terpakai)
  Widget _buildMyVouchersTab() {
    if (_activeVouchers.isEmpty && _historyVouchers.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 48, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text(
                  'Anda belum memiliki voucher reward.\nTukarkan poin Anda di katalog hadiah!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 1. Voucher Aktif
          if (_activeVouchers.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                SizedBox(width: 8),
                Text(
                  'Voucher Aktif (Siap Pakai)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._activeVouchers.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildActiveVoucherCard(v),
                )),
          ],

          // 2. Riwayat Voucher Terpakai
          if (_historyVouchers.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Riwayat Voucher',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._historyVouchers.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildHistoryVoucherCard(v),
                )),
          ],
        ]),
      ),
    );
  }

  /// Kartu Voucher Aktif dengan QR Code, kode teks, nominal, dan badge "1x Pakai"
  Widget _buildActiveVoucherCard(VoucherModel voucher) {
    return FrostedGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      blurSigma: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  voucher.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '1x Pakai',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Potongan Diskon: ${Formatters.rupiah(voucher.discountAmount)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 14),

          // Area QR Code & Kode Teks
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showVoucherQrModal(voucher),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(4),
                      child: QrImageView(
                        data: voucher.voucherCode,
                        version: QrVersions.auto,
                        size: 64,
                        semanticsLabel: 'QR Voucher ${voucher.voucherCode}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KODE VOUCHER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        voucher.voucherCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher.createdAt != null
                            ? 'Diklaim: ${Formatters.tanggal(voucher.createdAt!)}'
                            : 'Voucher Siap Digunakan',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.primary),
                  tooltip: 'Salin Kode',
                  onPressed: () => _copyToClipboard(
                    voucher.voucherCode,
                    'Kode voucher ${voucher.voucherCode} disalin!',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Voucher Terpakai (Dimmed / Redup) dengan badge "Sudah Terpakai"
  Widget _buildHistoryVoucherCard(VoucherModel voucher) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    voucher.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Sudah Terpakai',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  voucher.voucherCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  Formatters.rupiah(voucher.discountAmount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (voucher.usedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Digunakan pada: ${Formatters.tanggal(voucher.usedAt!)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
