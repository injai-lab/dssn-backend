// src/tags.trending.js
import { Router } from 'express';
import { prisma } from './lib/prisma.js';

const r = Router();

/**
 * GET /tags/trending?days=7&limit=10
 *
 * - post_tag 를 groupBy 해서 "요즘 많이 쓰인 태그"를 구함
 * - days: 최근 N일 (기본 7, 최대 30)
 * - limit: 상위 N개 (기본 10, 최대 50)
 *
 * 응답:
 * {
 *   "items": [
 *     { "id": 3, "name": "캠퍼스라이프", "usage_count": 5 },
 *     { "id": 1, "name": "피크닉모먼트", "usage_count": 3 },
 *     ...
 *   ]
 * }
 */
r.get('/trending', async (req, res, next) => {
  try {
    const days = Math.min(30, parseInt(req.query.days) || 7);
    const limit = Math.min(50, parseInt(req.query.limit) || 10);

    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    // 1) post_tag를 tag_id 기준으로 groupBy
    //    + post.created_at >= since 인 것만 집계
    const grouped = await prisma.post_tag.groupBy({
      by: ['tag_id'],
      where: {
        post: {
          created_at: {
            gte: since,
          },
        },
      },
      _count: {
        tag_id: true,
      },
      orderBy: {
        _count: {
          tag_id: 'desc',
        },
      },
      take: limit,
    });

    // 2) groupBy 결과에서 tag_id 모아서 실제 태그 정보 조회
    const tagIds = grouped.map((g) => g.tag_id);
    if (tagIds.length === 0) {
      return res.json({ items: [] });
    }

    const tags = await prisma.tag.findMany({
      where: {
        id: { in: tagIds },
      },
    });

    const tagMap = new Map(tags.map((t) => [t.id, t]));

    // 3) id-기준으로 이름/카운트 묶어서 응답 형태로 변환
    const items = grouped
      .map((g) => {
        const t = tagMap.get(g.tag_id);
        if (!t) return null;
        return {
          id: t.id,
          name: t.name,
          usage_count: g._count.tag_id,
        };
      })
      .filter((x) => x !== null);

    res.json({ items });
  } catch (e) {
    next(e);
  }
});

export default r;
