import 'package:flutter/material.dart';

class CommunityPost {
  final int id;
  final String? title;
  final String? content;
  final String authorName;
  final String? authorAvatar;
  final DateTime createdAt;
  final List<String> images; // file_url 목록
  final int likeCount;
  final int commentCount;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;

  CommunityPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
    required this.images,
    required this.likeCount,
    required this.commentCount,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
  });
}

typedef VoidToggle = Future<void> Function(int postId);

class CommunityPostCard extends StatelessWidget {
  final CommunityPost p;
  final VoidCallback onTap;
  final VoidToggle onToggleLike;
  final VoidToggle onToggleBookmark;

  const CommunityPostCard({
    super.key,
    required this.p,
    required this.onTap,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _fmtTime(p.createdAt);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 영역
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage:
                  p.authorAvatar != null ? NetworkImage(p.authorAvatar!) : null,
                  child: p.authorAvatar == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            // ⬇️ 제목: 커뮤니티 전용 — 본문보다 “굵고 크게”
            if ((p.title ?? '').trim().isNotEmpty) ...[
              Text(
                p.title!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
            ],

            // 본문 미리보기
            if ((p.content ?? '').trim().isNotEmpty)
              Text(
                p.content!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),

            // 이미지(첫 장 썸네일)
            if (p.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    p.images.first,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // 액션 바
            Row(
              children: [
                _IconTextButton(
                  icon: p.viewerHasLiked ? Icons.favorite : Icons.favorite_border,
                  color: p.viewerHasLiked ? Colors.red : Colors.grey.shade700,
                  text: p.likeCount.toString(),
                  onTap: () => onToggleLike(p.id),
                ),
                const SizedBox(width: 14),
                _IconTextButton(
                  icon: Icons.chat_bubble_outline,
                  text: p.commentCount.toString(),
                  onTap: onTap, // 상세로 이동해서 댓글 보기
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onToggleBookmark(p.id),
                  icon: Icon(
                    p.viewerHasBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: p.viewerHasBookmarked ? Colors.blueAccent : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    // 간단 표시
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }
}

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback onTap;

  const _IconTextButton({
    required this.icon,
    required this.text,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
