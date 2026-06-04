// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/auth_api.dart';

class AuthProvider extends ChangeNotifier {
  final _dio = ApiClient.I.dio;

  Map<String, dynamic>? _me;
  Map<String, dynamic>? get me => _me;
  bool get isLoggedIn => _me != null;

  String? _error;
  String? get error => _error;

  String _pickErr(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
      if (data is String && data.isNotEmpty) return data;
      return e.message ?? '네트워크 오류가 발생했어요.';
    }
    return '알 수 없는 오류가 발생했어요.';
  }

  Future<bool> login({required String usernameOrEmail, required String password}) async {
    try {
      _error = null;
      final data = await AuthApi.I.login(
        usernameOrEmail: usernameOrEmail.trim(),
        password: password,
      );
      final user = (data['user'] ?? data['me']) as Map?;
      if (user != null) {
        _me = user.cast<String, dynamic>();
        notifyListeners();
        return true;
      }
      final meRes = await _dio.get('/me');
      _me = (meRes.data as Map).cast<String, dynamic>();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchMe() async {
    try {
      final res = await _dio.get('/me');
      _me = (res.data as Map).cast<String, dynamic>();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await AuthApi.I.logout();
    } finally {
      _me = null;
      notifyListeners();
    }
  }

  // ----------------------- 내부 헬퍼 -----------------------

  Map<String, dynamic> _asMap(dynamic v) =>
      (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};

  /// data.user > user > me > profile > 루트
  Map<String, dynamic> _mutableUserMap() {
    _me ??= <String, dynamic>{};
    if (_me!['data'] is Map && (_me!['data'] as Map)['user'] is Map) {
      return (_me!['data'] as Map)['user'].cast<String, dynamic>();
    }
    for (final k in ['user', 'me', 'profile']) {
      if (_me![k] is Map) return (_me![k] as Map).cast<String, dynamic>();
    }
    return _me!;
  }

  void _mirrorStrings(Map<String, dynamic> into, Map<String, String> kvs) {
    for (final e in kvs.entries) {
      into[e.key] = e.value;
    }
  }

  // --------------------- 프로필 업데이트 ---------------------

  Future<void> updateProfile({
    String? nickname,
    String? intro,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      if (nickname != null) 'nickname': nickname,
      if (intro != null) 'intro': intro,
      if (avatarUrl != null) ...{
        'profile_img': avatarUrl,       // ✅ 서버 JSON에 맞춤
        'avatarUrl': avatarUrl,         // 클라 내부 호환
        'profile_image': avatarUrl,     // 혹시 다른 라우트에서 기대
        'avatar_url': avatarUrl,
      },
    }; // 서버 키가 다르면 맞춰 변경

    try {
      Response res;
      try {
        res = await _dio.patch('/me', data: body);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          res = await _dio.patch('/users/me', data: body);
        } else {
          rethrow;
        }
      }

      Map<String, dynamic>? updated;
      final data = res.data;
      if (data is Map) {
        if (data['user'] is Map) {
          updated = (data['user'] as Map).cast<String, dynamic>();
        } else if (data['me'] is Map) {
          updated = (data['me'] as Map).cast<String, dynamic>();
        } else if (data['data'] is Map) {
          final d = (data['data'] as Map);
          if (d['user'] is Map) {
            updated = (d['user'] as Map).cast<String, dynamic>();
          } else {
            updated = d.cast<String, dynamic>();
          }
        } else {
          updated = data.cast<String, dynamic>();
        }
      }

      _me ??= <String, dynamic>{};
      final target = _mutableUserMap();

      if (updated != null && updated.isNotEmpty) {
        target.addAll(updated);
        _me!.addAll(updated);
      } else {
        if (nickname != null) {
          for (final m in [_me!, target]) {
            _mirrorStrings(m, {
              'nickname': nickname,
              'displayName': nickname,
              'display_name': nickname,
              'name': (m['name'] ?? nickname).toString(),
            });
          }
        }
        if (intro != null) {
          for (final m in [_me!, target]) {
            _mirrorStrings(m, {
              'intro': intro,
              'bio': intro,
              'about': intro,
              'description': intro,
            });
          }
        }
        if (avatarUrl != null) {
          for (final m in [_me!, target]) {
            _mirrorStrings(m, {
              'avatar': avatarUrl,
              'avatar_url': avatarUrl,
              'profile_image': avatarUrl,
              'profile_image_url': avatarUrl,
              'avatarUrl': avatarUrl,
            });
            // ✅ 캐시 버스터(버전)
            final cur = (m['_avatar_v'] is int) ? m['_avatar_v'] as int : 0;
            m['_avatar_v'] = cur + 1;
          }
          // 루트에도 버전 유지(레이어 우선 탐색 대비)
          final cur = (_me!['_avatar_v'] is int) ? _me!['_avatar_v'] as int : 0;
          _me!['_avatar_v'] = cur + 1;
        }
      }

      _error = null;
      notifyListeners();
      // 필요시 서버와 완전 동기화: await fetchMe();
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      rethrow;
    }
  }
}
