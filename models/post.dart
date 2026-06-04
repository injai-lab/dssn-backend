// lib/providers/post_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';

class PostProvider extends ChangeNotifier {
  final _dio = ApiClient.I.dio;

  // 상태
  final List<dynamic> _items = [];
  List<dynamic> get items => List.unmodifiable(_items);

  String? _nextCursor;
  bool _initialized = false;
  bool _loading = false;       // 페이지 로드 중
  bool _refreshing = false;    // 당겨서 새로고침
  String? _error;

  bool get isLoading => _loading;
  bool get isRefreshing => _refreshing;
  bool get hasMore => _nextCursor != null;
  String? get errorMessage => _error;

  /// 첫 진입 시 한 번만 초기 페이지 로드
  Future<void> initIfEmpty({int limit = 10}) async {
    if (_initialized) return;
    _initialized = true;
    await refresh(limit: limit);
  }

  /// 새로고침: 처음부터 다시
  Future<void> refresh({int limit = 10}) async {
    if (_refreshing) return;
    _refreshing = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.get('/feed/home', queryParameters: {
        'limit': limit,
      });
      final data = res.data as Map<String, dynamic>;
      final list = (data['items'] ?? data['posts'] ?? data['data'] ?? []) as List;
      _items
        ..clear()
        ..addAll(list);
      _nextCursor = (data['next_cursor'] ?? data['nextCursor']) as String?;
    } on DioException catch (e) {
      _error = _pickErr(e);
    } catch (e) {
      _error = '피드를 불러오지 못했어요.';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// 다음 페이지 로드(무한 스크롤)
  Future<void> loadMore({int limit = 10}) async {
    if (_loading || _nextCursor == null) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.get('/feed/home', queryParameters: {
        'limit': limit,
        'cursor': _nextCursor,
      });
      final data = res.data as Map<String, dynamic>;
      final list = (data['items'] ?? data['posts'] ?? data['data'] ?? []) as List;
      _items.addAll(list);
      _nextCursor = (data['next_cursor'] ?? data['nextCursor']) as String?;
    } on DioException catch (e) {
      _error = _pickErr(e);
    } catch (e) {
      _error = '다음 글을 불러오지 못했어요.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 글 작성
  Future<String?> createPost({
    required String content,
    List<String>? fileUrls, // 서버 규격에 맞춰 필요 시 사용
  }) async {
    try {
      final res = await _dio.post('/feed/home', data: {
        'content': content,
        if (fileUrls != null && fileUrls.isNotEmpty) 'files': fileUrls,
      });
      // 서버가 새 글 객체를 반환한다고 가정
      final created = res.data['post'] ?? res.data;
      // 최신 글을 맨 위로
      _items.insert(0, created);
      notifyListeners();
      return null;
    } on DioException catch (e) {
      return _pickErr(e);
    } catch (_) {
      return '글을 올리지 못했어요.';
    }
  }

  String _pickErr(DioException e) {
    final m = e.response?.data;
    if (m is Map && m['message'] is String) return m['message'] as String;
    if (m is String && m.isNotEmpty) return m;
    return '네트워크 오류가 발생했어요.';
    // 디버그에선 e.message 로깅해도 됨
  }
}
