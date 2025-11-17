// src/routes/auth.register.js
import { Router } from 'express';
import bcrypt from 'bcryptjs'; // ✅ bcryptjs로 통일
import { prisma } from '../lib/prisma.js';
import { signAccess, signRefresh } from '../lib/jwt.js';
import { hashToken } from '../lib/token-hash.js';

const r = Router();

// 회원가입 직후 토큰 발급 여부
const ISSUE_TOKEN_ON_REGISTER = true;

// (개발용) 간단 이메일 형식만 체크
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** '14d' / '15m' 이런 TTL 문자열 → ms 로 변환 (login/refresh 와 동일 로직) */
function parseTtlMs(ttl) {
  const m = String(ttl).match(/^(\d+)([smhd])$/i);
  if (!m) return 14 * 24 * 60 * 60 * 1000;
  const n = Number(m[1]);
  const unit = m[2].toLowerCase();
  return (
    n *
    (unit === 's'
      ? 1000
      : unit === 'm'
      ? 60000
      : unit === 'h'
      ? 3600000
      : 86400000)
  );
}

/**
 * POST /auth/register
 * body: {
 *   username, email, password,
 *   name?, student_no, nickname,
 *   gender?, department?, birthday?
 * }
 * university는 DB default("동서울대학교")
 */
r.post('/register', async (req, res, next) => {
  try {
    const {
      username,
      email,
      password,
      name,
      student_no,
      nickname,
      gender,
      department,
      birthday,
    } = req.body ?? {};

    // 1) 정규화
    const u = String(username || '').trim();
    const em = String(email || '')
      .trim()
      .toLowerCase();
    const pw = String(password || '');
    const sn = String(student_no ?? '').trim();
    const nn = String(nickname ?? '').trim();
    const dept = department == null ? null : String(department).trim() || null;
    const gen = gender == null ? null : String(gender).trim() || null;

    // 2) 필수값 & 간단 검증
    if (!u || !em || !pw || !sn || !nn) {
      return res.status(400).json({
        message: 'username, email, password, student_no, nickname are required',
      });
    }
    if (!EMAIL_REGEX.test(em)) {
      return res.status(400).json({ message: 'Invalid email address' });
    }
    if (pw.length < 6) {
      return res
        .status(400)
        .json({ message: 'password must be at least 6 chars' });
    }

    // 3) 중복 체크
    const dup = await prisma.user.findFirst({
      where: {
        OR: [
          { username: u },
          { email: em },
          { nickname: nn },
          { student_no: sn },
        ],
      },
      select: { id: true },
    });
    if (dup) {
      return res
        .status(409)
        .json({ message: 'duplicate: username/email/nickname/student_no' });
    }

    // 4) 비밀번호 해시
    const hash = await bcrypt.hash(pw, 10);

    // 5) birthday 파싱(옵션)
    let birthdayDate = null;
    if (birthday) {
      const s = String(birthday).trim();
      let d;
      // Flutter에서 YYYYMMDD(예: 20001231) 형식으로 올 수도 있으니 처리
      if (/^\d{8}$/.test(s)) {
        const yyyy = s.slice(0, 4);
        const mm = s.slice(4, 6);
        const dd = s.slice(6, 8);
        d = new Date(`${yyyy}-${mm}-${dd}T00:00:00.000Z`);
      } else {
        d = new Date(s);
      }
      if (!isNaN(d.getTime())) birthdayDate = d;
    }

    // 6) 유저 생성 (token_version 은 DB default 0)
    const user = await prisma.user.create({
      data: {
        username: u,
        email: em,
        password: hash,
        name: name ?? null,
        student_no: sn,
        nickname: nn,
        gender: gen,
        department: dept,
        birthday: birthdayDate,
        // university: DB default 사용
      },
    });

    // 비밀번호는 응답에서 제거
    const { password: _pw, ...userOut } = user;

    // 7) 가입 즉시 토큰 발급 (access + refresh)
    if (ISSUE_TOKEN_ON_REGISTER) {
      // ✅ 이제 JWT_SECRET 체크 안 함. jwt.js 의 ACCESS/REFRESH_SECRET 사용
      const access = signAccess(user); // user.id + user.token_version 사용
      const refresh = signRefresh(user);

      // refresh 토큰도 DB에 저장 (login 과 동일 방식)
      const now = Date.now();
      const ttlMs = parseTtlMs(process.env.JWT_REFRESH_TTL ?? '14d');
      await prisma.refresh_token.create({
        data: {
          user_id: user.id,
          token_hash: hashToken(refresh),
          expires_at: new Date(now + ttlMs),
        },
      });

      return res.status(201).json({ user: userOut, access, refresh });
    }

    // 만약 ISSUE_TOKEN_ON_REGISTER = false 인 경우
    return res.status(201).json({ user: userOut });
  } catch (e) {
    if (e?.code === 'P2002') {
      return res.status(409).json({ message: 'unique constraint failed' });
    }
    next(e);
  }
});

export default r;
