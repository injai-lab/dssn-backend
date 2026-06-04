// lib/core/notify_polling.dart  (전체 교체)
// main.dart의 NotifyPollingBinder.ensureInitialized(context)와 시그니처를 맞춘 정적 바인더 버전

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../providers/net_provider.dart';

class NotifyPollingBinder {
  static Timer? _timer;
  static bool _init = false;
  static BuildContext? _ctx;

  /// main.dart에서 한 번만 호출되면 됩니다.
  static void ensureInitialized(BuildContext context) {
    if (_init) return;
    _init = true;
    _ctx = context;

    // 앱 재개 상태에서만 폴링 (Lifecycle은 매 틱 확인)
    _kick();
  }

  static void dispose() {
    _stop();
    _ctx = null;
    _init = false;
  }

  static Duration _interval() {
    try {
      final net = Provider.of<NetProvider>(_ctx!, listen: false);
      if (net.online == false) return const Duration(seconds: 60);
    } catch (_) {}
    return const Duration(seconds: 20);
  }

  static void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  static void _kick() {
    _stop();
    if (_ctx == null) return;

    // 오프라인이면 시작하지 않음
    try {
      final net = Provider.of<NetProvider>(_ctx!, listen: false);
      if (net.online == false) return;
    } catch (_) {}

    // 즉시 한 번 수행 후, 주기 폴링 시작
    _tick();

    _timer = Timer.periodic(_interval(), (_) {
      // Foreground일 때만
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      // 온라인일 때만
      try {
        final net = Provider.of<NetProvider>(_ctx!, listen: false);
        if (net.online == false) return;
      } catch (_) {}

      _tick();
    });
  }

  static Future<void> _tick() async {
    final ctx = _ctx;
    if (ctx == null) return;

    dynamic np;
    try {
      np = Provider.of<NotificationProvider>(ctx, listen: false);
    } catch (_) {
      // NotificationProvider가 아직 트리에 없으면 조용히 종료
      return;
    }

    // 1) 읽지않음 동기화(있는 이름부터 순회)
    try {
      await (np.syncUnread?.call() ??
          np.refreshUnread?.call() ??
          np.countUnread?.call());
    } catch (_) {}

    // 2) 최신 알림 가져오기(없으면 초기 로딩 시도)
    try {
      await (np.fetchLatest?.call() ??
          np.pull?.call() ??
          np.fetchMore?.call());
    } catch (_) {
      try {
        final items = (np.items as List?) ?? const [];
        final isLoading = (np.isInitialLoading as bool?) ?? false;
        if (items.isEmpty && !isLoading) {
          await np.fetchInitial?.call();
        }
      } catch (_) {}
    }
  }
}
