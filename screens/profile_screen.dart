// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  final bool embed;
  const ProfileScreen({super.key, this.embed = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // --------------------------- Actions ---------------------------

  void _openEdit() => Navigator.of(context).pushNamed('/profile/edit');

  Future<void> _openSettingsMenu() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('프로필 편집'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('현재 기기에서 로그아웃할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 실패: $e')),
      );
    }
  }

  // --------------------------- Helpers ---------------------------

  Color? _withAlpha(Color? c, double a) => c?.withValues(alpha: a);

  Map<String, dynamic> _asMap(dynamic v) =>
      (v is Map<String, dynamic>) ? v : <String, dynamic>{};

  List<Map<String, dynamic>> _layers(AuthProvider? ap) {
    final root = _asMap(ap?.me);
    final out = <Map<String, dynamic>>[];
    if (root.isEmpty) return out;
    out.add(root); // 루트 우선(로컬 병합 우선)

    for (final k in ['data', 'user', 'me', 'profile']) {
      final m1 = _asMap(root[k]);
      if (m1.isNotEmpty) out.add(m1);
      if (k == 'data') {
        final m2 = _asMap(m1['user']);
        if (m2.isNotEmpty) out.add(m2);
      }
    }
    return out;
  }

  String? _pickInLayers(List<Map<String, dynamic>> layers, List<String> keys) {
    for (final layer in layers) {
      for (final k in keys) {
        final v = layer[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  String _title(AuthProvider? ap) {
    final L = _layers(ap);
    if (L.isEmpty) return '사용자';
    final nickname = _pickInLayers(L, ['nickname', 'displayName', 'display_name']);
    final username = _pickInLayers(L, ['username', 'userName', 'handle']);
    final email    = _pickInLayers(L, ['email', 'mail'])?.split('@').first;
    return nickname ?? username ?? email ?? '사용자';
  }

  String _realName(AuthProvider? ap) {
    final L = _layers(ap);
    return _pickInLayers(L, ['name', 'fullName', 'full_name']) ?? '';
  }

  String _dept(AuthProvider? ap) {
    final L = _layers(ap);
    return _pickInLayers(L, ['department', 'dept', 'major']) ?? '학과/소속 미설정';
  }

  String _intro(AuthProvider? ap) {
    final L = _layers(ap);
    return _pickInLayers(L, ['intro', 'bio', 'about', 'description']) ??
        '한 줄 소개가 없습니다.';
  }

  /// avatar 후보 + 캐시버스터 버전
  MapEntry<String?, int> _avatarWithVer(AuthProvider? ap) {
    final L = _layers(ap);
    String? url = _pickInLayers(L, [
      'avatar', 'avatar_url',
      'profile_image', 'profile_image_url',
      'profile_img',                 // ✅ 추가
      'image', 'photo', 'avatarUrl',
    ]);
    int ver = 0;
    for (final layer in L) {
      final v = layer['_avatar_v'];
      if (v is int && v > ver) ver = v;
    }
    return MapEntry(url, ver);
  }

  Widget _avatarWidget(BuildContext context, String? url, int ver) {
    final theme = Theme.of(context);
    final placeholder = Container(
      color: theme.colorScheme.primaryContainer,
      child: const Center(child: Icon(Icons.person, size: 32)),
    );

    if (url == null || url.isEmpty) {
      return ClipOval(
        child: SizedBox(width: 56, height: 56, child: placeholder),
      );
    }

    final sep = url.contains('?') ? '&' : '?';
    final displayUrl = '$url${sep}v=$ver';

    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.network(
          displayUrl,
          key: ValueKey(displayUrl), // URL(+v) 바뀌면 강제 리빌드
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }

  // ------------------------------ UI --------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ap = context.watch<AuthProvider?>();
    final title = _title(ap);
    final name = _realName(ap).isNotEmpty ? _realName(ap) : _title(ap); // 본명 없으면 제목으로
    final dept = _dept(ap);
    final intro = _intro(ap);
    final avatarPair = _avatarWithVer(ap);
    final avatarUrl = avatarPair.key;
    final avatarVer = avatarPair.value;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 상단 큰 제목 + 톱니
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                color: theme.colorScheme.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '설정',
                      icon: const Icon(Icons.settings),
                      onPressed: _openSettingsMenu,
                    ),
                  ],
                ),
              ),
            ),

            // ====== 프로필 헤더 (아바타 | [이름(크게)] [학과(작게)] | 아래에 소개) ======
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                color: theme.colorScheme.surface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatarWidget(context, avatarUrl, avatarVer),
                    const SizedBox(width: 12),

                    // 오른쪽 묶음
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // <<< 요구 레이아웃: 프로필 바로 옆 이름, 그 옆에 학과 >>>
                          Row(
                            children: [
                              // 이름(크게, 왼쪽 정렬, 가능한 공간 많이 차지)
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 학과(작게, 오른쪽 정렬)
                              Flexible(
                                child: Text(
                                  dept,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _withAlpha(
                                        theme.textTheme.bodySmall?.color, 0.70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 소개 한 줄 (아래)
                          Text(
                            intro,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _withAlpha(
                                  theme.textTheme.bodySmall?.color, 0.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 친구/추천
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/friends'),
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('친구 목록'),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/friends/suggest'),
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('친구 추천'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1)),

            // 섹션 타이틀
            SliverToBoxAdapter(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('나의 작성 게시물', style: theme.textTheme.titleMedium),
              ),
            ),

            // 탭 바
            SliverToBoxAdapter(
              child: Material(
                color: theme.colorScheme.surface,
                child: TabBar(
                  controller: _tab,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor:
                  _withAlpha(theme.textTheme.bodyMedium?.color, 0.6),
                  indicatorColor: theme.colorScheme.primary,
                  tabs: const [
                    Tab(text: '작성 게시물'),
                    Tab(text: '커뮤니티 글'),
                  ],
                ),
              ),
            ),

            // 탭 내용
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tab,
                children: const [
                  _EmptyMyPost(),
                  _EmptyMyCommunityPost(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- 탭 콘텐츠 ----------------------

class _EmptyMyPost extends StatelessWidget {
  const _EmptyMyPost();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('작성한 게시물이 없습니다.'));
}

class _EmptyMyCommunityPost extends StatelessWidget {
  const _EmptyMyCommunityPost();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('작성한 커뮤니티 글이 없습니다.'));
}
