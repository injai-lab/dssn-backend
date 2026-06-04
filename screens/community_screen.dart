// lib/screens/community_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/community_provider.dart';

class CommunityScreen extends StatefulWidget {
  final bool embed;
  const CommunityScreen({super.key, this.embed = false});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // 실제 운영 커뮤니티 id로 바꿔줘!
  static const int _CID = 1;

  // 탭 정의 (id는 단순 표기용, category가 실제 API 파라미터)
  static const _boards = [
    {'id': 1, 'name': '자유게시판', 'category': 'free'},
    {'id': 2, 'name': '질문게시판', 'category': 'qna'},
    {'id': 3, 'name': '정보공유 게시판', 'category': 'info'},
  ];

  int _selectedBoardId = 1;
  bool _inited = false;

  String get _selectedCategory =>
      (_boards.firstWhere((e) => e['id'] == _selectedBoardId)['category'] as String);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    context.read<CommunityProvider>().refreshFeedByCategory(
      cid: _CID,
      category: _selectedCategory,
      limit: 10,
    );
  }

  Future<void> _onSelectBoard(int id) async {
    if (_selectedBoardId == id) return;
    setState(() => _selectedBoardId = id);
    await context.read<CommunityProvider>().refreshFeedByCategory(
      cid: _CID,
      category: _selectedCategory,
      limit: 10,
    );
  }

  /// 글쓰기 → write_community_post_screen 라우트로 이동
  Future<void> _writeInCurrentBoard() async {
    final ok = await Navigator.of(context).pushNamed(
      '/write-community', // ✅ 여기로 변경
      arguments: {
        'board_id': _selectedBoardId, // WriteCommunityPostScreen에서 category로 변환해 사용
        'communityId': _CID,          // 여러 커뮤니티 지원 시 이 값만 조정
      },
    );
    if (!mounted) return;
    if (ok == true) {
      await context.read<CommunityProvider>().refreshFeedByCategory(
        cid: _CID,
        category: _selectedCategory,
        limit: 10,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CommunityProvider>();
    final feed = cp.feedOfCategory(_selectedCategory);
    final isLoading = cp.isFeedLoadingCategory(_selectedCategory) && feed.isEmpty;

    final appBar = AppBar(
      title: const Text('커뮤니티'),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: '새 글',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _writeInCurrentBoard,
        ),
      ],
    );

    return Scaffold(
      appBar: widget.embed ? null : appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 칩
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _boards.map((b) {
                final id = b['id'] as int;
                final selected = _selectedBoardId == id;
                return ChoiceChip(
                  label: Text(b['name'] as String),
                  selected: selected,
                  onSelected: (_) => _onSelectBoard(id),
                  selectedColor: const Color(0xFF2E7D32),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected ? const Color(0xFF2E7D32) : const Color(0xFF9CCC65),
                  ),
                  backgroundColor: const Color(0xFFE8F5E9),
                );
              }).toList(),
            ),
          ),

          // 리스트
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context
                  .read<CommunityProvider>()
                  .refreshFeedByCategory(cid: _CID, category: _selectedCategory),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (feed.isEmpty
                  ? Center(
                child: Text(
                  '${_boards.firstWhere((e) => e['id'] == _selectedBoardId)['name']}에 작성된 글이 없습니다.',
                  style: const TextStyle(color: Colors.black45),
                ),
              )
                  : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 160 &&
                      !cp.isFeedLoadingCategory(_selectedCategory) &&
                      cp.feedHasMoreCategory(_selectedCategory)) {
                    cp.fetchMoreByCategory(
                      cid: _CID,
                      category: _selectedCategory,
                      limit: 10,
                    );
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: feed.length,
                  itemBuilder: (_, i) => _PostTile(post: feed[i]),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final title = (post['title'] as String?)?.trim();
    final displayTitle = (title == null || title.isEmpty) ? '제목 없음' : title;
    final like = (post['like_count'] ?? post['likes'] ?? post['_count']?['post_like'] ?? 0).toString();
    final comment =
    (post['comment_count'] ?? post['comments'] ?? post['_count']?['comment'] ?? 0).toString();

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/post', arguments: post),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목은 굵고 크게
              Text(
                displayTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Spacer(),
                  const Icon(Icons.favorite_border, size: 14),
                  const SizedBox(width: 3),
                  Text(like, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                  const Icon(Icons.chat_bubble_outline, size: 14),
                  const SizedBox(width: 3),
                  Text(comment, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
