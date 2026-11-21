import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';

/// Klien HTTP tunggal. Otomatis menyisipkan `Authorization: Bearer <token>`
/// dari SharedPreferences dan menormalkan error backend menjadi [ApiException].
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const _tokenKey = 'cleano_token';
  String? _cachedToken;

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

  Future<String?> readToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _guard(() => _dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _guard(() => _dio.post<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _guard(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _guard(() => _dio.put<T>(path, data: data));

  Future<Response<T>> delete<T>(String path) =>
      _guard(() => _dio.delete<T>(path));

  Future<Response<T>> postMultipart<T>(String path, FormData data) =>
      _guard(() => _dio.post<T>(path, data: data));

  /// Membungkus error Dio menjadi pesan yang siap ditampilkan ke UI.
  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Error seragam untuk seluruh aplikasi, mengikuti format backend:
/// `{ "success": false, "message": "..." }`
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    final body = res?.data;

    if (body is Map && body['message'] is String) {
      return ApiException(body['message'] as String, statusCode: res?.statusCode);
    }

    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Koneksi ke server habis waktu. Periksa jaringan Anda.',
      DioExceptionType.connectionError =>
        'Tidak dapat menghubungi server. Periksa koneksi dan alamat API.',
      DioExceptionType.badCertificate => 'Sertifikat server tidak valid.',
      _ => 'Terjadi kesalahan tak terduga.',
    };

    return ApiException(message, statusCode: res?.statusCode);
  }

  @override
  String toString() => message;
}