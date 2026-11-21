import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Penyimpanan sesi lokal (Token, Profil Pengguna, dan Status Ingat Saya)
/// dengan in-memory cache untuk performa akses instan.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _keyToken = 'cleano_token';
  static const _keyUser = 'cleano_user';
  static const _keyRememberMe = 'cleano_remember_me';
  static const _keySavedEmail = 'cleano_saved_email';

  String? _cachedToken;
  UserModel? _cachedUser;

  Future<void> saveSession({
    required String token,
    required UserModel user,
    bool rememberMe = true,
  }) async {
    _cachedToken = token;
    _cachedUser = user;
    await ApiService.instance.saveToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setBool(_keyRememberMe, rememberMe);
    if (rememberMe) {
      await prefs.setString(_keySavedEmail, user.email);
    } else {
      await prefs.remove(_keySavedEmail);
    }
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_keyToken);
    return _cachedToken;
  }

  Future<UserModel?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cachedUser = UserModel.fromJson(map);
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedEmail);
  }

  Future<void> updateUser(UserModel user) async {
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    _cachedToken = null;
    _cachedUser = null;
    await ApiService.instance.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (!rememberMe) {
      await prefs.remove(_keySavedEmail);
      await prefs.remove(_keyRememberMe);
    }
  }
}
