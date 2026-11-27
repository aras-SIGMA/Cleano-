import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kelola bahasa aktif ('id'/'en') secara reaktif dan simpan di SharedPreferences.
class LocaleService {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  static const _keyLocale = 'cleano_locale';
  static const supportedCodes = ['id', 'en'];

  final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('id'));

  /// Kode locale untuk `intl` (`id_ID` atau `en_US`).
  String get intlLocale => locale.value.languageCode == 'en' ? 'en_US' : 'id_ID';

  /// Memuat bahasa tersimpan dari SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLocale);
    if (code != null && supportedCodes.contains(code)) {
      locale.value = Locale(code);
    }
  }

  /// Mengubah bahasa aktif dan menyimpannya ke SharedPreferences.
  Future<void> setLocale(String languageCode) async {
    final normalized = supportedCodes.contains(languageCode) ? languageCode : 'id';
    locale.value = Locale(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, normalized);
  }
}
