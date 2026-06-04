// lib/providers/search_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class SearchProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  // 검색 결과
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> get results => List.unmodifiable(_results);

  // 자동완성
  List<String> _suggests = [];
  List<String> get suggests => List.unmodifiable(_suggests);

  // 트렌딩 태그
  List<Map<String, dynamic>> _trending = [];
  List<Map<String, dynamic>> get trending => List.unmodifiable(_trending);

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

  // ────────────────────────────────────────────────────────────────────────────
  Future<void> search({required String q, String? type}) async {
    try {
      final res = await _dio.get('/search', queryParameters: {
        'q': q.trim(),
        if (type != null && type.isNotEmpty) 'type': type,
      });
      final data = res.data;
      if (data is List) {
        _results = data
            .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
            .toList();
      } else if (data is Map && data['items'] is List) {
        _results = (data['items'] as List)
            .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
            .toList();
      } else {
        _results = const [];
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _results = const [];
      _error = _pickErr(e);
      notifyListeners();
    }
  }

  Future<void> fetchSuggest(String q) async {
    if (q.trim().isEmpty) {
      _suggests = const [];
      notifyListeners();
      return;
    }
    try {
      final res = await _dio.get('/suggest', queryParameters: { 'q': q.trim() });
      final data = res.data;
      if (data is List) {
        _suggests = data.map<String>((e) => e.toString()).toList();
      } else if (data is Map && data['items'] is List) {
        _suggests = (data['items'] as List).map<String>((e) => e.toString()).toList();
      } else {
        _suggests = const [];
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _suggests = const [];
      _error = _pickErr(e);
      notifyListeners();
    }
  }

  Future<void> fetchTrending({int limit = 10}) async {
    try {
      final res = await _dio.get('/tags/trending', queryParameters: {
        'limit': limit,
      });
      final data = res.data;
      if (data is List) {
        _trending = data
            .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
            .toList();
      } else if (data is Map && data['items'] is List) {
        _trending = (data['items'] as List)
            .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
            .toList();
      } else {
        _trending = const [];
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _trending = const [];
      _error = _pickErr(e);
      notifyListeners();
    }
  }
}
