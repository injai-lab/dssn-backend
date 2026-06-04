// lib/api_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'env.dart';

class ApiClient {
  ApiClient._internal() {
    final base = BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: Env.connectTimeout,   // Duration
      receiveTimeout: Env.receiveTimeout,   // Duration
      contentType: 'application/json',
      responseType: ResponseType.json,
    );

    _dio = Dio(base);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _storage.read(key: Env.accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        handler.next(options);
      },
      onError: (e, handler) async {
        final req = e.requestOptions;
        final isUnauthorized = e.response?.statusCode == 401;
        final alreadyRetried = req.extra['__ret'] == true;

        if (!isUnauthorized || alreadyRetried) {
          return handler.next(e);
        }

        try {
          final newToken = await _ensureRefreshedToken();
          if (newToken == null) {
            return handler.next(e);
          }

          final opts = Options(
            method: req.method,
            headers: {
              ...?req.headers,
              'Authorization': 'Bearer $newToken',
            },
            responseType: req.responseType,
            contentType: req.contentType,
            followRedirects: req.followRedirects,
            validateStatus: req.validateStatus,
            receiveDataWhenStatusError: req.receiveDataWhenStatusError,
            sendTimeout: req.sendTimeout,       // Duration?
            receiveTimeout: req.receiveTimeout, // Duration?
          );

          final res = await _dio.request(
            req.path,
            data: req.data,
            queryParameters: req.queryParameters,
            options: opts.copyWith(extra: {
              ...?req.extra,
              '__ret': true,
            }),
            cancelToken: req.cancelToken,
            onReceiveProgress: req.onReceiveProgress,
            onSendProgress: req.onSendProgress,
          );

          return handler.resolve(res);
        } catch (err, st) {
          if (kDebugMode) {
            print('Retry after refresh failed: $err\n$st');
          }
          return handler.next(e);
        }
      },
    ));
  }

  static final ApiClient I = ApiClient._internal();

  late final Dio _dio;
  Dio get dio => _dio;

  final _storage = const FlutterSecureStorage();
  Future<String?>? _refreshing;

  Future<String?> _ensureRefreshedToken() async {
    // 이미 진행 중이면 그 결과만 기다림
    if (_refreshing != null) {
      try {
        return await _refreshing!;
      } catch (_) {
        // 진행 중이던 리프레시가 실패했을 수 있음
        return null;
      }
    }

    final completer = Completer<String?>();
    _refreshing = completer.future;

    try {
      final refresh = await _storage.read(key: Env.refreshTokenKey);
      if (refresh == null || refresh.isEmpty) {
        completer.complete(null);
        return null;
      }

      final res = await _dio.post('/auth/refresh', data: {'refresh': refresh});
      final data = (res.data as Map).cast<String, dynamic>();

      // (괄호로 명확화) access | accessToken | token
      final String? access = (data['access'] as String?)
          ?? (data['accessToken'] as String?)
          ?? (data['token'] as String?);

      final String? refreshNew =
          (data['refresh'] as String?) ?? (data['refreshToken'] as String?);

      if (access == null || access.isEmpty) {
        completer.complete(null);
        return null;
      }

      await _storage.write(key: Env.accessTokenKey, value: access);
      if (refreshNew != null && refreshNew.isNotEmpty) {
        await _storage.write(key: Env.refreshTokenKey, value: refreshNew);
      }

      completer.complete(access);
      return access;
    } catch (e, s) {
      if (kDebugMode) {
        print('Refresh failed: $e\n$s');
      }
      completer.complete(null);
      return null;
    } finally {
      _refreshing = null; // 항상 초기화 (성공/실패 불문)
    }
  }
}
