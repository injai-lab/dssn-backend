import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class CommentScreen extends StatefulWidget {
  /// 상세/피드 등 어디서든 넘어올 수 있게 유연하게 받습니다.
  final int? postId;
  final Map<String, dynamic>? post; // 선택: 글 프리뷰
  const CommentScreen({super.key, this.postId, this.post});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  late final Dio _dio;

  int? _postId;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dio = ApiClient.I.dio;

    // postId 추출 (postId > post.id > post.post_id)
    _postId = widget.postId ??
        _int(widget.post?['id']) ??
        _int(widget.post?['post_id']);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 라우트 arguments도 지원: { postId, post, id }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _postId ??= _int(args['postId']) ?? _int(args['id']);
      if (args['post'] is Map) {
        _postId ??= _int((args['post'] as Map)['id']) ??
            _int((args['post'] as Map)['post_id']);
      }
    }
    _fetch();
  }

  /* ───────── API ───────── */

  Future<void> _fetch() async {
    if (_postId == null) {
      setState(() => _error = '잘못된 글 ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final tries = <Future<Response>>[
      _dio.get('/comments', queryParameters: {'post_id': _postId}), // 우리 서버 규격
      _dio.get('/comments/$_postId'),                               // 보조
      _dio.get('/posts/$_postId/comments'),                         // 보조
    ];

    DioException? last;
    for (final req in tries) {
      try {
        final r = await req;
        final d = r.data;

        List raw = const [];
        if (d is Map && d['items'] is List) raw = d['items'];
        else if (d is Map && d['comments'] is List) raw = d['comments'];
        else if (d is List) raw = d;

        setState(() {
          _items = raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
          _loading = false;
        });
        return;
      } on DioException catch (e) {
        last = e;
        continue;
      }
    }

    setState(() {
      _loading = false;
      _error = '불러오기 실패: ${last?.response?.statusCode ?? ''} ${last?.message ?? ''}'.trim();
    });
  }

  Future<void> _send(String text) async {
    if (_postId == null) return;
    final t = text.trim();
    if (t.isEmpty) return;

    // 낙관적 추가
    final optimistic = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch,
      'content': t,
      'created_at': DateTime.now().toIso8601String(),
      'user': {'nickname': '나'},
      '_optimistic': true,
    };
    setState(() => _items = [optimistic, ..._items]);

    try {
      final r = await _dio.post('/comments', data: {
        'post_id': _postId,
        'content': t,
      });

      Map<String, dynamic>? created;
      if (r.data is Map<String, dynamic>) {
        created = r.data as Map<String, dynamic>;
      }

      if (!mounted) return;
      if (created != null) {
        final others = _items.where((c) => c['_optimistic'] != true).toList();
        setState(() => _items = [created!, ...others]);
      } else {
        await _fetch();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = _items.where((c) => c['_optimistic'] != true).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 전송 실패: $e')),
      );
    }
  }

  /* ───────── UI ───────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('댓글')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            if (_items.isEmpty)
              Text('아직 댓글이 없어요.', style: TextStyle(color: Colors.grey.shade600))
            else
              ..._items.map((c) => _CommentTile(c)),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: _CommentInput(onSubmit: _send),
    );
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/* ───────── 타일 & 입력창 ───────── */

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CommentTile(this.c);

  @override
  Widget build(BuildContext context) {
    final author = _str(_pickMap(c, ['user', 'author', 'writer'])?['nickname']) ??
        _str(c['author_name']) ?? '익명';
    final content = _str(c['content']) ?? '';
    final createdAt = _str(c['created_at']) ?? _str(c['createdAt']) ?? '';
    final optimistic = c['_optimistic'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE6F4EA)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(author, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(
                createdAt.isNotEmpty ? createdAt : (optimistic ? '전송 중…' : ''),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ]),
            const SizedBox(height: 4),
            Text(content),
          ]),
        ),
      ]),
    );
  }
}

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

/* ───────── 유틸 ───────── */

Map<String, dynamic>? _pickMap(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is Map<String, dynamic>) return v;
  }
  return null;
}

String? _str(dynamic v) => v == null ? null : (v is String ? v : v.toString());
