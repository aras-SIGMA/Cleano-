import 'package:cleano_app/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('fromJson membaca format snake_case backend', () {
      final json = {
        'id': 1,
        'name': 'Kasir Cleano',
        'email': 'kasir@cleano.id',
        'phone': '081234567890',
        'role': 'kasir',
        'member_code': 'MBR-0001',
        'points': 150,
        'tier': 'Gold',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 1);
      expect(user.name, 'Kasir Cleano');
      expect(user.email, 'kasir@cleano.id');
      expect(user.role, 'kasir');
      expect(user.isKasir, isTrue);
      expect(user.isPelanggan, isFalse);
      expect(user.memberCode, 'MBR-0001');
      expect(user.points, 150);
      expect(user.tier, 'Gold');
    });

    test('toJson menghasilkan representasi yang konsisten', () {
      const user = UserModel(
        id: 2,
        name: 'Rina',
        email: 'rina@gmail.com',
        phone: '081234567891',
        role: 'pelanggan',
        memberCode: 'MBR-0002',
        points: 0,
        tier: 'Silver',
      );

      final json = user.toJson();

      expect(json['id'], 2);
      expect(json['name'], 'Rina');
      expect(json['role'], 'pelanggan');
      expect(user.isPelanggan, isTrue);
      expect(user.isKasir, isFalse);
    });

    test('toleran terhadap tipe data string untuk id dan points', () {
      final json = {
        'id': '99',
        'name': 'Budi',
        'email': 'budi@gmail.com',
        'phone': '081234567899',
        'role': 'pelanggan',
        'member_code': 'MBR-0099',
        'points': '350',
        'tier': 'Platinum',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 99);
      expect(user.points, 350);
    });
  });
}
