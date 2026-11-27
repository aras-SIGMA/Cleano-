import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/utils/formatters.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'session_service.dart';

/// Service autentikasi: login, registrasi, ambil profil terkini, dan logout.
class AuthService {
  AuthService({
    ApiService? apiService,
    SessionService? sessionService,
  })  : _api = apiService ?? ApiService.instance,
        _session = sessionService ?? SessionService.instance;

  static final AuthService instance = AuthService();

  final ApiService _api;
  final SessionService _session;

  /// Login dengan email & password.
  Future<UserModel> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final res = await _api.post(
      ApiConstants.login,
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final payload = res.data;
    if (payload is! Map<String, dynamic> || payload['data'] is! Map) {
      throw const ApiException('Format respons server tidak valid.');
    }

    final data = payload['data'] as Map<String, dynamic>;
    final token = data['token']?.toString() ?? '';
    final rawUser = data['user'];
    if (token.isEmpty || rawUser is! Map<String, dynamic>) {
      throw const ApiException('Data login tidak lengkap.');
    }

    final user = UserModel.fromJson(rawUser);

    await _api.saveToken(token);
    await _session.saveSession(
      token: token,
      user: user,
      rememberMe: rememberMe,
    );

    return user;
  }

  /// Registrasi akun pelanggan baru.
  Future<({UserModel user, String token})> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final normalizedPhone = Formatters.normalizePhone(phone);

    final res = await _api.post(
      ApiConstants.register,
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'phone': normalizedPhone,
      },
    );

    final payload = res.data;
    if (payload is! Map<String, dynamic> || payload['data'] is! Map) {
      throw const ApiException('Format respons server tidak valid.');
    }

    final data = payload['data'] as Map<String, dynamic>;
    final token = data['token']?.toString() ?? '';
    final rawUser = data['user'];
    if (token.isEmpty || rawUser is! Map<String, dynamic>) {
      throw const ApiException('Data registrasi tidak lengkap.');
    }

    final user = UserModel.fromJson(rawUser);

    await _api.saveToken(token);
    await _session.saveSession(
      token: token,
      user: user,
      rememberMe: true,
    );

    return (user: user, token: token);
  }

  /// Membaca profil pengguna dari server (GET /api/users/me).
  Future<UserModel?> getMe() async {
    try {
      final res = await _api.get(ApiConstants.userMe);
      final payload = res.data;
      if (payload is Map<String, dynamic> && payload['data'] is Map) {
        final user = UserModel.fromJson(payload['data'] as Map<String, dynamic>);
        await _session.updateUser(user);
        return user;
      }
    } on ApiException catch (e) {
      // Jika token kedaluwarsa (401), hapus sesi lokal
      if (e.statusCode == 401) {
        await logout();
      }
      rethrow;
    }
    return null;
  }

  /// Mengubah foto profil akun yang sedang login (PATCH /api/users/me/avatar).
  Future<UserModel> updateAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final lower = filename.toLowerCase();
    final subtype = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
            ? 'webp'
            : 'jpeg';
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType('image', subtype),
      ),
    });

    final res = await _api.patchMultipart(ApiConstants.userAvatar, formData);
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      final user = UserModel.fromJson(payload['data'] as Map<String, dynamic>);
      await _session.updateUser(user);
      return user;
    }
    throw const ApiException('Format respons server tidak valid.');
  }

  /// Mengubah kata sandi akun yang sedang login (PATCH /api/auth/change-password).
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.patch(
      ApiConstants.changePassword,
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  /// Mengeluarkan sesi login.
  Future<void> logout() async {
    await _api.clearToken();
    await _session.clearSession();
  }
}
