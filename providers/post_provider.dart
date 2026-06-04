// lib/providers/post_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

/// 홈 피드가 속한 커뮤니티 id (네 규칙: write_post_screen에서 쓰는 곳)
const int kHomeCommunityId = 1;

class PostProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  // 목록 상태
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  String? _cursor; // 서버 커서(문자열일 수 있음 → int 변환 금지)
  bool _hasMore = true;
  bool _loading = false;
  bool get hasMore => _hasMore;
  bool get loading => _loading;

  // 에러 메시지
  String? _error;
  String? get error => _error;

  // ────────────────────────────────────────────────────────────────────────────
  // 유틸: 에러 메시지 뽑기
  String _pickErr(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
      if (data is String && data.isNotEmpty) return data;
      return e.message ?? '네트워크 오류가 발생했어요.';
    }
    return '알 수 없는 오류가 발생했어요.';
  }

  // 홈 전용 판별자: 카테고리/보드 없음 + community_id==kHomeCommunityId
  bool _isHomePost(Map<String, dynamic> p) {
    final dynamic cat = p['category']; // 'free' | 'qna' | 'info' (커뮤니티 글이면 채워짐)
    final dynamic boardId = p['board_id'] ?? p['boardId'];
    final String? cid = (p['community_id'] ?? p['communityId'])?.toString();

    final bool noCategory =
        cat == null || (cat is String && cat.trim().isEmpty);
    final bool noBoard =
        boardId == null || boardId.toString().trim().isEmpty;

    // community_id가 아예 없는 응답이면(구형 API), 홈 글로 간주하도록 완화
    final bool inHomeCommunity =
        (cid == null) || (cid == kHomeCommunityId.toString());

    return (noCategory && noBoard && inHomeCommunity);
  }

  List<Map<String, dynamic>> _castList(List raw) {
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 초기화/리셋
  Future<void> refreshHome({int limit = 10}) async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _error = null;
    notifyListeners();
    await fetchMoreHome(limit: limit);
  }

  // 홈 피드 페이지네이션
  Future<void> fetchMoreHome({int limit = 10}) async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.get('/feed/home', queryParameters: {
        'limit': limit,
        if (_cursor != null) 'cursor': _cursor,
        // 서버가 지원한다면 홈 전용 힌트 파라미터도 같이 넘김(무시해도 됨)
        'community_id': kHomeCommunityId,
        'home_only': 1,
      });

      final data = (res.data as Map).cast<String, dynamic>();
      final list = (data['items'] ?? data['data'] ?? data['posts'] ?? []) as List;
      final nextCursor = data['nextCursor'];

      // 1) 캐스팅
      final pageRaw = _castList(list);

      // 2) 홈 전용 필터
      final page = pageRaw.where(_isHomePost).toList();

      _items.addAll(page);
      _cursor = (nextCursor is String && nextCursor.isNotEmpty) ? nextCursor : null;
      _hasMore = _cursor != null;
    } catch (e) {
      _error = _pickErr(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 글쓰기(홈)
  /// title|content 중 하나는 반드시 채워야 하며,
  /// files: 업로드된 파일 URL 배열. (없으면 빈 배열)
  Future<Map<String, dynamic>?> createHomePost({
    String? title,
    String? content,
    List<String> files = const [],
  }) async {
    try {
      final body = <String, dynamic>{
        // 홈 글임을 서버에 명시
        'community_id': kHomeCommunityId,
      };
      if (title != null && title.trim().isNotEmpty) body['title'] = title.trim();
      if (content != null && content.trim().isNotEmpty) body['content'] = content.trim();
      if (files.isNotEmpty) body['files'] = files;

      final res = await _dio.post('/feed/home', data: body);
      final created = (res.data as Map).cast<String, dynamic>();

      // 방어적으로 한 번 더 필터 후 추가
      if (_isHomePost(created)) {
        _items.insert(0, created); // 최상단에 삽입
        notifyListeners();
      }
      return created;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 상호작용 토글 공통 헬퍼
  Future<Map<String, dynamic>?> _toggleAndMerge(
      int postId,
      String endpoint,
      ) async {
    try {
      final res = await _dio.post('$endpoint/$postId');
      final data = (res.data as Map).cast<String, dynamic>();

      // 목록에서 해당 포스트 찾아서 필드 병합
      final idx = _items.indexWhere((e) =>
      (e['id'] == postId) || (e['id']?.toString() == postId.toString()));
      if (idx >= 0) {
        final updated = {..._items[idx], ...data};
        _items[idx] = updated;
        notifyListeners();
      }
      return data;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }

  // 좋아요/북마크/리포스트
  Future<Map<String, dynamic>?> toggleLike(int postId) async {
    return _toggleAndMerge(postId, '/like');
  }

  Future<Map<String, dynamic>?> toggleBookmark(int postId) async {
    return _toggleAndMerge(postId, '/bookmark');
  }

  Future<Map<String, dynamic>?> toggleRepost(int postId) async {
    return _toggleAndMerge(postId, '/repost');
  }

  // 단건 상태 조회 (필요 시 호출)
  Future<Map<String, dynamic>?> fetchInteractionStatus(int postId) async {
    try {
      final res = await _dio.get('/interactions/$postId/status');
      final data = (res.data as Map).cast<String, dynamic>();

      final idx = _items.indexWhere((e) =>
      (e['id'] == postId) || (e['id']?.toString() == postId.toString()));
      if (idx >= 0) {
        final updated = {..._items[idx], ...data};
        _items[idx] = updated;
        notifyListeners();
      }
      return data;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }
}
