import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final int postId;
  const CommunityPostDetailScreen({super.key, required this.postId});

  @override
  State<CommunityPostDetailScreen> createState() => _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _dio = Dio(); // 프로젝트의 ApiClient 사용 중이면 교체
  Map<String, dynamic>? _post;
  List<dynamic> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1) 게시글 상세
      final p = await _dio.get('/posts/${widget.postId}'); // { post: {...} }
      // 2) 루트 댓글
      final c = await _dio.get('/comments/${widget.postId}'); // { items: [...] }

      setState(() {
        _post = p.data['post'] as Map<String, dynamic>?;
        _comments = c.data['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    await _dio.post('/like/${widget.postId}');
    await _load();
  }

  Future<void> _toggleBookmark() async {
    await _dio.post('/bookmarks', data: {'post_id': widget.postId});
    await _load();
  }

  Future<void> _createComment(String text) async {
    if (text.trim().isEmpty) return;
    await _dio.post('/comments', data: {
      'post_id': widget.postId,
      'content': text.trim(),
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_post == null) {
      return const Scaffold(body: Center(child: Text('게시글을 찾을 수 없어요.')));
    }

    final title = (_post!['title'] ?? '') as String;
    final content = (_post!['content'] ?? '') as String;
    final files = List<Map<String, dynamic>>.from(_post!['post_file'] ?? []);
    final likeCount = _post!['_count']?['post_like'] ?? 0;
    final commentCount = _post!['_count']?['comment'] ?? 0;
    final viewerHasLiked = _post!['viewer_has_liked'] == true;
    final viewerHasBookmarked = _post!['viewer_has_bookmarked'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('게시글')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (title.trim().isNotEmpty) ...[
                  Text(
                    title.trim(),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (content.trim().isNotEmpty)
                  SelectableText(
                    content.trim(),
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                if (files.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Images(files: files.map((e) => '${e['file_url']}').toList()),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _toggleLike,
                      icon: Icon(
                        viewerHasLiked ? Icons.favorite : Icons.favorite_border,
                        color: viewerHasLiked ? Colors.red : null,
                        size: 18,
                      ),
                      label: Text('$likeCount'),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chat_bubble_outline, size: 18),
                    const SizedBox(width: 4),
                    Text('$commentCount'),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleBookmark,
                      icon: Icon(
                        viewerHasBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text('댓글', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final cm in _comments) _CommentTile(cm: cm),
              ],
            ),
          ),
          _CommentInput(onSubmit: _createComment),
        ],
      ),
    );
  }
}

class _Images extends StatelessWidget {
  final List<String> files;
  const _Images({required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(files.first, fit: BoxFit.cover),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: PageView.builder(
        itemCount: files.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(files[i], fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> cm;
  const _CommentTile({required this.cm});
  @override
  Widget build(BuildContext context) {
    final user = cm['user'] ?? {};
    final name = (user['nickname'] ?? user['username'] ?? '익명').toString();
    final text = (cm['is_deleted'] == true)
        ? '삭제된 댓글입니다.'
        : (cm['content'] ?? '').toString();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(text),
    );
  }
}

class _CommentInput extends StatefulWidget {
  final Future<void> Function(String) onSubmit;
  const _CommentInput({required this.onSubmit});
  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final _c = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sending
                  ? null
                  : () async {
                final t = _c.text.trim();
                if (t.isEmpty) return;
                setState(() => _sending = true);
                await widget.onSubmit(t);
                _c.clear();
                if (mounted) setState(() => _sending = false);
              },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }
}
