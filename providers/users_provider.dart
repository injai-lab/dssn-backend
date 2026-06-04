// lib/providers/users_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class UsersProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  final Map<int, Map<String, dynamic>> _profile = {};
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

  Map<String, dynamic>? profileOf(int userId) => _profile[userId];

  Future<void> fetchProfile(int userId) async {
    try {
      final res = await _dio.get('/users/$userId');
      _profile[userId] = (res.data as Map).cast<String, dynamic>();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = _pickErr(e);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> toggleFollow(int userId) async {
    try {
      final res = await _dio.post('/follows/toggle', data: { 'user_id': userId });
      final data = (res.data as Map).cast<String, dynamic>();
      if (_profile[userId] != null) {
        _profile[userId] = {..._profile[userId]!, ...data};
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
