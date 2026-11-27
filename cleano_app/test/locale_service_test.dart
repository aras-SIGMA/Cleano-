import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/l10n/app_localizations.dart';
import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/screens/auth/login_screen.dart';
import 'package:cleano_app/screens/pelanggan/pelanggan_profile_screen.dart';
import 'package:cleano_app/services/locale_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleService & Multi-Language Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocaleService.instance.setLocale('id');
    });

    test('Default locale adalah id dan setLocale menyimpan ke SharedPreferences', () async {
      expect(LocaleService.instance.locale.value.languageCode, 'id');
      expect(LocaleService.instance.intlLocale, 'id_ID');

      await LocaleService.instance.setLocale('en');
      expect(LocaleService.instance.locale.value.languageCode, 'en');
      expect(LocaleService.instance.intlLocale, 'en_US');

      // Reset lalu muat ulang dari SharedPreferences
      LocaleService.instance.locale.value = const Locale('id');
      await LocaleService.instance.load();
      expect(LocaleService.instance.locale.value.languageCode, 'en');
    });

    testWidgets('Mengubah bahasa dari Profil Pelanggan langsung memperbarui teks UI ke English', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const user = UserModel(
        id: 2,
        name: 'Rina Marlina',
        email: 'rina@cleano.id',
        phone: '081234567891',
        role: 'pelanggan',
        memberCode: 'MBR-0001',
        points: 150,
        tier: 'Gold',
      );

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: LocaleService.instance.locale,
          builder: (context, currentLocale, _) => MaterialApp(
            locale: currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const PelangganProfileScreen(user: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Awalnya berbahasa Indonesia
      expect(find.text('Profil & Akun Saya'), findsOneWidget);
      expect(find.text('Bahasa Aplikasi'), findsOneWidget);

      // Buka pemilih bahasa dan pilih English
      await tester.scrollUntilVisible(find.text('Bahasa Aplikasi'), 200);
      await tester.tap(find.text('Bahasa Aplikasi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Judul & seksi otomatis berubah ke English
      expect(find.text('My Profile & Account'), findsOneWidget);
      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('ACCOUNT & SECURITY'), findsOneWidget);
    });

    testWidgets('Layar lain (LoginScreen) ikut berubah ke English saat locale en aktif', (tester) async {
      await LocaleService.instance.setLocale('en');

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: LocaleService.instance.locale,
          builder: (context, currentLocale, _) => MaterialApp(
            locale: currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to your account to manage laundry orders and access exclusive rewards.'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Cashier'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
    });
  });
}
