// lib/env.dart
class Env {
  /// Android 에뮬레이터 기본: 10.0.2.2
  /// 실기기 테스트는 로컬 IP 로 교체하거나 --dart-define=API_BASE_URL 사용
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// 네트워크 타임아웃
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// 토큰 키
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}
