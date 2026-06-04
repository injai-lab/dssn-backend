// lib/providers/explore_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class ExploreProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  String? _cursor;         // 문자열 커서
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  bool get hasMore => _hasMore;
  bool get loading => _loading;
  String? get error => _error;

  String _pickErr(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
      if (d is String && d.isNotEmpty) return d;
      return e.message ?? '네트워크 오류가 발생했어요.';
    }
    return '알 수 없는 오류가 발생했어요.';
  }

  Future<void> refresh({int limit = 10}) async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _error = null;
    notifyListeners();
    await fetchMore(limit: limit);
  }

  Future<void> fetchMore({int limit = 10}) async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.get('/feed/explore', queryParameters: {
        'limit': limit,
        if (_cursor != null) 'cursor': _cursor,
      });

      final data = (res.data as Map).cast<String, dynamic>();
      final list = (data['items'] ?? data['posts'] ?? []) as List;
      final next = data['nextCursor'];

      _items.addAll(list.map<Map<String, dynamic>>(
            (e) => (e as Map).cast<String, dynamic>(),
      ));
      _cursor = (next is String && next.isNotEmpty) ? next : null;
      _hasMore = _cursor != null;
    } catch (e) {
      _error = _pickErr(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
