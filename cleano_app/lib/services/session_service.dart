import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Penyimpanan sesi lokal (Token, Profil Pengguna, dan Status Ingat Saya).
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _keyToken = 'cleano_token';
  static const _keyUser = 'cleano_user';
  static const _keyRememberMe = 'cleano_remember_me';
  static const _keySavedEmail = 'cleano_saved_email';

  Future<void> saveSession({
    required String token,
    required UserModel user,
    bool rememberMe = true,
  }) async {
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
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
