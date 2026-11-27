import 'dart:async';

import 'package:flutter/material.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../widgets/language_picker_sheet.dart';

/// Layar pembuka (Splash / Welcome Screen) dengan pengecekan sesi otomatis.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final token = await SessionService.instance.getToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() => _isChecking = false);
      return;
    }

    // Prioritaskan profil cache untuk cold-start instan (<50ms)
    final cachedUser = await SessionService.instance.getUser();
    if (!mounted) return;

    if (cachedUser != null) {
      final destination = cachedUser.isKasir
          ? AppRouter.kasir
          : AppRouter.pelanggan;
      Navigator.of(context).pushReplacementNamed(destination);

      // Sinkronisasi profil terbaru di latar belakang tanpa memblokir startup
      unawaited(
        AuthService.instance
            .getMe()
            .then((fresh) async {
              if (fresh != null) {
                await SessionService.instance.updateUser(fresh);
              }
            })
            .catchError((_) {}),
      );
      return;
    }

    // Jika belum ada cache profil, fetch dari server
    try {
      final user = await AuthService.instance.getMe();
      if (!mounted) return;

      if (user != null) {
        await SessionService.instance.updateUser(user);
        if (!mounted) return;
        final destination = user.isKasir
            ? AppRouter.kasir
            : AppRouter.pelanggan;
        Navigator.of(context).pushReplacementNamed(destination);
        return;
      }
    } catch (_) {
      // Server error atau offline
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Pusatkan kolom dan batasi lebar 460 px pada layar lebar.
    final horizontalPadding = width > 516 ? (width - 460) / 2 : 28.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: Column(
              children: [
                // Header Logo
                Image.asset(
                  'assets/logo/cleano-logo-horizontal-white.png',
                  height: 40,
                  semanticLabel: 'Cleano',
                ),

                const Spacer(),

                // Center Illustration Card
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo/cleano-icon.png',
                      width: 104,
                      height: 104,
                      semanticLabel: 'Logo Cleano',
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Title & Subtitle
                const Text(
                  'Smart Laundry POS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.splashSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

                const Spacer(),

                // Action Buttons or Loader
                if (_isChecking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.login);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.l10n.login,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.register);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.l10n.signUp,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
