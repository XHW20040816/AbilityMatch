'use strict';

/**
 * 账号服务核心逻辑：与传输层解耦，本地 Node 服务与 AGC 云函数共用同一份实现。
 * 只依赖 Node 内置模块，无需 npm install。
 *
 * 约定：
 * - 所有方法返回 { status, body }，body = { ok, data } 或 { ok:false, code, message }
 * - store 只需实现 findByAccount / findById / insert / update / count
 */

const crypto = require('crypto');

const ROLE_STUDENT = 'STUDENT';
const ROLE_COMPANY = 'COMPANY';

const DEFAULT_ACCESS_TTL = 2 * 3600;
const DEFAULT_REFRESH_TTL = 30 * 86400;

function b64u(input) {
  return Buffer.from(input).toString('base64url');
}

function signToken(payload, secret, ttlSec) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64u(JSON.stringify(Object.assign({}, payload, { iat: now, exp: now + ttlSec })));
  const signature = crypto.createHmac('sha256', secret).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

function verifyToken(token, secret) {
  if (typeof token !== 'string') {
    return null;
  }
  const parts = token.split('.');
  if (parts.length !== 3) {
    return null;
  }
  const expected = crypto.createHmac('sha256', secret).update(`${parts[0]}.${parts[1]}`).digest('base64url');
  const actual = parts[2];
  // 长度不一致时 timingSafeEqual 会抛错，先挡住
  if (expected.length !== actual.length) {
    return null;
  }
  if (!crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(actual))) {
    return null;
  }
  let payload;
  try {
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch (e) {
    return null;
  }
  if (typeof payload.exp !== 'number' || payload.exp * 1000 < Date.now()) {
    return null;
  }
  return payload;
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 32).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

function verifyPassword(password, stored) {
  const parts = String(stored || '').split('$');
  if (parts.length !== 3 || parts[0] !== 'scrypt') {
    return false;
  }
  const calc = crypto.scryptSync(password, parts[1], 32);
  const expect = Buffer.from(parts[2], 'hex');
  return calc.length === expect.length && crypto.timingSafeEqual(calc, expect);
}

function normalizeAccount(account) {
  return String(account || '').trim().toLowerCase();
}

function ok(data) {
  return { status: 200, body: { ok: true, data } };
}

function fail(status, code, message) {
  return { status, body: { ok: false, code, message } };
}

function publicAccount(row) {
  return {
    id: row.id,
    role: row.role,
    account: row.account,
    displayName: row.displayName || '',
    verifyStatus: row.verifyStatus || 'PENDING'
  };
}

function createAuthService(store, options) {
  const opts = options || {};
  const secret = opts.secret || process.env.AUTH_JWT_SECRET || 'abilitymatch-dev-secret-change-me';
  const accessTtl = opts.accessTtl || DEFAULT_ACCESS_TTL;
  const refreshTtl = opts.refreshTtl || DEFAULT_REFRESH_TTL;

  function issueSession(row) {
    const token = signToken({ sub: row.id, acc: row.account, role: row.role, typ: 'access' }, secret, accessTtl);
    const refreshToken = signToken({ sub: row.id, typ: 'refresh' }, secret, refreshTtl);
    return { token, refreshToken, expiresIn: accessTtl, account: publicAccount(row) };
  }

  function validateCredential(role, account, password) {
    if (role !== ROLE_STUDENT && role !== ROLE_COMPANY) {
      return '账号角色不合法';
    }
    if (account.length < 4) {
      return '登录账号至少 4 个字符';
    }
    if (password.length < 6) {
      return '密码至少 6 位';
    }
    if (account.length > 64 || password.length > 64) {
      return '账号或密码过长';
    }
    return '';
  }

  return {
    /** POST /api/auth/register */
    async register(body) {
      const role = String(body.role || '');
      const account = normalizeAccount(body.account);
      const password = String(body.password || '');
      const invalid = validateCredential(role, account, password);
      if (invalid) {
        return fail(400, 'INVALID_INPUT', invalid);
      }
      const exists = await store.findByAccount(account);
      if (exists) {
        return fail(409, 'ACCOUNT_TAKEN', '该账号已注册，请直接登录');
      }
      const id = await store.insert({
        role,
        account,
        passwordHash: hashPassword(password),
        displayName: String(body.displayName || account).trim(),
        verifyStatus: 'PENDING',
        createTime: Date.now(),
        updateTime: Date.now()
      });
      const row = await store.findById(id);
      return ok(issueSession(row));
    },

    /** POST /api/auth/login */
    async login(body) {
      const role = String(body.role || '');
      const account = normalizeAccount(body.account);
      const password = String(body.password || '');
      const invalid = validateCredential(role, account, password);
      if (invalid) {
        return fail(400, 'INVALID_INPUT', invalid);
      }
      const row = await store.findByAccount(account);
      if (!row) {
        return fail(404, 'ACCOUNT_NOT_FOUND', '账号不存在，请先注册');
      }
      if (row.role !== role) {
        const message = role === ROLE_STUDENT
          ? '该账号是企业账号，请切换到企业端'
          : '该账号是学生账号，请切换到学生端';
        return fail(403, 'ROLE_MISMATCH', message);
      }
      if (!verifyPassword(password, row.passwordHash)) {
        return fail(401, 'BAD_CREDENTIALS', '密码错误，请重新输入');
      }
      await store.update(row.id, { lastLoginTime: Date.now() });
      return ok(issueSession(row));
    },

    /** GET /api/auth/me（Bearer） */
    async me(token) {
      const payload = verifyToken(token, secret);
      if (!payload || payload.typ !== 'access') {
        return fail(401, 'UNAUTHORIZED', '登录状态已失效，请重新登录');
      }
      const row = await store.findById(payload.sub);
      if (!row) {
        return fail(404, 'ACCOUNT_NOT_FOUND', '账号不存在');
      }
      return ok(publicAccount(row));
    },

    /** POST /api/auth/refresh */
    async refresh(body) {
      const payload = verifyToken(String(body.refreshToken || ''), secret);
      if (!payload || payload.typ !== 'refresh') {
        return fail(401, 'UNAUTHORIZED', '登录状态已失效，请重新登录');
      }
      const row = await store.findById(payload.sub);
      if (!row) {
        return fail(404, 'ACCOUNT_NOT_FOUND', '账号不存在');
      }
      return ok(issueSession(row));
    },

    /** POST /api/auth/logout：无状态 JWT 直接丢弃，真实项目应把 jti 写入黑名单 */
    async logout(token) {
      const payload = verifyToken(token, secret);
      return ok({ loggedOut: payload !== null });
    },

    /** GET /api/health */
    async health() {
      const total = typeof store.count === 'function' ? await store.count() : 0;
      return ok({ status: 'up', service: 'abilitymatch-auth', accounts: total, time: Date.now() });
    }
  };
}

module.exports = {
  createAuthService,
  signToken,
  verifyToken,
  hashPassword,
  verifyPassword,
  normalizeAccount,
  ROLE_STUDENT,
  ROLE_COMPANY
};
