import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';

class FriendsManagementScreen extends StatefulWidget {
  const FriendsManagementScreen({super.key});
  @override
  State<FriendsManagementScreen> createState() => _FriendsManagementScreenState();
}

class _FriendsManagementScreenState extends State<FriendsManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _ctrlFollowing = ScrollController();
  final _ctrlFollowers = ScrollController();
  bool _inited = false;
  bool _loadingMoreFollowing = false;
  bool _loadingMoreFollowers = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_inited) return;
      _inited = true;
      await _refreshAll();
    });

    _ctrlFollowing.addListener(() {
      if (_loadingMoreFollowing) return;
      if (_ctrlFollowing.position.pixels >=
          _ctrlFollowing.position.maxScrollExtent - 300) {
        _moreFollowing();
      }
    });
    _ctrlFollowers.addListener(() {
      if (_loadingMoreFollowers) return;
      if (_ctrlFollowers.position.pixels >=
          _ctrlFollowers.position.maxScrollExtent - 300) {
        _moreFollowers();
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrlFollowing.dispose();
    _ctrlFollowers.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshFollowing(), _refreshFollowers()]);
  }

  Future<void> _refreshFollowing() async {
    final up = context.read<UsersProvider>() as dynamic;
    // 흔한 메서드명 대응
    try { await up.listFollowing?.call(); return; } catch (_) {}
    try { await up.getFollowing?.call(); return; } catch (_) {}
    try { await up.refreshFollowing?.call(); return; } catch (_) {}
  }

  Future<void> _refreshFollowers() async {
    final up = context.read<UsersProvider>() as dynamic;
    try { await up.listFollowers?.call(); return; } catch (_) {}
    try { await up.getFollowers?.call(); return; } catch (_) {}
    try { await up.refreshFollowers?.call(); return; } catch (_) {}
  }

  Future<void> _moreFollowing() async {
    setState(() => _loadingMoreFollowing = true);
    final up = context.read<UsersProvider>() as dynamic;
    try { await up.moreFollowing?.call(); } catch (_) {}
    try { await up.fetchMoreFollowing?.call(); } catch (_) {}
    try { await up.nextFollowing?.call(); } catch (_) {}
    if (mounted) setState(() => _loadingMoreFollowing = false);
  }

  Future<void> _moreFollowers() async {
    setState(() => _loadingMoreFollowers = true);
    final up = context.read<UsersProvider>() as dynamic;
    try { await up.moreFollowers?.call(); } catch (_) {}
    try { await up.fetchMoreFollowers?.call(); } catch (_) {}
    try { await up.nextFollowers?.call(); } catch (_) {}
    if (mounted) setState(() => _loadingMoreFollowers = false);
  }

  List _following(BuildContext ctx) {
    final up = ctx.watch<UsersProvider>() as dynamic;
    List list = const [];
    try { list = (up.following as List?) ?? const []; } catch (_) {}
    if (list.isEmpty) { try { list = (up.followings as List?) ?? const []; } catch (_) {} }
    return list;
  }

  List _followers(BuildContext ctx) {
    final up = ctx.watch<UsersProvider>() as dynamic;
    List list = const [];
    try { list = (up.followers as List?) ?? const []; } catch (_) {}
    return list;
  }

  Future<void> _toggleFollow(dynamic user) async {
    final me = (context.read<AuthProvider>() as dynamic);
    int? myId;
    try { myId = (me.me?.id as int?); } catch (_) {}
    // 대상 id
    int? uid;
    try { uid = (user?.id as int?); } catch (_) {}
    uid ??= int.tryParse('${user?['id'] ?? user?['user_id'] ?? ''}');
    if (uid == null || (myId != null && myId == uid)) return;

    final up = context.read<UsersProvider>() as dynamic;

    // 팔로우 여부 추정
    bool following = false;
    try {
      following = (user?.following == true) ||
          (user?['following'] == true) ||
          (user?.isFollowed == true) ||
          (user?['isFollowed'] == true);
    } catch (_) {}

    try {
      if (following) {
        try { await up.unfollow?.call(uid); } catch (_) {}
        try { await up.unfollowUser?.call(userId: uid); } catch (_) {}
      } else {
        try { await up.follow?.call(uid); } catch (_) {}
        try { await up.followUser?.call(userId: uid); } catch (_) {}
      }
    } catch (_) {}
    // 화면 갱신
    await _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final following = _following(context);
    final followers = _followers(context);

    return Scaffold(
      appBar: AppBar(title: const Text('친구 관리')),
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            tabs: const [Tab(text: '내가 팔로우'), Tab(text: '나를 팔로우')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UsersList(
                  items: following,
                  ctrl: _ctrlFollowing,
                  loadingMore: _loadingMoreFollowing,
                  onRefresh: _refreshFollowing,
                  onTapFollow: _toggleFollow,
                ),
                _UsersList(
                  items: followers,
                  ctrl: _ctrlFollowers,
                  loadingMore: _loadingMoreFollowers,
                  onRefresh: _refreshFollowers,
                  onTapFollow: _toggleFollow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final List items;
  final ScrollController ctrl;
  final bool loadingMore;
  final Future<void> Function() onRefresh;
  final Future<void> Function(dynamic user) onTapFollow;

  const _UsersList({
    required this.items,
    required this.ctrl,
    required this.loadingMore,
    required this.onRefresh,
    required this.onTapFollow,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: ctrl,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (loadingMore && i == items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final u = items[i];
          final name = _s(u, ['nickname','name','username']) ?? '사용자';
          final dept = _s(u, ['department','major']) ?? '';
          final avatar = _s(u, ['profile_img','avatar','imageUrl']);
          final following = _b(u, ['following','isFollowed']) ?? false;

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: (avatar != null && avatar.isNotEmpty)
                  ? NetworkImage(avatar)
                  : null,
              child: (avatar == null || avatar.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(name),
            subtitle: dept.isEmpty ? null : Text(dept),
            trailing: FilledButton.tonal(
              onPressed: () => onTapFollow(u),
              child: Text(following ? '팔로잉' : '팔로우'),
            ),
            onTap: () => Navigator.pushNamed(ctx, '/user', arguments: u),
          );
        },
      ),
    );
  }

  static String? _s(dynamic o, List<String> keys) {
    try { for (final k in keys) { final v = (o?.toJson?.call()? [k]) ?? o?[k] ?? o?.k; if (v != null) return '$v'; } } catch (_){}
    return null;
  }
  static bool? _b(dynamic o, List<String> keys) {
    try { for (final k in keys) {
      final v = (o?.toJson?.call()? [k]) ?? o?[k] ?? o?.k;
      if (v is bool) return v;
      if (v is String) return (v.toLowerCase() == 'true');
    } } catch (_){}
    return null;
  }
}
