// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import '../core/api_client.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  final VoidCallback? onUpdated;
  final VoidCallback? onDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onUpdated,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final p = _unwrapPost(post); // item 또는 item['post'] 통일

    final author = _str(_pickMap(p, ['user', 'author', 'writer'])?['nickname']) ??
        _str(_pickMap(p, ['user', 'author', 'writer'])?['name']) ??
        _str(p['author_name']) ??
        '익명';

    final content = _str(p['content']) ?? _str(p['text']) ?? '';
    final createdAt = _str(p['created_at']) ?? _str(p['createdAt']) ?? '';

    // _count 블록 우선 반영
    final Map<String, dynamic>? cnt = (p['_count'] is Map<String, dynamic>) ? p['_count'] : null;
    final likeCount = _toInt(cnt?['post_like']) ??
        _toInt(_pickFirst([p['like_count'], p['likes'], p['likeCount']])) ??
        0;
    final commentCount = _toInt(cnt?['comment']) ??
        _toInt(_pickFirst([p['comment_count'], p['comments'], p['commentCount']])) ??
        0;

    final images = _extractImagesForDSSN(p); // ← 이번 JSON 맞춤 파서
    final String? firstImage = images.isNotEmpty ? images.first : null;

    return InkWell(
      onTap: onTap,
      onLongPress: () {
        // 디버그: 우리가 최종 파싱한 URL들 보기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(images.isEmpty ? '이미지 없음(파싱 실패)' : images.join('\n'), maxLines: 5),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 & 시간
            Row(
              children: [
                const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE6F4EA)),
                const SizedBox(width: 8),
                Expanded(child: Text(author, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (createdAt.isNotEmpty)
                  Text(createdAt, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(width: 6),
                const Icon(Icons.more_vert, size: 18),
              ],
            ),
            const SizedBox(height: 8),

            // 본문
            Text(content, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),

            // 이미지 (있으면)
            if (firstImage != null) ...[
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
            ],

            // 액션 영역
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 18),
                const SizedBox(width: 4),
                Text('$likeCount'),
                const SizedBox(width: 16),
                const Icon(Icons.mode_comment_outlined, size: 18),
                const SizedBox(width: 4),
                Text('$commentCount'),
                const Spacer(),
                const Icon(Icons.bookmark_border, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────────
 * DSSN 맞춤 이미지 파서
 * (thumbnail_url, post_file[{file_url,is_thumbnail}], 그 외 일반 키들도 커버)
 * ───────────────────────────── */

List<String> _extractImagesForDSSN(Map<String, dynamic> p) {
  // 0) thumbnail_url 우선
  final thumb = _str(p['thumbnail_url']);
  if (thumb != null && thumb.isNotEmpty) return [_abs(thumb)];

  // 1) post_file 배열 (객체에 file_url / is_thumbnail)
  final pf = p['post_file'];
  if (pf is List) {
    // 썸네일 true인 걸 우선
    final withFlag = pf.whereType<Map>().toList();
    withFlag.sort((a, b) {
      final at = (a['is_thumbnail'] == true) ? 0 : 1;
      final bt = (b['is_thumbnail'] == true) ? 0 : 1;
      return at.compareTo(bt);
    });

    final urls = <String>[];
    for (final it in withFlag) {
      final u = _str(it['file_url']) ?? _str(it['url']) ?? _str(it['src']) ?? _str(it['path']);
      if (u != null && u.isNotEmpty) urls.add(_abs(u));
    }
    if (urls.isNotEmpty) return urls;
  }

  // 2) 예비 키들(기존 범용 파서)
  final fallback = _extractImagesRobust(p);
  return fallback;
}

/* ─────────────────────────────
 * 기존 범용 유틸 + 경로 보정
 * ───────────────────────────── */

Map<String, dynamic> _unwrapPost(Map<String, dynamic> item) {
  final inner = item['post'];
  if (inner is Map<String, dynamic>) return inner;
  return item;
}

List<String> _extractImagesRobust(Map<String, dynamic> p) {
  final single = _str(_pickFirst([
    p['image'],
    p['cover'],
    p['thumbnail'],
    p['thumb'],
    p['first_image_url'],
    p['thumbnail_url'], // 혹시 위에서 못 잡는 경우를 위해 한번 더
  ]));
  if (single != null && single.isNotEmpty) return [_abs(single)];

  final keys = [
    'files',
    'images',
    'image_urls',
    'imageUrls',
    'photos',
    'pictures',
    'media',
    'attachments',
    'content_images',
    'media_urls',
    'mediaUrls',
    // DSSN 유사 키까지 보강
    'post_files',
    'post_file',
  ];

  for (final k in keys) {
    final v = p[k];
    if (v == null) continue;

    final urls = <String>[];

    if (v is List) {
      for (final it in v) {
        if (it is String) {
          _pushIfUrl(urls, it);
        } else if (it is Map) {
          final u = _str(_pickFirst([
            it['file_url'], // DSSN
            it['url'],
            it['src'],
            it['path'],
            it['downloadUrl'],
            it['fileUrl'],
          ]));
          if (u != null) _pushIfUrl(urls, u);
        }
      }
      if (urls.isNotEmpty) return urls;
    }

    if (v is String) {
      final parts = v.split(RegExp(r'[,\s]+')).where((s) => s.trim().isNotEmpty);
      for (final s in parts) {
        _pushIfUrl(urls, s);
      }
      if (urls.isNotEmpty) return urls;
    }
  }

  return const [];
}

void _pushIfUrl(List<String> out, String raw) {
  final u = _abs(raw);
  if (u.isNotEmpty) out.add(u);
}

String _abs(String u) {
  if (u.isEmpty) return u;

  if (u.startsWith('http://') || u.startsWith('https://')) {
    return _fixEmulatorHost(u);
  }

  String base = '';
  try {
    base = ApiClient.I.dio.options.baseUrl;
  } catch (_) {}

  if (base.isEmpty) return u;

  if (u.startsWith('/')) return _fixEmulatorHost('$base$u');
  return _fixEmulatorHost('$base/$u');
}

String _fixEmulatorHost(String url) {
  return url
      .replaceAll('://localhost', '://10.0.2.2')
      .replaceAll('://127.0.0.1', '://10.0.2.2');
}

Map<String, dynamic>? _pickMap(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is Map<String, dynamic>) return v;
  }
  return null;
}

dynamic _pickFirst(List<dynamic> candidates) {
  for (final x in candidates) {
    if (x != null) return x;
  }
  return null;
}

String? _str(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}
