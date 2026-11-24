import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/state_view.dart';
import 'pelanggan_qr_card_screen.dart';
import 'pelanggan_rewards_screen.dart';
import 'pelanggan_tracking_screen.dart';

/// Navigasi Utama Portal Pelanggan Cleano (3 Tab):
/// - Tab 0: Lacak Cucian Real-Time (M7)
/// - Tab 1: Kartu Member & QR (M8)
/// - Tab 2: Hadiah & Saldo Poin Loyalti (M9)
class PelangganMainNav extends StatefulWidget {
  const PelangganMainNav({super.key});

  @override
  State<PelangganMainNav> createState() => _PelangganMainNavState();
}

class _PelangganMainNavState extends State<PelangganMainNav> {
  int _currentIndex = 0;
  UserModel? _user;
  bool _isLoading = true;
  String? _profileError;

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
      if (mounted) {
        setState(() {
          _user = fresh ?? _user;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_user == null) _profileError = 'Gagal memuat profil. Periksa koneksi Anda.';
        });
      }
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun pelanggan?'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFEBF4FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEBF4FF),
        body: StateErrorView(
          message: _profileError ?? 'Profil tidak tersedia.',
          onRetry: () {
            setState(() {
              _isLoading = true;
              _profileError = null;
            });
            _loadProfile();
          },
        ),
      );
    }

    final children = [
      PelangganTrackingScreen(user: _user, onLogout: _handleLogout),
      PelangganQrCardScreen(user: _user, onLogout: _handleLogout),
      PelangganRewardsScreen(user: _user, onLogout: _handleLogout),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        if (isWide) {
          return Scaffold(
            backgroundColor: const Color(0xFFEBF4FF),
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
                          tooltip: 'Logout',
                          onPressed: _handleLogout,
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.local_laundry_service_outlined),
                      selectedIcon: Icon(Icons.local_laundry_service_rounded),
                      label: Text('Lacak'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.qr_code_2_outlined),
                      selectedIcon: Icon(Icons.qr_code_2_rounded),
                      label: Text('Kartu Member'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.card_giftcard_outlined),
                      selectedIcon: Icon(Icons.card_giftcard_rounded),
                      label: Text('Hadiah'),
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
          backgroundColor: const Color(0xFFEBF4FF),
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
      (Icons.local_laundry_service_outlined, Icons.local_laundry_service_rounded, 'Lacak'),
      (Icons.qr_code_2_outlined, Icons.qr_code_2_rounded, 'Kartu Member'),
      (Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, 'Hadiah'),
    ];

    return RepaintBoundary(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FrostedGlassCard(
            enableBlur: true,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      horizontal: isSelected ? 18 : 12,
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
}
