// lib/providers/comment_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class CommentProvider extends ChangeNotifier {
  final _dio = ApiClient.I.dio;

  final Map<int, List<Map<String, dynamic>>> _byPost = {}; // postId -> comments
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

  List<Map<String, dynamic>> commentsOf(int postId) =>
      List.unmodifiable(_byPost[postId] ?? const []);

  Future<void> fetch(int postId) async {
    try {
      final res = await _dio.get('/comments/$postId');
      final list = (res.data as List)
          .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
          .toList();
      _byPost[postId] = list;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchThread({
    required int postId,
    required int parentId,
  }) async {
    try {
      final res = await _dio.get('/comments/threads', queryParameters: {
        'post_id': postId,
        'parent_id': parentId,
      });
      final list = (res.data as List)
          .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
          .toList();
      return list;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return const [];
    }
  }

  Future<Map<String, dynamic>?> create({
    required int postId,
    required String content,
    int? parentId,
  }) async {
    try {
      final body = {
        'post_id': postId,
        'content': content.trim(),
        if (parentId != null) 'parent_id': parentId,
      };
      final res = await _dio.post('/comments', data: body);
      final created = (res.data as Map).cast<String, dynamic>();
      final list = _byPost[postId] ?? <Map<String, dynamic>>[];
      list.insert(0, created);
      _byPost[postId] = list;
      notifyListeners();
      return created;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleLike(int commentId, {required int postId}) async {
    try {
      final res = await _dio.post('/comments/$commentId/like');
      final data = (res.data as Map).cast<String, dynamic>();
      final list = _byPost[postId];
      if (list != null) {
        final idx = list.indexWhere((c) =>
        (c['id'] == commentId) || (c['id']?.toString() == commentId.toString()));
        if (idx >= 0) {
          list[idx] = {...list[idx], ...data};
          _byPost[postId] = List.from(list);
          notifyListeners();
        }
      }
      return data;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> remove(int commentId, {required int postId}) async {
    try {
      await _dio.delete('/comments/$commentId');
      final list = _byPost[postId];
      if (list != null) {
        list.removeWhere((c) =>
        (c['id'] == commentId) || (c['id']?.toString() == commentId.toString()));
        _byPost[postId] = List.from(list);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
      return false;
    }
  }
}
