import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // wajib sebelum DateFormat/NumberFormat memakai locale 'id_ID'
  await initializeDateFormatting('id_ID');
  runApp(const CleanoApp());
}

class CleanoApp extends StatelessWidget {
  const CleanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleano',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _BootstrapScreen(),
    );
  }
}

/// Layar sementara sampai navigator portal kasir/pelanggan dibuat.
class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '(belum diisi)';

    return Scaffold(
      appBar: AppBar(title: const Text('Cleano')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_laundry_service_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Cleano',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Smart Laundry POS & Order Tracking',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              SelectableText(
                'API: $baseUrl',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}