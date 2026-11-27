import 'package:intl/intl.dart';

import '../../services/locale_service.dart';

/// Formatter tampilan: Rupiah, tanggal, sensor telepon, normalisasi nomor telepon.
class Formatters {
  const Formatters._();

  /// `21000` -> `Rp 21.000`
  static String rupiah(num value) {
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(value);
    } catch (_) {
      final str = value.toInt().toString();
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return 'Rp ${str.replaceAllMapped(reg, (m) => '${m[1]}.')}';
    }
  }

  /// `4.5` -> `4,50 kg`
  static String berat(num kg) => '${kg.toStringAsFixed(2).replaceAll('.', ',')} kg';

  /// Format tanggal: `19 Nov 2026`
  static String tanggal(DateTime value) {
    final loc = LocaleService.instance.intlLocale;
    try {
      return DateFormat('dd MMM yyyy', loc).format(value);
    } catch (_) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    }
  }

  /// Format jam: `14:30`
  static String jam(DateTime value) {
    final loc = LocaleService.instance.intlLocale;
    try {
      return DateFormat('HH:mm', loc).format(value);
    } catch (_) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Menormalkan nomor telepon/WhatsApp: +62812... atau 62812... menjadi 0812...
  static String normalizePhone(String input) {
    final digits = input.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith('+62')) return '0${digits.substring(3)}';
    if (digits.startsWith('62')) return '0${digits.substring(2)}';
    return digits;
  }

  /// Menyensor nomor WA untuk privasi: `0812-****-7890`.
  static String sensorTelepon(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return phone;

    final depan = digits.substring(0, 4);
    final belakang = digits.substring(digits.length - 4);
    return '$depan-****-$belakang';
  }
}
