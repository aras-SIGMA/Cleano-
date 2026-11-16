import 'package:intl/intl.dart';

/// Formatter tampilan: Rupiah, tanggal, nomor WA tersensor, berat.
class Formatters {
  const Formatters._();

  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _tanggal = DateFormat('dd MMM yyyy', 'id_ID');
  static final _tanggalJam = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  static final _jam = DateFormat('HH:mm', 'id_ID');

  /// `21000` -> `Rp 21.000`
  static String rupiah(num value) => _rupiah.format(value);

  /// `4.5` -> `4,50 kg`
  static String berat(num kg) => '${kg.toStringAsFixed(2).replaceAll('.', ',')} kg';

  static String tanggal(DateTime value) => _tanggal.format(value);

  static String tanggalJam(DateTime value) => _tanggalJam.format(value);

  static String jam(DateTime value) => _jam.format(value);

  /// Menyensor nomor WA untuk ditampilkan ke kasir: `0812-****-7890`.
  /// Format asli tetap dipakai untuk pencarian.
  static String sensorTelepon(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return phone;

    final depan = digits.substring(0, 4);
    final belakang = digits.substring(digits.length - 4);
    return '$depan-****-$belakang';
  }
}