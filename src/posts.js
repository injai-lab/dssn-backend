// posts.js — 게시글 라우트 (목록/생성/수정/삭제 + 상세)

import { Router } from 'express';
import { prisma } from './lib/prisma.js';
import { extractTags } from './lib/tags.js';
import { requireMe, assertOwner } from './mw.js';

const r = Router();

/* ───────────────── 공통 유틸 ───────────────── */
function parsePage(req) {
  const limit = Math.min(50, parseInt(req.query.limit) || 20);
  const cursor = req.query.cursor ? Number(req.query.cursor) : undefined;
  const page = req.query.page
    ? Math.max(1, parseInt(req.query.page))
    : undefined; // 폴백
  return { limit, cursor, page };
}

// community_id → category 추론 테이블(없으면 undefined 유지)
const CATEGORY_BY_COMMUNITY = new Map([
  [2, 'free'],
  [3, 'qna'],
  [4, 'info'],
]);

const baseInclude = {
  user: {
    select: {
      id: true,
      username: true,
      nickname: true,
      profile_img: true,
      department: true,
    },
  },
  // 썸네일 먼저 보이도록 정렬
  post_file: { orderBy: [{ is_thumbnail: 'desc' }, { id: 'asc' }] },
  post_tag: { include: { tag: true } },
  _count: {
    select: { comment: true, post_like: true, bookmark: true, repost: true },
  },
};

async function decorateViewerFlagsAndThumb(items, me) {
  if (!items?.length) return items;
  const ids = items.map((i) => i.id);

  let likeSet = new Set();
  let bmSet = new Set();
  let rpSet = new Set();

  if (me) {
    const [likes, bms, rps] = await Promise.all([
      prisma.post_like.findMany({
        where: { user_id: me, post_id: { in: ids } },
        select: { post_id: true },
      }),
      prisma.bookmark.findMany({
        where: { user_id: me, post_id: { in: ids } },
        select: { post_id: true },
      }),
      prisma.repost.findMany({
        where: { user_id: me, post_id: { in: ids } },
        select: { post_id: true },
      }),
    ]);
    likeSet = new Set(likes.map((x) => x.post_id));
    bmSet = new Set(bms.map((x) => x.post_id));
    rpSet = new Set(rps.map((x) => x.post_id));
  }

  for (const it of items) {
    it.viewer_has_liked = me ? likeSet.has(it.id) : false;
    it.viewer_has_bookmarked = me ? bmSet.has(it.id) : false;
    it.viewer_has_reposted = me ? rpSet.has(it.id) : false;

    const thumb =
      (it.post_file || []).find((f) => f.is_thumbnail) ||
      (it.post_file || [])[0];
    it.thumbnail_url = thumb?.file_url ?? null;
  }
  return items;
}

/* ───────────────── 목록: 전체/커뮤니티별/홈(community_id=null) ───────────────── */
r.get('/', async (req, res, next) => {
  try {
    const communityId = req.query.community_id
      ? Number(req.query.community_id)
      : undefined;
    const homeOnly = String(req.query.home ?? '') === '1';

    const { limit, cursor, page } = parsePage(req);

    const where = communityId
      ? { community_id: communityId }
      : homeOnly
      ? { community_id: null }
      : {};

    const queryBase = {
      where,
      orderBy: { id: 'desc' },
      include: baseInclude,
    };

    let items = [];
    let next_cursor = null;

    if (cursor) {
      items = await prisma.post.findMany({
        ...queryBase,
        take: limit + 1,
        cursor: { id: cursor },
        skip: 1,
      });
      if (items.length > limit) {
        const last = items.pop();
        next_cursor = last.id;
      }
    } else if (page) {
      const skip = (page - 1) * limit;
      items = await prisma.post.findMany({ ...queryBase, take: limit, skip });
      // page 모드는 next_cursor 미제공
    } else {
      items = await prisma.post.findMany({ ...queryBase, take: limit + 1 });
      if (items.length > limit) {
        const last = items.pop();
        next_cursor = last.id;
      }
    }

    await decorateViewerFlagsAndThumb(items, req.me ?? null);
    res.json({ items, next_cursor });
  } catch (e) {
    next(e);
  }
});

