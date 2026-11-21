import 'package:flutter/material.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/kasir/kasir_main_nav.dart';
import '../../screens/pelanggan/pelanggan_main_nav.dart';
import '../../screens/splash_screen.dart';

/// Rute navigasi aplikasi Cleano.
class AppRouter {
  const AppRouter._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const kasir = '/kasir';
  static const pelanggan = '/pelanggan';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        kasir: (context) => const KasirMainNav(),
        pelanggan: (context) => const PelangganMainNav(),
      };
}
