import 'package:cleano_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters', () {
    test('rupiah memakai pemisah ribuan Indonesia', () {
      expect(Formatters.rupiah(21000), contains('21'));
      expect(Formatters.rupiah(0), contains('0'));
    });

    test('berat memakai koma desimal', () {
      expect(Formatters.berat(4.5), '4,50 kg');
      expect(Formatters.berat(10), '10,00 kg');
    });

    test('nomor WA disensor di tengah', () {
      expect(Formatters.sensorTelepon('081234567890'), '0812-****-7890');
      expect(Formatters.sensorTelepon('0812-3456-7890'), '0812-****-7890');
    });

    test('nomor terlalu pendek dikembalikan apa adanya', () {
      expect(Formatters.sensorTelepon('08123'), '08123');
    });

    test('normalizePhone mengubah +62 dan 62 ke 08', () {
      expect(Formatters.normalizePhone('+6281234567890'), '081234567890');
      expect(Formatters.normalizePhone('6281234567890'), '081234567890');
      expect(Formatters.normalizePhone('0812-3456-7890'), '081234567890');
      expect(Formatters.normalizePhone('  0812 3456 7890  '), '081234567890');
    });
  });
}