/* ───────────────── 생성: category/파일 다양한 포맷 허용 ───────────────── */
r.post('/', requireMe, async (req, res, next) => {
  try {
    const me = req.me;

    // 흔히 쓰는 다양한 키를 허용
    const {
      community_id,
      title,
      content,
      category, // 'free' | 'qna' | 'info' (옵션)
      files,
      file_urls,
      fileUrls,
      images,
      image_urls,
      attachments,
      medias,
      media,
    } = req.body ?? {};

    if (!title && !content) {
      return res
        .status(400)
        .json({ message: 'title 또는 content 중 하나는 필요합니다.' });
    }

    // 1) 파일 목록 정규화: [string] 또는 [{url,file_url,is_thumbnail}] 모두 지원
    const rawFiles =
      files ??
      file_urls ??
      fileUrls ??
      images ??
      image_urls ??
      attachments ??
      medias ??
      media ??
      [];

    const normalized = [];
    if (Array.isArray(rawFiles)) {
      for (const it of rawFiles) {
        if (!it) continue;
        if (typeof it === 'string') {
          normalized.push({ url: it, is_thumbnail: false });
        } else if (typeof it === 'object') {
          const url =
            it.url ?? it.file_url ?? it.src ?? it.cdn_url ?? it.path ?? '';
          if (typeof url === 'string' && url.trim()) {
            normalized.push({
              url: url.trim(),
              is_thumbnail: !!it.is_thumbnail,
            });
          }
        }
      }
    }

    // 2) community_id 정규화(홈은 null 가능)
    const cid =
      community_id != null && community_id !== '' ? Number(community_id) : null;

    // 3) category 확정(클라이언트 값 우선, 없으면 community_id로 추론)
    const cat =
      typeof category === 'string' && category.trim()
        ? category.trim()
        : CATEGORY_BY_COMMUNITY.get(cid) ?? null;

    // 4) 태그 추출
    const tags = extractTags(`${title ?? ''} ${content ?? ''}`);

    // 5) 트랜잭션으로 생성
    const created = await prisma.$transaction(async (tx) => {
      const post = await tx.post.create({
        data: {
          user_id: me,
          community_id: cid, // 홈 스코프면 null
          title: title ?? null,
          content: content ?? null,
          category: cat, // free | qna | info | null
        },
        select: { id: true },
      });

      // 파일 저장(첫 항목을 기본 썸네일, 지정 시 지정값 우선)
      if (normalized.length) {
        const hasThumb = normalized.some((f) => f.is_thumbnail);
        const payload = normalized.map((f, i) => ({
          post_id: post.id,
          file_url: f.url,
          is_thumbnail: hasThumb ? !!f.is_thumbnail : i === 0,
        }));
        await tx.post_file.createMany({ data: payload });
      }

      // 태그 저장(중복 무시)
      for (const tagName of tags) {
        const tag = await tx.tag.upsert({
          where: { name: tagName },
          create: { name: tagName },
          update: {},
        });
        await tx.post_tag
          .create({ data: { post_id: post.id, tag_id: tag.id } })
          .catch((e) => {
            if (e?.code !== 'P2002') throw e;
          });
      }

      return post;
    });

    // 생성된 post 전체정보 응답(정렬·카운트 포함)
    const full = await prisma.post.findUnique({
      where: { id: created.id },
      include: baseInclude,
    });
    await decorateViewerFlagsAndThumb([full], req.me ?? null);

    res.status(201).json({ ok: true, post: full });
  } catch (e) {
    if (e?.code === 'P2003') {
      return res.status(400).json({ message: 'Invalid community_id' });
    }
    next(e);
  }
});

/* ───────────────── 상세 ───────────────── */
r.get('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const me = req.me ?? null;

    const post = await prisma.post.findUnique({
      where: { id },
      include: baseInclude,
    });
    if (!post) return res.status(404).json({ message: 'not found' });

    await decorateViewerFlagsAndThumb([post], me);
    res.json({ post });
  } catch (e) {
    next(e);
  }
});

/* ───────────────── 수정(작성자만) ───────────────── */
r.put('/:id', requireMe, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const p = await prisma.post.findUnique({ where: { id } });
    if (!p) return res.status(404).json({ message: 'not found' });
    if (!assertOwner(p.user_id, req.me, res)) return;

    const data = {};
    if ('title' in req.body) data.title = req.body.title ?? null;
    if ('content' in req.body) data.content = req.body.content ?? null;
    if ('is_deleted' in req.body) data.is_deleted = !!req.body.is_deleted;
    if ('category' in req.body) data.category = req.body.category ?? null; // 카테고리도 수정 가능

    const updated = await prisma.post.update({
      where: { id },
      data,
      include: baseInclude,
    });
    await decorateViewerFlagsAndThumb([updated], req.me ?? null);
    res.json(updated);
  } catch (e) {
    next(e);
  }
});

/* ───────────────── 삭제(작성자만, 하드 삭제) ───────────────── */
r.delete('/:id', requireMe, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const p = await prisma.post.findUnique({ where: { id } });
    if (!p) return res.status(404).json({ message: 'not found' });
    if (!assertOwner(p.user_id, req.me, res)) return;

    await prisma.post.delete({ where: { id } });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

export default r;
