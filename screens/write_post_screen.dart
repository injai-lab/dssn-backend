// lib/screens/write_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/upload_api.dart';

/// 홈(기본) 게시판 ID — 서버의 홈 피드 ID와 맞추세요.
const int kHomeCommunityId = 1;

class WritePostScreen extends StatefulWidget {
  const WritePostScreen({super.key});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final _form = GlobalKey<FormState>();
  final _contentCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController(); // 수동 URL(선택)

  // 갤러리에서 선택한 파일
  final List<XFile> _pickedFiles = [];
  // 업로드 완료된 파일 URL
  final List<String> _uploadedUrls = [];
  // 업로드 진행률 (index → 0~1)
  final Map<int, double> _progress = {};

  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _imageUrlCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────
  // 갤러리 이미지 선택
  // ─────────────────────────────
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    try {
      final imgs = await picker.pickMultiImage(imageQuality: 90);
      if (imgs.isEmpty) return;
      setState(() {
        _pickedFiles
          ..clear()
          ..addAll(imgs);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  // ─────────────────────────────
  // 서버 업로드 (UploadApi)
  // ─────────────────────────────
  Future<void> _uploadAll() async {
    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 이미지를 선택해 주세요.')),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadedUrls.clear();
      _progress.clear();
    });

    for (int i = 0; i < _pickedFiles.length; i++) {
      final x = _pickedFiles[i];
      try {
        final url = await UploadApi.I.uploadOne(
          File(x.path),
          onProgress: (sent, total) {
            if (!mounted) return;
            if (total > 0) setState(() => _progress[i] = sent / total);
          },
        );
        _uploadedUrls.add(url);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패(${i + 1}/${_pickedFiles.length}): $e')),
        );
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (_uploadedUrls.isNotEmpty) {
      _imageUrlCtrl.clear(); // 수동 URL과 충돌 방지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 완료: ${_uploadedUrls.length}개')),
      );
    }
  }

  // ─────────────────────────────
  // 게시하기 (/posts: {content, files[], community_id})
  // 항상 community_id = kHomeCommunityId
  // ─────────────────────────────
  Future<void> _submitPost() async {
    if (_uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 업로드 중입니다. 잠시만 기다려 주세요.')),
      );
      return;
    }
    if (_submitting) return;
    if (!_form.currentState!.validate()) return;

    const maxLen = 1000;
    final text = _contentCtrl.text.trim();
    if (text.length > maxLen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 1000자까지 입력 가능합니다.')),
      );
      return;
    }

    // 최종 전송 이미지 목록: 업로드된 URL들 + 수동 입력 1개(있으면)
    final manual = _imageUrlCtrl.text.trim();
    final List<String> files = [
      ..._uploadedUrls,
      if (manual.isNotEmpty) manual,
    ];

    setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{
        'content': text,
        if (files.isNotEmpty) 'files': files,
        'community_id': kHomeCommunityId, // 고정: 홈 피드
      };

      final res = await ApiClient.I.dio.post('/posts', data: payload);
      final data = res.data;
      final created = (data is Map) ? data : null;

      if (!mounted) return;
      Navigator.pop(context, created ?? true);
    } on Exception catch (e) {
      String msg = '게시 실패';
      try {
        final dioErr = e as dynamic;
        final body = dioErr.response?.data;
        if (body != null) msg = '$msg: $body';
      } catch (_) {
        msg = '$msg: $e';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    const maxLen = 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('새 글 (홈)'),
        actions: [
          TextButton(
            onPressed: (_uploading || _submitting) ? null : _submitPost,
            child: _submitting
                ? const SizedBox(
              height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('게시', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // 본문
              TextFormField(
                controller: _contentCtrl,
                minLines: 5,
                maxLines: 8,
                maxLength: maxLen,
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '홈 피드에 무엇을 남길까요? #해시태그 가능',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return '내용을 입력해 주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ① 수동 이미지 URL (선택)
              TextFormField(
                controller: _imageUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '이미지 URL(선택)',
                  hintText: 'https:// 로 시작하는 이미지 주소',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (_imageUrlCtrl.text.trim().isNotEmpty)
                _UrlPreview(url: _imageUrlCtrl.text.trim()),

              const SizedBox(height: 16),

              // ② 갤러리 선택 + 업로드
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _pickedFiles.isEmpty ? '갤러리에서 이미지 선택' : '이미지 다시 선택',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                    (_pickedFiles.isEmpty || _uploading) ? null : _uploadAll,
                    icon: _uploading
                        ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: const Text('업로드'),
                  ),
                ],
              ),

              if (_pickedFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PickedPreviewGrid(files: _pickedFiles, progress: _progress),
                const SizedBox(height: 4),
                Text(
                  _uploadedUrls.isEmpty
                      ? '※ 업로드 버튼을 눌러 서버로 전송하세요.'
                      : '업로드 완료(${_uploadedUrls.length}/${_pickedFiles.length})',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],

              const SizedBox(height: 24),

              // 게시 버튼
              FilledButton.icon(
                onPressed: (_uploading || _submitting) ? null : _submitPost,
                icon: const Icon(Icons.send),
                label: const Text('홈에 게시하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────── URL 미리보기 ───────── */
class _UrlPreview extends StatelessWidget {
  final String url;
  const _UrlPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Text('이미지를 불러올 수 없어요'),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────── 선택 이미지 그리드 + 업로드 진행률 ───────── */
class _PickedPreviewGrid extends StatelessWidget {
  final List<XFile> files;
  final Map<int, double> progress;
  const _PickedPreviewGrid({required this.files, required this.progress});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: files.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (ctx, i) {
        final x = files[i];
        final p = (progress[i] ?? 0.0).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(x.path), fit: BoxFit.cover),
              ),
            ),
            if (p > 0 && p < 1)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.all(6),
                  child: LinearProgressIndicator(value: p),
                ),
              ),
            if (p >= 1)
              const Positioned(
                right: 6,
                top: 6,
                child: Icon(Icons.check_circle, color: Colors.lightGreenAccent),
              ),
          ],
        );
      },
    );
  }
}
