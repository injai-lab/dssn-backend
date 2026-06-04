import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _ctrl = ScrollController();
  bool _inited = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_inited) return;
      _inited = true;
      await _refresh();
    });
    _ctrl.addListener(() {
      if (_loadingMore) return;
      if (_ctrl.position.pixels >= _ctrl.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /* ───────── 데이터 액션들 (메서드 이름 자동 탐색) ───────── */

  Future<void> _refresh() async {
    final np = context.read<NotificationProvider>() as dynamic;
    try { await np.refresh?.call(); return; } catch (_) {}
    try { await np.list?.call(); return; } catch (_) {}
    try { await np.fetch?.call(); return; } catch (_) {}
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final np = context.read<NotificationProvider>() as dynamic;
    try { await np.more?.call(); } catch (_) {}
    try { await np.fetchMore?.call(); } catch (_) {}
    try { await np.next?.call(); } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _markAllRead() async {
    final np = context.read<NotificationProvider>() as dynamic;
    bool ok = false;
    try { await np.markAllRead?.call(); ok = true; } catch (_) {}
    if (!ok) { try { await np.readAll?.call(); ok = true; } catch (_) {} }
    if (!ok) { try { await np.clearUnread?.call(); ok = true; } catch (_) {} }
    if (ok) await _refresh();
  }

  Future<void> _markRead(dynamic noti) async {
    final id = _id(noti);
    if (id == null) return;
    final np = context.read<NotificationProvider>() as dynamic;

    bool ok = false;
    try { await np.markRead?.call(id); ok = true; } catch (_) {}
    if (!ok) { try { await np.read?.call(id); ok = true; } catch (_) {} }
    if (!ok) { try { await np.open?.call(id); ok = true; } catch (_) {} }
    if (ok) await _refresh();
  }

  /* ───────── 리스트/아이템 헬퍼 ───────── */

  List _items(dynamic np) {
    List list = const [];
    try { list = (np.items as List?) ?? const []; } catch (_) {}
    if (list.isEmpty) { try { list = (np.notifications as List?) ?? const []; } catch (_) {} }
    if (list.isEmpty) { try { list = (np.list as List?) ?? const []; } catch (_) {} }
    return list;
  }

  int? _id(dynamic n) {
    try {
      final v = n?['id'] ?? n?['noti_id'] ?? n?.id ?? n?.noti_id;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    } catch (_) {}
    return null;
  }

  bool _isRead(dynamic n) {
    try {
      final v = n?['is_read'] ?? n?['read'] ?? n?.is_read ?? n?.read ?? false;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
    } catch (_) {}
    return false;
  }

  String? _s(dynamic o, List<String> keys) {
    try {
      for (final k in keys) {
        final v = (o?.toJson?.call()? [k]) ?? o?[k] ?? o?.k;
        if (v != null) return '$v';
      }
    } catch (_) {}
    return null;
  }

  void _navigateByPayload(dynamic n) {
    // 서버가 넘겨주는 라우팅 힌트들을 최대한 활용
    final route = _s(n, ['route','screen','targetRoute']);
    final postId = _s(n, ['post_id','postId']);
    final userId = _s(n, ['user_id','userId']);
    final commId = _s(n, ['community_id','communityId']);

    if (route != null) {
      Navigator.pushNamed(context, route, arguments: n);
      return;
    }
    if (postId != null) {
      Navigator.pushNamed(context, '/post', arguments: {'id': int.tryParse(postId) ?? postId});
      return;
    }
    if (userId != null) {
      Navigator.pushNamed(context, '/user', arguments: {'id': int.tryParse(userId) ?? userId});
      return;
    }
    if (commId != null) {
      Navigator.pushNamed(context, '/community', arguments: {'id': int.tryParse(commId) ?? commId});
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>() as dynamic;
    final items = _items(np);

    final unread = () {
      try { return (np.unreadCount as int?) ?? 0; } catch (_) { return 0; }
    }();

    final hasMore = () {
      try { return (np.hasMore as bool?) ?? true; } catch (_) { return true; }
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('모두 읽음', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _ctrl,
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            if (i < items.length) {
              final n = items[i];
              final title = _s(n, ['title','type','kind']) ?? '알림';
              final body  = _s(n, ['content','text','message','body']) ?? '';
              final ts    = _s(n, ['created_at','createdAt','time']) ?? '';
              final read  = _isRead(n);

              return ListTile(
                onTap: () {
                  _navigateByPayload(n);
                  _markRead(n);
                },
                leading: CircleAvatar(
                  backgroundColor: read ? Colors.grey.shade300 : Colors.green.shade100,
                  child: Icon(
                    read ? Icons.notifications_none : Icons.notifications_active,
                    color: read ? Colors.grey.shade700 : Colors.green.shade800,
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: read ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty)
                      Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (ts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(ts, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: '읽음 처리',
                  icon: Icon(read ? Icons.check_circle_outline : Icons.mark_email_read_outlined),
                  onPressed: () => _markRead(n),
                ),
              );
            }

            // 마지막 칸: 로딩/끝
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!hasMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('더 이상 알림이 없어요')),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
