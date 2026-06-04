// lib/core/deeplink.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:app_links/app_links.dart';

class DeepLinkBinder {
  static StreamSubscription<Uri>? _sub;
  static bool _init = false;
  static BuildContext? _ctx;
  static AppLinks? _appLinks;

  static Future<void> ensureInitialized(BuildContext context) async {
    if (_init) return;
    _init = true;
    _ctx = context;

    _appLinks = AppLinks();

    // 앱이 링크로 처음 실행된 경우
    final initial = await _appLinks!.getInitialLink(); // ← 여기!
    if (initial != null) _handleUri(initial);

    // 실행 중 수신
    _sub = _appLinks!.uriLinkStream.listen(
      _handleUri,
      onError: (e) {},
    );
  }

  static void _handleUri(Uri uri) {
    final ctx = _ctx;
    if (ctx == null) return;

    final segs = uri.pathSegments;
    if (segs.isNotEmpty) {
      switch (segs.first) {
        case 'post':
          final id = segs.length > 1 ? segs[1] : uri.queryParameters['id'];
          if (id != null) {
            Navigator.of(ctx).pushNamed('/post', arguments: {'id': id});
            return;
          }
          break;
        case 'profile':
          final uid = segs.length > 1 ? segs[1] : uri.queryParameters['uid'];
          if (uid != null) {
            Navigator.of(ctx).pushNamed('/profile', arguments: {'uid': uid});
            return;
          }
          break;
      }
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _ctx = null;
    _init = false;
    _appLinks = null;
  }
}
