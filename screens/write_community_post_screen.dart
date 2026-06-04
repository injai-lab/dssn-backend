import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

/// 네 DB의 커뮤니티 id로 바꿔 써도 됨(여러 커뮤니티 운영이면 arguments로 override 가능)
const int kCommunityIdDefault = 1;

// 카테고리(게시판) 정의
class _Cat {
  final String key;  // 'free' | 'qna' | 'info'
  final String label;
  const _Cat(this.key, this.label);
}
const List<_Cat> _cats = [
  _Cat('free', '자유게시판'),
  _Cat('qna',  '질문게시판'),
  _Cat('info', '정보공유 게시판'),
];
String? _categoryFromBoardId(int? boardId) {
  switch (boardId) {
    case 1: return 'free';
    case 2: return 'qna';
    case 3: return 'info';
    default: return null;
  }
}
String _labelOf(String? key) =>
    _cats.firstWhere((c) => c.key == key, orElse: () => const _Cat('', '선택되지 않음')).label;

/// 커뮤니티 글쓰기(게시판 선택 + 제목 필수 + 이미지(갤러리/URL))
class WriteCommunityPostScreen extends StatefulWidget {
  /// route arguments:
  /// - board_id | boardId : 1(free) / 2(qna) / 3(info) → 카테고리 미리 선택
  /// - community_id | communityId : 특정 커뮤니티 ID로 강제
  const WriteCommunityPostScreen({super.key});

  @override
  State<WriteCommunityPostScreen> createState() => _WriteCommunityPostScreenState();
}

class _WriteCommunityPostScreenState extends State<WriteCommunityPostScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _picker = ImagePicker();
  final Dio _dio = ApiClient.I.dio;

  bool _sending = false;
  bool _argsApplied = false;

  /// 카테고리('free' | 'qna' | 'info')
  String? _category;

  /// 커뮤니티 id (기본값)
  int _cid = kCommunityIdDefault;

  /// 로컬에서 고른 이미지들
  final List<XFile> _localImages = [];
  /// 사용자가 직접 넣은 이미지 URL들
  final List<String> _urlImages = [];
  /// 로컬 이미지를 업로드하고 받은 URL들(제출 직전 세팅)
  final List<String> _uploadedUrls = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    _argsApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      int? bid;
      if (args['board_id'] is int) bid = args['board_id'] as int;
      if (args['boardId']  is int) bid = args['boardId']  as int;
      _category = _categoryFromBoardId(bid);

      if (args['community_id'] is int) _cid = args['community_id'] as int;
      if (args['communityId']  is int) _cid = args['communityId']  as int;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── 이미지: 갤러리 선택 ─────────────────────────────
  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _localImages.add(x));
  }

  // ── 이미지: URL로 추가 ───────────────────────────────
  Future<void> _addImageByUrl() async {
    final ctrl = TextEditingController();
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이미지 URL 추가'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https:// 로 시작하는 이미지 주소',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('추가')),
        ],
      ),
    );
    if (picked == null || picked.isEmpty) return;
    if (!picked.startsWith('http')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 URL을 입력해주세요.')),
      );
      return;
    }
    setState(() => _urlImages.add(picked));
  }

  // ── 로컬 이미지 업로드 → URL 확보 ───────────────────
  Future<void> _uploadLocalImagesIfNeeded() async {
    _uploadedUrls.clear();
    for (final x in _localImages) {
      final fileName = x.path.split('/').last;
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(x.path, filename: fileName),
      });
      final res = await _dio.post('/upload', data: form);
      final url = (res.data['file_url'] ?? res.data['url'] ?? '').toString();
      if (url.isNotEmpty) _uploadedUrls.add(url);
    }
  }

  List<Map<String, dynamic>> get _filesPayload {
    final all = <String>[..._urlImages, ..._uploadedUrls];
    return all.map((u) => {'url': u}).toList();
  }

  // ── 카테고리 선택 바텀시트 ─────────────────────────
  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('게시판 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  title: Text(_cats[i].label),
                  trailing: _category == _cats[i].key
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(context, _cats[i].key),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  // ── 등록 ───────────────────────────────────────────
  Future<void> _submit() async {
    if (_category == null || _category!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시판(카테고리)을 선택해주세요.')),
      );
      return;
    }
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('커뮤니티 글은 제목이 필요합니다.')),
      );
      return;
    }
    if (_title.text.trim().isEmpty &&
        _content.text.trim().isEmpty &&
        _localImages.isEmpty &&
        _urlImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목/본문/이미지 중 하나는 입력해주세요.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _uploadLocalImagesIfNeeded();

      final body = <String, dynamic>{
        'category': _category, // 'free' | 'qna' | 'info'
        'title': _title.text.trim(),
        'content': _content.text.trim().isEmpty ? null : _content.text.trim(),
        if (_urlImages.isNotEmpty || _uploadedUrls.isNotEmpty) 'files': _filesPayload,
      };

      // /communities/{cid}/posts
      await _dio.post('/communities/$_cid/posts', data: body);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 중 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _labelOf(_category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티 글쓰기'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('등록', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 게시판 선택
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.forum_outlined, color: Color(0xFF2E7D32)),
              title: const Text('게시판(카테고리) 선택', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                _category == null ? '선택되지 않음' : selectedLabel,
                style: TextStyle(
                  color: _category == null ? Colors.redAccent : Colors.black54,
                ),
              ),
              trailing: const Icon(Icons.expand_more),
              onTap: _pickCategory,
            ),
            const SizedBox(height: 8),

            // 제목 (필수, 본문보다 더 큼/굵음)
            TextField(
              controller: _title,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '제목 (필수)',
                hintText: '게시판 제목을 입력하세요',
                labelStyle: TextStyle(fontWeight: FontWeight.w700),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 18, height: 1.25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            // 본문
            TextField(
              controller: _content,
              minLines: 6,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText: '본문을 입력하세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // 이미지 추가 버튼: 갤러리 / URL
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _sending ? null : _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('사진 선택'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _addImageByUrl,
                  icon: const Icon(Icons.link),
                  label: const Text('URL로 추가'),
                ),
                const SizedBox(width: 8),
                if (_localImages.isNotEmpty || _urlImages.isNotEmpty)
                  Text('(${_localImages.length + _urlImages.length}장)',
                      style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),

            // 미리보기(URL + 로컬)
            if (_urlImages.isNotEmpty || _localImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // URL 프리뷰
                  ..._urlImages.map((u) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          u,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: _sending ? null : () => setState(() => _urlImages.remove(u)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )),
                  // 로컬 프리뷰
                  ..._localImages.map((x) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(x.path),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: _sending ? null : () => setState(() => _localImages.remove(x)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
