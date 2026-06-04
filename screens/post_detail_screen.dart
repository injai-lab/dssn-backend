// lib/screens/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? post; // 홈 목록에서 프리뷰로 넘겨줄 수 있음
  const PostDetailScreen({super.key, this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;                     // 상세 본문(원시 Map)
  List<Map<String, dynamic>> _comments = const []; // 댓글 목록
  bool _loading = false;
  String? _error;
  bool _inited = false;

  void _log(Object m) => debugPrint('[POST_DETAIL] $m');

  // ---------- 초기 진입 ----------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    // 1) 우선 위젯으로 넘어온 프리뷰 적용
    Map<String, dynamic>? initial = widget.post;

    // 2) 네비게이션 arguments(id, post 둘 다 수용)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args['post'] is Map) {
        initial = Map<String, dynamic>.from(args['post'] as Map);
      } else {
        initial = Map<String, dynamic>.from(args);
      }
    }
    _post = initial;

    // 3) 첫 프레임 이후 네트워크 로딩 시작
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  // 상세 응답이 {post:{...}} 또는 {...} 어떤 형태든 열어주는 헬퍼
  Map<String, dynamic>? _unwrapPost(Map<String, dynamic>? m) {
    if (m == null) return null;
    final inner = m['post'];
    if (inner is Map<String, dynamic>) return inner.cast<String, dynamic>();
    return m;
  }

  int? get _id {
    final p = _unwrapPost(_post);
    final v = p?['id'] ?? p?['post_id'] ?? p?['postId'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  // =====================================================
  // =============== 네트워크 로딩 로직 ==================
  // =====================================================
  Future<void> _fetch() async {
    final id = _id;
    if (id == null) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '불러오기 실패: 잘못된 글 ID'; });
      return;
    }

    final hasPreview = _unwrapPost(_post) != null;
    if (mounted) setState(() { _loading = !hasPreview; _error = null; });

    Map<String, dynamic>? newPost = _post;
    List<Map<String, dynamic>> newComments = _comments;

    // 1) 본문은 프리뷰 없을 때만 시도 (500이어도 댓글은 진행)
    if (!hasPreview) {
      try {
        newPost = await _fetchPostMulti(id);
      } catch (e) {
        _log('detail fail but continue → $e');
      }
    }

    // 2) 댓글은 항상 시도
    DioException? commentsErr;
    try {
      newComments = await _fetchCommentsMulti(id);
    } on DioException catch (e) {
      commentsErr = e;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _post = newPost;
      _comments = newComments;
      _loading = false;
      if (commentsErr != null) {
        final sc = commentsErr.response?.statusCode;
        _error = '댓글 불러오기 실패: HTTP $sc';
      }
    });
  }

  Future<void> _refreshComments() async {
    final id = _id;
    if (id == null || !mounted) return;

    final dio = ApiClient.I.dio;
    final tries = <Future<Response>>[
      dio.get('/comments', queryParameters: {'post_id': id}), // 우리 서버 규격
      dio.get('/comments', queryParameters: {'postId': id}),  // camelCase 허용
      dio.get('/posts/$id/comments'),                         // 백업
      dio.get('/comments/$id'),                               // 마지막 후보
    ];

    DioException? last;
    for (final t in tries) {
      try {
        final r = await t;
        final d = r.data;

        List list = const [];
        if (d is Map && d['items'] is List)      list = d['items'];
        else if (d is Map && d['comments'] is List) list = d['comments'];
        else if (d is List)                      list = d;

        if (!mounted) return;
        setState(() {
          _comments = list.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        });
        return; // 성공했으니 종료
      } on DioException catch (e) {
        last = e; // 404/500이어도 다음 후보 계속 시도
        continue;
      }
    }

    if (!mounted) return;
    final sc = last?.response?.statusCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('댓글 새로고침 실패 (HTTP $sc)')),
    );
  }

  // 상세: 여러 후보 경로를 순차 시도
  Future<Map<String, dynamic>> _fetchPostMulti(int id) async {
    final dio = ApiClient.I.dio;
    final paths = <String>[
      '/posts/$id',
      '/post/$id',
      '/feed/posts/$id',
      '/feed/post/$id',
      '/posts/detail/$id',
      '/post/detail/$id',
    ];
    DioException? last;
    for (final p in paths) {
      try {
        _log('GET $p');
        final r = await dio.get(p);
        final d = r.data;
        if (d is Map) {
          return (d['post'] is Map<String, dynamic>)
              ? Map<String, dynamic>.from(d['post'])
              : Map<String, dynamic>.from(d);
        }
      } on DioException catch (e) {
        _log(' → ${e.response?.statusCode} @ $p');
        last = e; // 어떤 코드든 다음 후보로 계속
        continue;
      }
    }
    throw last ?? '지원되는 상세 엔드포인트를 찾지 못했습니다';
  }

  // 댓글: 우리 서버 규격 우선, 그 외 백업
  Future<List<Map<String, dynamic>>> _fetchCommentsMulti(int id) async {
    final dio = ApiClient.I.dio;
    final calls = <Future<Response>>[
      dio.get('/comments', queryParameters: {'post_id': id}), // ✅ 우선(서버 규격)
      dio.get('/posts/$id/comments'),                         // 백업
      dio.get('/comments/$id'),                               // 마지막 후보
    ];
    DioException? last;
    for (final c in calls) {
      try {
        final r = await c;
        final d = r.data;
        List list = const [];
        if (d is Map && d['items'] is List)      list = d['items'];
        else if (d is Map && d['comments'] is List) list = d['comments'];
        else if (d is List)                      list = d;

        return list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } on DioException catch (e) {
        last = e;
        continue;
      }
    }
    if (last?.response?.statusCode == 404) return <Map<String, dynamic>>[];
    throw last ?? '댓글 엔드포인트를 찾지 못했습니다';
  }

  // 댓글 작성: 낙관적 → 서버 저장 → 동기화
  Future<void> _submitComment(String text) async {
    final id = _id;
    if (id == null) return;
    final t = text.trim();
    if (t.isEmpty) return;

    // 낙관적 추가
    final optimistic = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'content': t,
      'created_at': DateTime.now().toIso8601String(),
      'user': {'nickname': '나'},
      '_optimistic': true,
    };
    setState(() => _comments = [optimistic, ..._comments]);

    try {
      await ApiClient.I.dio.post('/comments', data: {'post_id': id, 'content': t});
      await _refreshComments(); // 저장 후 목록만 재동기화
    } catch (e) {
      if (!mounted) return;
      setState(() => _comments = _comments.where((c) => c['_optimistic'] != true).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 전송 실패: $e')),
      );
    }
  }

  // =====================================================
  // ======================= UI ==========================
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final p = _unwrapPost(_post) ?? {};
    final author =
        _str(_pickMap(p, ['user', 'author', 'writer'])?['nickname']) ??
            _str(_pickMap(p, ['user', 'author', 'writer'])?['name']) ??
            _str(p['author_name']) ??
            '익명';

    final content    = _str(p['content']) ?? _str(p['text']) ?? '';
    final createdAt  = _str(p['created_at']) ?? _str(p['createdAt']) ?? '';
    final images     = _extractImagesForDSSN(p);
    final firstImage = images.isNotEmpty ? images.first : null;

    final hasPost     = p.isNotEmpty;
    final hasComments = _comments.isNotEmpty;

    final contentList = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 14, backgroundColor: Color(0xFFE6F4EA)),
            const SizedBox(width: 8),
            Expanded(child: Text(author, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (createdAt.isNotEmpty)
              Text(createdAt, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        if (content.isNotEmpty) Text(content, style: const TextStyle(fontSize: 15)),
        if (content.isNotEmpty) const SizedBox(height: 12),
        if (firstImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                firstImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('이미지를 불러올 수 없어요'),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),

        // 에러 문구는 "상세와 댓글이 모두 비어 있을 때"만 보여줌
        if (_error != null && !hasPost && !hasComments)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),

        const Divider(height: 24),
        const Text('댓글', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_comments.isEmpty)
          Text('아직 댓글이 없어요.', style: TextStyle(color: Colors.grey.shade600))
        else
          ..._comments.map((c) => _CommentTile(c)),
        const SizedBox(height: 120),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('게시글')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshComments, // 전체가 아닌 댓글만
        child: contentList,
      ),
      bottomSheet: _CommentInput(onSubmit: _submitComment),
    );
  }
}

