// lib/core/auth_api.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'env.dart';

class AuthApi {
  AuthApi._();
  static final AuthApi I = AuthApi._();

  final _dio = ApiClient.I.dio;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'usernameOrEmail': usernameOrEmail,
      'password': password,
    });

    final data = (res.data as Map).cast<String, dynamic>();

    final String? access =
        data['access'] ?? data['accessToken'] ?? data['token'];
    final String? refresh =
        data['refresh'] ?? data['refreshToken'];
    if (access != null && access.isNotEmpty) {
      await _storage.write(key: Env.accessTokenKey, value: access);
    }
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: Env.refreshTokenKey, value: refresh);
    }
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/me');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // 서버 로그아웃 실패는 무시
    } finally {
      await _storage.delete(key: Env.accessTokenKey);
      await _storage.delete(key: Env.refreshTokenKey);
    }
  }
}
