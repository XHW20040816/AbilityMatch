'use strict';

/**
 * 本地账号服务：零依赖，直接 `node server/local.js` 即可启动，用于课程答辩演示。
 * 数据落在 server/data/accounts.json，删除该文件即清空。
 *
 * 与 AGC 云函数（cloudfunctions/auth）共用 server/auth-core.js，接口完全一致。
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { createAuthService } = require('./auth-core');

const PORT = Number(process.env.PORT || 8080);
const DATA_FILE = path.join(__dirname, 'data', 'accounts.json');

class JsonFileStore {
  constructor(file) {
    this.file = file;
    this.rows = [];
    this.seq = 0;
    this.load();
  }

  load() {
    try {
      const raw = fs.readFileSync(this.file, 'utf8');
      const parsed = JSON.parse(raw);
      this.rows = Array.isArray(parsed.rows) ? parsed.rows : [];
      this.seq = Number(parsed.seq || this.rows.length);
    } catch (e) {
      this.rows = [];
      this.seq = 0;
    }
  }

  persist() {
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify({ seq: this.seq, rows: this.rows }, null, 2), 'utf8');
    fs.renameSync(tmp, this.file);
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
    this.persist();
    return created.id;
  }

  async update(id, patch) {
    const row = this.rows.find((item) => item.id === Number(id));
    if (row) {
      Object.assign(row, patch);
      this.persist();
    }
  }

  async count() {
    return this.rows.length;
  }
}

const store = new JsonFileStore(DATA_FILE);
const service = createAuthService(store);

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8');
      if (!text) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(text));
      } catch (e) {
        resolve({});
      }
    });
  });
}

function bearer(req) {
  const header = String(req.headers.authorization || '');
  return header.startsWith('Bearer ') ? header.substring(7) : '';
}

async function route(req, method, pathname, body) {
  if (method === 'GET' && pathname === '/api/health') {
    return service.health();
  }
  if (method === 'POST' && pathname === '/api/auth/register') {
    return service.register(body);
  }
  if (method === 'POST' && pathname === '/api/auth/login') {
    return service.login(body);
  }
  if (method === 'GET' && pathname === '/api/auth/me') {
    return service.me(bearer(req));
  }
  if (method === 'POST' && pathname === '/api/auth/refresh') {
    return service.refresh(body);
  }
  if (method === 'POST' && pathname === '/api/auth/logout') {
    return service.logout(bearer(req));
  }
  return { status: 404, body: { ok: false, code: 'NOT_FOUND', message: `未知接口 ${pathname}` } };
}

const server = http.createServer(async (req, res) => {
  const method = (req.method || 'GET').toUpperCase();
  const pathname = (req.url || '/').split('?')[0];
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  try {
    const body = method === 'POST' ? await readBody(req) : {};
    const result = await route(req, method, pathname, body);
    res.writeHead(result.status);
    res.end(JSON.stringify(result.body));
    console.log(`${new Date().toISOString()} ${method} ${pathname} -> ${result.status}`);
  } catch (error) {
    res.writeHead(500);
    res.end(JSON.stringify({ ok: false, code: 'SERVER_ERROR', message: String(error && error.message || error) }));
    console.error(`${method} ${pathname} 处理失败`, error);
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`AbilityMatch 账号服务已启动：http://127.0.0.1:${PORT}`);
  console.log(`健康检查：http://127.0.0.1:${PORT}/api/health`);
  console.log('模拟器请用 http://10.0.2.2:8080，真机请用本机局域网 IP');
});