/* ---------- 댓글 타일 ---------- */
class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CommentTile(this.c);

  @override
  Widget build(BuildContext context) {
    final author =
        _str(_pickMap(c, ['user', 'author', 'writer'])?['nickname']) ??
            _str(c['author_name']) ??
            '익명';
    final content   = _str(c['content']) ?? '';
    final createdAt = _str(c['created_at']) ?? _str(c['createdAt']) ?? '';
    final optimistic = c['_optimistic'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE6F4EA)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(author, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                    createdAt.isNotEmpty ? createdAt : (optimistic ? '전송 중…' : ''),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- 입력창 ---------- */
class _CommentInput extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;
  const _CommentInput({required this.onSubmit});
  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;

    setState(() => _sending = true);
    try {
      await widget.onSubmit(t);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pad = (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.padding.bottom);

    return Material(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 8, 10 + pad),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- 공통 유틸 ---------- */
List<String> _extractImagesForDSSN(Map<String, dynamic> p) {
  final thumb = _str(p['thumbnail_url']);
  if (thumb != null && thumb.isNotEmpty) return [thumb];

  final pf = p['post_file'];
  if (pf is List) {
    final list = pf.whereType<Map>().toList()
      ..sort((a, b) => ((a['is_thumbnail'] == true) ? 0 : 1) -
          ((b['is_thumbnail'] == true) ? 0 : 1));
    final urls = <String>[];
    for (final it in list) {
      final u = _str(it['file_url']) ??
          _str(it['url']) ??
          _str(it['src']) ??
          _str(it['path']);
      if (u != null && u.isNotEmpty) urls.add(u);
    }
    if (urls.isNotEmpty) return urls;
  }
  return const [];
}

Map<String, dynamic>? _pickMap(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is Map<String, dynamic>) return v;
  }
  return null;
}

String? _str(dynamic v) => v == null ? null : (v is String ? v : v.toString());
