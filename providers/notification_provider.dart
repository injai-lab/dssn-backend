// lib/providers/notification_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _onlyUnread = false;

  String? _error;
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

  bool get onlyUnread => _onlyUnread;

  Future<void> refresh({int limit = 20, bool onlyUnread = false}) async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _onlyUnread = onlyUnread;
    _error = null;
    notifyListeners();
    await fetchMore(limit: limit);
  }

  Future<void> fetchMore({int limit = 20}) async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.get('/notifications', queryParameters: {
        'limit': limit,
        if (_cursor != null) 'cursor': _cursor,
        'onlyUnread': _onlyUnread ? 1 : 0,
      });
      final data = (res.data as Map).cast<String, dynamic>();
      final list = (data['items'] ?? data['data'] ?? []) as List;
      final next = data['nextCursor'];

      _items.addAll(list.map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>()));
      _cursor = (next is String && next.isNotEmpty) ? next : null;
      _hasMore = _cursor != null;
    } catch (e) {
      _error = _pickErr(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> markRead(List<int> ids) async {
    try {
      await _dio.patch('/notifications/read', data: { 'ids': ids });
      // 로컬 반영
      for (int i = 0; i < _items.length; i++) {
        if (ids.contains(_items[i]['id'])) {
          _items[i] = {..._items[i], 'read': true};
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      await _dio.post('/notifications/read-all');
      for (int i = 0; i < _items.length; i++) {
        _items[i] = {..._items[i], 'read': true};
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return false;
    }
  }
}
