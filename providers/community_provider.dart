import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

/// 카테고리 기반 커뮤니티 피드 Provider
/// - 목록: GET /communities/{cid}/feed?category=free|qna|info&limit=10&cursor=...
/// - 무한스크롤: next_cursor 사용
class CommunityProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  // 카테고리별 피드 상태
  final Map<String, List<Map<String, dynamic>>> _feeds = {
    'free': [],
    'qna': [],
    'info': [],
  };
  final Map<String, bool> _loading = {'free': false, 'qna': false, 'info': false};
  final Map<String, bool> _hasMore = {'free': true, 'qna': true, 'info': true};
  final Map<String, String?> _cursor = {'free': null, 'qna': null, 'info': null};

  List<Map<String, dynamic>> feedOfCategory(String category) =>
      List.unmodifiable(_feeds[category] ?? const []);

  bool isFeedLoadingCategory(String category) => _loading[category] ?? false;

  bool feedHasMoreCategory(String category) => _hasMore[category] ?? false;

  Future<void> refreshFeedByCategory({
    required int cid,
    required String category, // 'free' | 'qna' | 'info'
    int limit = 10,
  }) async {
    _loading[category] = true;
    _cursor[category] = null;
    _hasMore[category] = true;
    _feeds[category] = [];
    notifyListeners();

    try {
      final res = await _dio.get('/communities/$cid/feed', queryParameters: {
        'category': category,
        'limit': limit,
      });
      final data = res.data ?? {};
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      _feeds[category] = items;
      _cursor[category] = data['next_cursor'];
      _hasMore[category] = _cursor[category] != null;
    } finally {
      _loading[category] = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreByCategory({
    required int cid,
    required String category,
    int limit = 10,
  }) async {
    if (_loading[category] == true || _hasMore[category] == false) return;
    _loading[category] = true;
    notifyListeners();

    try {
      final res = await _dio.get('/communities/$cid/feed', queryParameters: {
        'category': category,
        'limit': limit,
        if (_cursor[category] != null) 'cursor': _cursor[category],
      });
      final data = res.data ?? {};
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      _feeds[category] = [..._feeds[category]!, ...items];
      _cursor[category] = data['next_cursor'];
      _hasMore[category] = _cursor[category] != null;
    } finally {
      _loading[category] = false;
      notifyListeners();
    }
  }
}
