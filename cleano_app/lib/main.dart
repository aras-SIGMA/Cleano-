import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'services/locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Memuat konfigurasi .env dengan fallback aman
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fallback jika berkas .env belum tersedia
  }

  // Wajib sebelum DateFormat / NumberFormat memakai locale 'id_ID' atau 'en_US'
  try {
    await initializeDateFormatting('id_ID');
    await initializeDateFormatting('en_US');
  } catch (_) {}

  await LocaleService.instance.load();

  runApp(const CleanoApp());
}

/// Widget root aplikasi Cleano.
class CleanoApp extends StatelessWidget {
  const CleanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.instance.locale,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          title: 'Cleano — Smart Laundry POS',
          debugShowCheckedModeBanner: false,
          locale: currentLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
          initialRoute: AppRouter.splash,
          routes: AppRouter.routes,
        );
      },
    );
  }
}
