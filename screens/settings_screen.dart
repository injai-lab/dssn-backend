import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../core/quick_ping.dart';
import '../core/deeplink.dart';
import '../providers/notification_provider.dart';
import '../providers/net_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  String _ping = '-';
  String _deep = '';

  Future<void> _doPing() async {
    setState(() => _busy = true);
    final sw = Stopwatch()..start();
    try {
      // 반환값을 기대하지 않고 단순 호출 (예: Future<void>)
      await quickPingHealth();
      sw.stop();
      setState(() => _ping = '${sw.elapsedMilliseconds}ms');
    } catch (_) {
      sw.stop();
      setState(() => _ping = '실패');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    final ap = context.read<AuthProvider>() as dynamic;
    try { await ap.logout?.call(); } catch (_) {}
    try { await ap.signOut?.call(); } catch (_) {}
    setState(() => _busy = false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AuthProvider>();
    final me = _pickMe(ap);

    final np = context.watch<NotificationProvider>() as dynamic;
    int unread = 0; try { unread = (np.unreadCount as int?) ?? 0; } catch (_) {}

    final net = context.watch<NetProvider>() as dynamic;
    bool online = true; try { online = (net.online as bool?) ?? true; } catch (_) {}

    // 초기화만 보장 (반환값 사용 안 함)
    try { DeepLinkBinder.ensureInitialized(context); } catch (_) {}

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(_s(me, ['nickname','name','username']) ?? '나'),
            subtitle: Text(_s(me, ['email']) ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/profile/edit'),
          ),
          const Divider(),

          SwitchListTile(
            value: online,
            onChanged: (_) {}, // 표시용
            secondary: const Icon(Icons.network_check),
            title: const Text('네트워크 연결'),
            subtitle: Text(online ? '온라인' : '오프라인'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('알림'),
            subtitle: Text('읽지 않음 $unread'),
            onTap: () => Navigator.pushNamed(context, '/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('딥링크 테스트'),
            subtitle: Text(_deep.isEmpty ? 'dongstory://post/123 같은 링크' : _deep),
            onTap: () async {
              final sample = 'dongstory://post/123';
              setState(() => _deep = sample);
              // 실제 열기는 DeepLinkBinder의 실제 API 명을 확인 후 연결하세요.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('샘플 딥링크 문자열을 설정했습니다.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('서버 핑'),
            subtitle: Text(_ping),
            trailing: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _busy ? null : _doPing,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: _busy ? null : _logout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // helpers
  dynamic _pickMe(AuthProvider auth) {
    final a = auth as dynamic;
    try { final v = a.me; if (v != null) return v; } catch (_) {}
    try { final v = a.currentUser; if (v != null) return v; } catch (_) {}
    try { final v = a.user; if (v != null) return v; } catch (_) {}
    try { final v = a.loggedInUser; if (v != null) return v; } catch (_) {}
    return null;
  }
  String? _s(dynamic o, List<String> keys) {
    try { for (final k in keys) {
      final v = (o?.toJson?.call()? [k]) ?? o?[k] ?? o?.k;
      if (v != null) return '$v';
    }} catch (_) {}
    return null;
  }
}
