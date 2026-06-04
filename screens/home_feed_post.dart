import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/post_card.dart';

const int kHomeCommunityId = 1; // 홈 피드 전용 커뮤니티 id

class HomeFeedPost extends StatefulWidget {
  const HomeFeedPost({super.key});
  @override
  State<HomeFeedPost> createState() => _HomeFeedPostState();
}

class _HomeFeedPostState extends State<HomeFeedPost> {
  final _scroll = ScrollController();

  final List<dynamic> _items = [];
  String? _cursor;
  bool _hasMore = true;
  bool _initialLoading = false;
  bool _moreLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _moreLoading || _initialLoading) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _fetchMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final p = await _fetchFromServer(limit: 20, cursor: null);
      setState(() {
        _items
          ..clear()
          ..addAll(p.items);
        _cursor = p.nextCursor;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      setState(() => _error = '피드를 불러오지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _fetchMore() async {
    if (_cursor == null) return;
    setState(() {
      _moreLoading = true;
      _error = null;
    });
    try {
      final p = await _fetchFromServer(limit: 20, cursor: _cursor);
      setState(() {
        _items.addAll(p.items);
        _cursor = p.nextCursor;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      setState(() => _error = '더 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _moreLoading = false);
    }
  }

  // 홈 전용 판별자(커뮤니티 글 차단)
  bool _isHomePost(Map p) {
    final cat = p['category'];                      // 커뮤니티면 'free'|'qna'|'info'
    final board = p['board_id'] ?? p['boardId'];
    final cid = (p['community_id'] ?? p['communityId'])?.toString();
    final noCategory = (cat == null) || (cat is String && cat.trim().isEmpty);
    final noBoard = (board == null) || board.toString().trim().isEmpty;
    // community_id가 응답에 없으면(구형 API) 홈으로 간주
    final inHome = (cid == null) || (cid == kHomeCommunityId.toString());
    return noCategory && noBoard && inHome;
  }

  Future<_PageData> _fetchFromServer({int limit = 20, String? cursor}) async {
    final resp = await ApiClient.I.dio.get('/feed/home', queryParameters: {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
      // 서버가 이해하면 홈 전용으로 더 확실히 필터됨(모르면 무시됨)
      'community_id': kHomeCommunityId,
      'home_only': 1,
    });

    final body = resp.data;
    dynamic items =
        body['data']?['items'] ?? body['items'] ?? body['data']?['posts'] ?? body['posts'];
    if (items is Map && items['items'] != null) items = items['items'];
    if (items is! List) items = <dynamic>[];

    // 클라 방어 필터
    final filtered = items
        .whereType<Map>()
        .where(_isHomePost)
        .toList();

    final next = body['data']?['nextCursor'] ??
        body['nextCursor'] ??
        body['cursor'] ??
        body['data']?['cursor'];
    final hasMore = (body['data']?['hasMore'] ?? body['hasMore']) ??
        (next != null && next.toString().isNotEmpty);

    return _PageData(
      items: filtered,
      nextCursor: next?.toString(),
      hasMore: hasMore == true,
    );
  }

  Future<void> _openWrite() async {
    final res = await Navigator.pushNamed(context, '/write'); // 홈 전용 글쓰기 라우트
    if (!mounted) return;
    if (res == true || res is Map) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                if (_initialLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_off, size: 40, color: Colors.black38),
                          const SizedBox(height: 10),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _refresh, child: const Text('다시 시도'))
                        ],
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('피드가 비어 있어요. 첫 글을 작성해보세요!',
                              style: TextStyle(color: Colors.black54)),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final post = Map<String, dynamic>.from(_items[i]);
                        final postId = (post['id'] ?? post['post_id']).toString();

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: PostCard(
                            post: post,
                            onTap: () {
                              final p = post;
                              final id = p['id'] ?? p['post_id'] ?? p['postId'];
                              Navigator.pushNamed(
                                context,
                                '/post',
                                arguments: {'id': id, 'post': p},
                              );
                            },
                          ),
                        );
                      },
                    ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: _moreLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : (!_hasMore
                          ? const Text('모든 글을 다 보셨습니다.',
                          style: TextStyle(color: Colors.black38))
                          : const SizedBox.shrink()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PageData {
  final List<dynamic> items;
  final String? nextCursor;
  final bool hasMore;
  _PageData({required this.items, required this.nextCursor, required this.hasMore});
}
