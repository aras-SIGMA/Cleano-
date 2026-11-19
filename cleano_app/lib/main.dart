import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Memuat konfigurasi .env dengan fallback aman
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fallback jika berkas .env belum tersedia
  }

  // Wajib sebelum DateFormat / NumberFormat memakai locale 'id_ID'
  try {
    await initializeDateFormatting('id_ID');
  } catch (_) {}

  runApp(const CleanoApp());
}

/// Widget root aplikasi Cleano.
class CleanoApp extends StatelessWidget {
  const CleanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleano — Smart Laundry POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
    );
  }
}
