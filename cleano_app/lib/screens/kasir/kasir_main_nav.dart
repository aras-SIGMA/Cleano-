import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import 'kasir_dashboard_screen.dart';
import 'kasir_master_screen.dart';
import 'kasir_orders_screen.dart';
import 'pos_create_order_screen.dart';
import '../../widgets/frosted_glass_card.dart';

/// Navigasi Utama Portal Kasir Cleano:
/// - Responsif: NavigationRail di layar lebar (tablet/desktop) dan NavigationBar di ponsel
/// - Tab 0: Dashboard Operasional
/// - Tab 1: POS Transaksi Baru
/// - Tab 2: Daftar Pesanan & Estafet Mesin
/// - Tab 3: Master Data Outlet
/// - Tab 4: Profil Kasir & Logout
class KasirMainNav extends StatefulWidget {
  const KasirMainNav({super.key});

  @override
  State<KasirMainNav> createState() => _KasirMainNavState();
}

class _KasirMainNavState extends State<KasirMainNav> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0}; // Hanya tab beranda yang dimuat di awal untuk cold-start instan
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final cached = await SessionService.instance.getUser();
    if (mounted && cached != null) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    try {
      final fresh = await AuthService.instance.getMe();
      if (mounted && fresh != null) {
        setState(() {
          _user = fresh;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun kasir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

  if (confirm != true || !mounted) return;

    await AuthService.instance.logout();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.splash, (r) => false);
  }

  Widget _buildTabBody(int index) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return switch (index) {
      0 => KasirDashboardScreen(
          onNavigateToOrders: () => _onTabChanged(2),
        ),
      1 => PosCreateOrderScreen(
          onOrderCreated: (order) {
            _onTabChanged(2);
          },
        ),
      2 => const KasirOrdersScreen(),
      3 => const KasirMasterScreen(),
      4 => _buildProfileView(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final children = List.generate(5, _buildTabBody);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onTabChanged,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Image.asset(
                      'assets/logo/cleano-icon.png',
                      width: 32,
                      height: 32,
                      semanticLabel: 'Cleano',
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                          tooltip: 'Keluar',
                          onPressed: _handleLogout,
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Beranda'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add_shopping_cart_outlined),
                      selectedIcon: Icon(Icons.add_shopping_cart_rounded),
                      label: Text('Catat Cucian'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Pesanan'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.store_outlined),
                      selectedIcon: Icon(Icons.store_rounded),
                      label: Text('Kelola Toko'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Akun'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AppTheme.border),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: children,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _currentIndex,
            children: children,
          ),
          bottomNavigationBar: _buildFloatingBottomBar(),
        );
      },
    );
  }

  Widget _buildFloatingBottomBar() {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
      (Icons.add_shopping_cart_outlined, Icons.add_shopping_cart_rounded, 'Catat'),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Pesanan'),
      (Icons.store_outlined, Icons.store_rounded, 'Toko'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Akun'),
    ];

    return RepaintBoundary(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FrostedGlassCard(
            enableBlur: true,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            borderRadius: 32,
            blurSigma: 20,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (idx) {
                final isSelected = _currentIndex == idx;
                final item = items[idx];

                return InkWell(
                  onTap: () => _onTabChanged(idx),
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 12 : 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.$2 : item.$1,
                          size: 22,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Akun Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.surfaceSubtle,
                        child: const Icon(
                          Icons.store_mall_directory_rounded,
                          color: AppTheme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?.name ?? 'Kasir Cleano',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ROLE: KASIR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _InfoRow(label: 'Email', value: _user?.email ?? '-'),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Nomor HP', value: _user?.phone ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
              label: const Text(
                'Keluar (Logout)',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
