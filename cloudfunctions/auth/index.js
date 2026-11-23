'use strict';

/**
 * AGC 云函数入口（Node.js 运行时，配合 HTTP 触发器）。
 * 与 server/local.js 共用同一份 auth-core.js，接口契约完全一致，
 * 因此端上只需切换 baseUrl 即可在「本地服务」与「云端函数」之间迁移。
 *
 * 注意：auth-core.js 由 server/auth-core.js 同步而来，修改请改 server 侧后重新拷贝。
 */

const { createAuthService } = require('./auth-core');

/** 演示用内存存储：函数实例回收即丢失，正式部署请换成 Cloud DB 实现（见 server/README.md） */
class MemoryStore {
  constructor() {
    this.rows = [];
    this.seq = 0;
  }

  async findByAccount(account) {
    return this.rows.find((item) => item.account === account) || null;
  }

  async findById(id) {
    return this.rows.find((item) => item.id === Number(id)) || null;
  }

  async insert(row) {
    this.seq += 1;
    const created = Object.assign({}, row, { id: this.seq });
    this.rows.push(created);
    return created.id;
  }

  async update(id, patch) {
    const row = this.rows.find((item) => item.id === Number(id));
    if (row) {
      Object.assign(row, patch);
    }
  }

  async count() {
    return this.rows.length;
  }
}

const service = createAuthService(new MemoryStore());

function pathOf(event) {
  if (event.path) {
    return String(event.path);
  }
  if (event.rawPath) {
    return String(event.rawPath);
  }
  const url = String(event.url || event.requestURI || '/');
  return url.split('?')[0];
}

function bodyOf(event) {
  const body = event.body;
  if (typeof body === 'string') {
    if (body.length === 0) {
      return {};
    }
    try {
      return JSON.parse(body);
    } catch (e) {
      return {};
    }
  }
  if (body && typeof body === 'object') {
    return body;
  }
  return event;
}

function headerOf(event, name) {
  const headers = event.headers || {};
  const target = name.toLowerCase();
  const key = Object.keys(headers).find((item) => item.toLowerCase() === target);
  return key ? String(headers[key]) : '';
}

function bearerOf(event) {
  const header = headerOf(event, 'authorization');
  return header.startsWith('Bearer ') ? header.substring(7) : '';
}

exports.handler = async function (event) {
  const method = String(event.httpMethod || event.method || 'POST').toUpperCase();
  const pathname = pathOf(event);
  let result;

  if (method === 'GET' && pathname === '/api/health') {
    result = await service.health();
  } else if (method === 'POST' && pathname === '/api/auth/register') {
    result = await service.register(bodyOf(event));
  } else if (method === 'POST' && pathname === '/api/auth/login') {
    result = await service.login(bodyOf(event));
  } else if (method === 'GET' && pathname === '/api/auth/me') {
    result = await service.me(bearerOf(event));
  } else if (method === 'POST' && pathname === '/api/auth/refresh') {
    result = await service.refresh(bodyOf(event));
  } else if (method === 'POST' && pathname === '/api/auth/logout') {
    result = await service.logout(bearerOf(event));
  } else {
    result = { status: 404, body: { ok: false, code: 'NOT_FOUND', message: `未知接口 ${pathname}` } };
  }

  return {
    statusCode: result.status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify(result.body)
  };
};

exports.main = exports.handler;
