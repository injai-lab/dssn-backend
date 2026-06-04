import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/users_provider.dart';

class FriendRecommendScreen extends StatefulWidget {
  const FriendRecommendScreen({super.key});
  @override
  State<FriendRecommendScreen> createState() => _FriendRecommendScreenState();
}

class _FriendRecommendScreenState extends State<FriendRecommendScreen> {
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
        _more();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final up = context.read<UsersProvider>() as dynamic;
    try { await up.fetchRecommendations?.call(); return; } catch (_) {}
    try { await up.recommend?.call(); return; } catch (_) {}
    try { await up.refreshRecommend?.call(); return; } catch (_) {}
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    final up = context.read<UsersProvider>() as dynamic;
    try { await up.moreRecommendations?.call(); } catch (_) {}
    try { await up.fetchMoreRecommend?.call(); } catch (_) {}
    try { await up.nextRecommend?.call(); } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  List _items(BuildContext ctx) {
    final up = ctx.watch<UsersProvider>() as dynamic;
    List list = const [];
    try { list = (up.recommendations as List?) ?? const []; } catch (_) {}
    if (list.isEmpty) { try { list = (up.suggestions as List?) ?? const []; } catch (_) {} }
    if (list.isEmpty) { try { list = (up.items as List?) ?? const []; } catch (_) {} }
    return list;
  }

  Future<void> _toggleFollow(dynamic user) async {
    final up = context.read<UsersProvider>() as dynamic;
    int? uid;
    try { uid = (user?.id as int?); } catch (_) {}
    uid ??= int.tryParse('${user?['id'] ?? user?['user_id'] ?? ''}');
    if (uid == null) return;

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
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    return Scaffold(
      appBar: AppBar(title: const Text('친구 추천')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _ctrl,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            if (_loadingMore && i == items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final u = items[i];
            final name = _s(u, ['nickname','name','username']) ?? '사용자';
            final dept = _s(u, ['department','major']) ?? '';
            final avatar = _s(u, ['profile_img','avatar','imageUrl']);
            final bio   = _s(u, ['bio','introduce','about']) ?? '';
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dept.isNotEmpty) Text(dept),
                  if (bio.isNotEmpty)
                    Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
              trailing: FilledButton(
                onPressed: () => _toggleFollow(u),
                child: Text(following ? '팔로잉' : '팔로우'),
              ),
              onTap: () => Navigator.pushNamed(ctx, '/user', arguments: u),
            );
          },
        ),
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
