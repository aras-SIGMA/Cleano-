import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveSession menyimpan token, user, dan email saat rememberMe aktif', () async {
      final session = SessionService.instance;
      const user = UserModel(
        id: 1,
        name: 'Kasir Cleano',
        email: 'kasir@cleano.id',
        phone: '081234567890',
        role: 'kasir',
        memberCode: 'MBR-0001',
        points: 100,
        tier: 'Gold',
      );

      await session.saveSession(
        token: 'dummy-jwt-token',
        user: user,
        rememberMe: true,
      );

      final token = await session.getToken();
      final savedUser = await session.getUser();
      final rememberMe = await session.getRememberMe();
      final savedEmail = await session.getSavedEmail();

      expect(token, 'dummy-jwt-token');
      expect(savedUser?.id, 1);
      expect(savedUser?.email, 'kasir@cleano.id');
      expect(rememberMe, isTrue);
      expect(savedEmail, 'kasir@cleano.id');
    });

    test('clearSession membersihkan token dan user', () async {
      final session = SessionService.instance;
      const user = UserModel(
        id: 2,
        name: 'Pelanggan Rina',
        email: 'rina@gmail.com',
        phone: '081234567891',
        role: 'pelanggan',
        memberCode: 'MBR-0002',
        points: 0,
        tier: 'Silver',
      );

      await session.saveSession(
        token: 'token-to-remove',
        user: user,
        rememberMe: true,
      );

      await session.clearSession();

      final token = await session.getToken();
      final savedUser = await session.getUser();
      // Saat rememberMe true, email tetap disimpan agar user tidak repot mengetik ulang
      final savedEmail = await session.getSavedEmail();

      expect(token, isNull);
      expect(savedUser, isNull);
      expect(savedEmail, 'rina@gmail.com');
    });

    test('clearSession menghapus email jika rememberMe false', () async {
      final session = SessionService.instance;
      const user = UserModel(
        id: 3,
        name: 'Guest',
        email: 'guest@cleano.id',
        phone: '081234567892',
        role: 'pelanggan',
        memberCode: 'MBR-0003',
        points: 0,
        tier: 'Silver',
      );

      await session.saveSession(
        token: 'temp-token',
        user: user,
        rememberMe: false,
      );

      await session.clearSession();

      final token = await session.getToken();
      final savedEmail = await session.getSavedEmail();

      expect(token, isNull);
      expect(savedEmail, isNull);
    });
  });
}
