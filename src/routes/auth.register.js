// src/routes/auth.register.js
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../lib/prisma.js';
import { signAccess, signRefresh } from '../lib/jwt.js';

const r = Router();
const ISSUE_TOKEN_ON_REGISTER = true;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ---------- helpers ----------
function normalizeGender(input) {
  if (!input) return null;
  const v = String(input).trim().toLowerCase();
  if (['남', '남자', 'male', 'm'].includes(v)) return 'male';
  if (['여', '여자', 'female', 'f'].includes(v)) return 'female';
  return null; // 모호하면 null 저장(스키마가 user_gender enum 이므로 허용: male|female|null)
}

// '20021122' | '2002-11-22' | ISO → Date or null (UTC 00:00로 고정)
function parseBirthday(input) {
  if (!input) return null;
  const s = String(input).trim();
  let d = null;
  if (/^\d{8}$/.test(s)) {
    const y = +s.slice(0, 4);
    const m = +s.slice(4, 6);
    const day = +s.slice(6, 8);
    d = new Date(Date.UTC(y, m - 1, day));
  } else if (/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    d = new Date(`${s}T00:00:00.000Z`);
  } else {
    d = new Date(s);
  }
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

const bad = (res, code, message, extra) =>
  res.status(code).json({ message, ...(extra ?? {}) });

// ---------- route ----------
/**
 * POST /auth/register
 * Body: { username, email, password, name?, student_no?, nickname, gender?, department?, birthday? }
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

    // 1) normalize
    const u = String(username ?? '').trim();
    const sn = String(student_no ?? username ?? '').trim(); // 기본값: username=학번
    const em = String(email ?? '')
      .trim()
      .toLowerCase();
    const pw = String(password ?? '');
    const nn = String(nickname ?? '').trim();
    const dept = department == null ? null : String(department).trim() || null;
    const gen = normalizeGender(gender);
    const bday = parseBirthday(birthday);

    // 2) validate
    if (!u || !em || !pw || !nn) {
      return bad(res, 400, 'username, email, password, nickname are required');
    }
    if (!/^\d{7}$/.test(u)) return bad(res, 400, 'username must be 7 digits');
    if (!/^\d{7}$/.test(sn))
      return bad(res, 400, 'student_no must be 7 digits');
    if (!EMAIL_REGEX.test(em)) return bad(res, 400, 'invalid email format');
    const [local, domain] = em.split('@');
    if (domain !== 'du.ac.kr')
      return bad(res, 400, 'email must be @du.ac.kr domain');
    if (local !== u)
      return bad(res, 400, 'email local-part must equal username');
    if (pw.length < 6)
      return bad(res, 400, 'password must be at least 6 chars');
    if ([...nn].length > 12) return bad(res, 400, 'nickname max length is 12');

    // 3) duplicate check
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
    if (dup)
      return bad(
        res,
        409,
        'duplicate: username/email/nickname/student_no already exists'
      );

    // 4) hash
    const hash = await bcrypt.hash(pw, 10);

    // 5) create
    const created = await prisma.user.create({
      data: {
        username: u,
        email: em,
        password: hash,
        name: name ?? null,
        student_no: sn,
        nickname: nn,
        gender: gen, // enum user_gender('male','female')
        department: dept, // String? (nullable)
        birthday: bday, // Date? (nullable)
      },
      select: {
        id: true,
        username: true,
        email: true,
        name: true,
        nickname: true,
        profile_img: true,
        gender: true,
        department: true,
        birthday: true,
        university: true,
        email_verified: true,
        created_at: true,
      },
    });

    // 6) issue tokens (optional)
    if (ISSUE_TOKEN_ON_REGISTER) {
      if (!process.env.JWT_SECRET)
        return bad(res, 500, 'JWT_SECRET not configured');
      const ver = 0;
      const access = signAccess(created.id, ver);
      const refresh = signRefresh(created.id, ver);
      return res.status(201).json({ user: created, access, refresh });
    }
    return res.status(201).json({ user: created });
  } catch (e) {
    // Prisma duplicate
    if (e?.code === 'P2002') {
      return bad(res, 409, 'unique constraint failed');
    }
    // Prisma enum/validation 등 상세 노출
    if (e?.name === 'PrismaClientValidationError') {
      return bad(res, 400, 'validation error', { detail: String(e.message) });
    }
    next(e);
  }
});

export default r;
