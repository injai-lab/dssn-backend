// lib/providers/net_provider.dart (전체 덮어쓰기)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart'; // ApiClient.I.dio 사용 (이미 있는 파일)

class NetProvider extends ChangeNotifier {
  final Dio _dio = ApiClient.I.dio;

  bool? _online; // null: 모름, true: 온라인, false: 오프라인
  bool? get online => _online;

  int? _latencyMs;
  int? get latencyMs => _latencyMs;

  String? _lastError;
  String? get lastError => _lastError;

  Timer? _timer;

  NetProvider({Duration interval = const Duration(seconds: 7)}) {
    // 앱 시작 직후 한번 체크하고, 주기적으로 모니터링
    checkNow();
    _timer = Timer.periodic(interval, (_) => checkNow());
  }

  /// /health 핑 (성공=온라인)
  Future<void> checkNow() async {
    try {
      final started = DateTime.now().millisecondsSinceEpoch;
      final res = await _dio.get('/health',
          options: Options(receiveTimeout: const Duration(seconds: 5)));
      // 200~299 이면 OK
      final ok = res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300;
      _online = ok;
      _lastError = null;
      _latencyMs = DateTime.now().millisecondsSinceEpoch - started;
    } on DioException catch (e) {
      _online = false;
      _lastError = _pickMessage(e);
      _latencyMs = null;
    } catch (_) {
      _online = false;
      _lastError = '서버에 연결할 수 없어요.';
      _latencyMs = null;
    } finally {
      notifyListeners();
    }
  }

  String _pickMessage(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    if (d is String && d.isNotEmpty) return d;
    // 타임아웃/네트워크 차단 등
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '요청 시간이 초과되었어요.';
    }
    return '네트워크 오류가 발생했어요.';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
