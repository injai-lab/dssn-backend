import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/users_provider.dart';
import '../providers/post_provider.dart';
import '../providers/chat_provider.dart';

class UserPageScreen extends StatefulWidget {
  final dynamic user; // arguments 로 user 객체 or {id:...}
  const UserPageScreen({super.key, this.user});

  @override
  State<UserPageScreen> createState() => _UserPageScreenState();
}

class _UserPageScreenState extends State<UserPageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  dynamic _u;
  bool _inited = false;

  int? get _uid {
    try {
      final id = _u?['id'] ?? _u?['user_id'] ?? _u?.id ?? _u?.user_id;
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _u = widget.user;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _u ??= ModalRoute.of(context)?.settings.arguments;
      if (_inited) return;
      _inited = true;
      await _ensureLoaded();
    });
  }

  Future<void> _ensureLoaded() async {
    final id = _uid;
    if (id == null) return;

    final up = context.read<UsersProvider>() as dynamic;
    try { _u ??= await up.findById?.call(id); } catch (_) {}
    try { _u ??= await up.detail?.call(id); } catch (_) {}
    if (mounted) setState((){});

    final pp = context.read<PostProvider>() as dynamic;
    try { await pp.listByUser?.call(id); } catch (_) {}
    try { await pp.list?.call(userId: id); } catch (_) {}
    try { await pp.fetch?.call(userId: id); } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final id = _uid;
    if (id == null) return;
    final up = context.read<UsersProvider>() as dynamic;
    bool ok = false;
    try { await up.toggleFollow?.call(id); ok = true; } catch (_) {}
    if (!ok) try { await up.follow?.call(id); ok = true; } catch (_){}
    if (ok) await _ensureLoaded();
  }

  Future<void> _startDM() async {
    final id = _uid;
    if (id == null) return;
    final cp = context.read<ChatProvider>() as dynamic;
    dynamic room;
    bool ok = false;
    try { room = await cp.openDirect?.call('$id'); ok = true; } catch (_){}
    if (!ok) try { room = await cp.openOrCreate?.call(['$id']); ok = true; } catch (_){}
    if (!ok) try { room = await cp.createRoom?.call(memberIds: ['$id']); ok = true; } catch (_){}
    if (!ok || !mounted) return;
    Navigator.pushNamed(context, '/chat', arguments: room);
  }

  @override
  Widget build(BuildContext context) {
    final name = _s(_u, ['nickname','name','username']) ?? '사용자';
    final dept = _s(_u, ['department','major']) ?? '';
    final bio  = _s(_u, ['bio','about']) ?? '';
    final avatar = _s(_u, ['profile_img','avatar','imageUrl']);
    final following = _b(_u, ['following','isFollowing','followed']) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.article_outlined), text: '게시물'),
            Tab(icon: Icon(Icons.info_outline), text: '소개'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: _startDM),
          TextButton(
            onPressed: _toggleFollow,
            child: Text(following ? '언팔로우' : '팔로우',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: (avatar != null && avatar!.isNotEmpty)
                      ? NetworkImage(avatar!)
                      : null,
                  child: (avatar == null || avatar!.isEmpty)
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    runSpacing: 4,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      if (dept.isNotEmpty) Text(dept, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UserPostsTab(userId: _uid),
                _UserAboutTab(text: bio),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* --- 사용자 게시물 탭 --- */
class _UserPostsTab extends StatefulWidget {
  final int? userId;
  const _UserPostsTab({required this.userId});
  @override
  State<_UserPostsTab> createState() => _UserPostsTabState();
}
class _UserPostsTabState extends State<_UserPostsTab> {
  final _ctrl = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_more) return;
      if (_ctrl.position.pixels >= _ctrl.position.maxScrollExtent - 300) _loadMore();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  List _posts(dynamic pp) {
    List list = const [];
    try { list = (pp.posts as List?) ?? const []; } catch (_){}
    if (list.isEmpty) try { list = (pp.items as List?) ?? const []; } catch (_){}
    if (list.isEmpty) try { list = (pp.feed  as List?) ?? const []; } catch (_){}
    return list;
  }

  Future<void> _refresh() async {
    final id = widget.userId;
    if (id == null) return;
    final pp = context.read<PostProvider>() as dynamic;
    try { await pp.listByUser?.call(id); return; } catch (_){}
    try { await pp.list?.call(userId: id); return; } catch (_){}
    try { await pp.fetch?.call(userId: id); return; } catch (_){}
  }

  Future<void> _loadMore() async {
    setState(() => _more = true);
    final pp = context.read<PostProvider>() as dynamic;
    try { await pp.more?.call(); } catch (_){}
    try { await pp.fetchMore?.call(); } catch (_){}
    try { await pp.next?.call(); } catch (_){}
    if (mounted) setState(() => _more = false);
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PostProvider>() as dynamic;
    final items = _posts(pp);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _ctrl,
        itemCount: items.length + (_more ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (_more && i == items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = items[i];
          final title = _s(p, ['title']) ?? '게시글';
          final body  = _s(p, ['content','text','body']) ?? '';
          return ListTile(
            onTap: () => Navigator.pushNamed(context, '/post', arguments: p),
            leading: const Icon(Icons.article_outlined),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
          );
        },
      ),
    );
  }
}

/* --- 사용자 소개 탭 --- */
class _UserAboutTab extends StatelessWidget {
  final String text;
  const _UserAboutTab({required this.text});
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const Center(child: Text('소개가 없습니다.'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(text),
    );
  }
}

/* helpers */
String? _s(dynamic o, List<String> keys) {
  try { for (final k in keys) { final v=(o?.toJson?.call()? [k])??o?[k]??o?.k; if (v!=null) return '$v'; } } catch (_){}
  return null;
}
bool? _b(dynamic o, List<String> keys) {
  try { for (final k in keys) { final v=(o?.toJson?.call()? [k])??o?[k]??o?.k;
  if (v is bool) return v; if (v is String) return v.toLowerCase()=='true';
  }} catch (_){}
  return null;
}
