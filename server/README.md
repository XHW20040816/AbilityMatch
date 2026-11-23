# 账号服务（AGC 云函数 / 本地 Node 骨架）

把「账号与登录」从端上本地库迁到服务端，端上改为 HTTP + JWT，网络不可达时自动降级为本机账号库。

- `server/auth-core.js`：与传输层无关的账号核心逻辑（注册、登录、me、refresh、logout、health），本地服务与 AGC 云函数共用。
- `server/local.js`：本地演示服务，零依赖，数据落 `server/data/accounts.json`。
- `cloudfunctions/auth/`：AGC 云函数入口（HTTP 触发器），`auth-core.js` 由 server 侧同步而来。

## 启动本地服务

```bash
node server/local.js          # 默认 8080
PORT=9090 node server/local.js
```

健康检查：`GET http://127.0.0.1:8080/api/health`

## 端上如何连

企业/学生登录后进入「我的 → 数据工具 → 账号服务」：

| 场景 | 地址 |
| --- | --- |
| 模拟器访问宿主机 | `http://10.0.2.2:8080` |
| 真机同局域网 | `http://<PC 局域网 IP>:8080` |
| 真机 + USB 端口转发 | 先 `hdc rport tcp:8080 tcp:8080`，再填 `http://127.0.0.1:8080` |

填好后点「测试连接」，看到 `连接成功：{"ok":true,...}` 即通。开关关闭时完全走本机账号库，行为与改造前一致。

> 明文 HTTP 仅用于本地演示；接入 AGC 时请使用 HTTPS 域名。

## API 契约

统一响应信封：

成功：

```json
{ "ok": true, "data": { } }
```

失败：

```json
{ "ok": false, "code": "BAD_CREDENTIALS", "message": "密码错误，请重新输入" }
```

### POST /api/auth/register

```json
{ "role": "STUDENT", "account": "s9001", "password": "pass1234", "displayName": "张三" }
```

`role` 取 `STUDENT` / `COMPANY`；`account` 4~64 字符（服务端统一转小写比对）；`password` 6~64 字符。

成功 200：

```json
{ "ok": true, "data": {
  "token": "<JWT>", "refreshToken": "<JWT>", "expiresIn": 7200,
  "account": { "id": 1, "role": "STUDENT", "account": "s9001",
               "displayName": "张三", "verifyStatus": "PENDING" }
} }
```

### POST /api/auth/login

```json
{ "role": "STUDENT", "account": "s9001", "password": "pass1234" }
```

成功返回同注册。

### GET /api/auth/me

请求头 `Authorization: Bearer <token>`，返回 `{ "ok": true, "data": { "id", "role", "account", "displayName", "verifyStatus" } }`。

### POST /api/auth/refresh

```json
{ "refreshToken": "<refreshToken>" }
```

返回新的 `token` / `refreshToken`。端上在 accessToken 到期前 60 秒自动调用。

### POST /api/auth/logout

请求头带 Bearer，返回 `{ "ok": true, "data": { "loggedOut": true } }`。JWT 无状态，服务端不保存会话；生产环境可把 jti 写入黑名单。

### GET /api/health

返回 `{ "ok": true, "data": { "status": "up", "service": "abilitymatch-auth", "accounts": 3 } }`。

## 错误码

| HTTP | code | 含义 | 端上处理 |
| --- | --- | --- | --- |
| 400 | INVALID_INPUT | 账号/密码长度或角色不合法 | 直接提示，不降级 |
| 401 | BAD_CREDENTIALS | 密码错误 | 直接提示 |
| 401 | UNAUTHORIZED | token 无效或过期 | 清 token，重新登录 |
| 403 | ROLE_MISMATCH | 角色选错 | 提示切换学生端/企业端 |
| 404 | ACCOUNT_NOT_FOUND | 账号不存在 | 提示先注册 |
| 409 | ACCOUNT_TAKEN | 账号已被注册 | 提示直接登录 |
| 5xx / 网络异常 | — | 服务不可用 | **降级本地账号库** |

端上判定依据：`AuthApiError.transport`。`transport=false` 表示服务端明确拒绝，直接抛给 UI；`transport=true` 表示网络/超时/5xx，`AuthService` 自动回退本地校验，并打日志。

## 与端上的数据关系

- 服务端是**账号目录**（账号、密码哈希、角色、核验状态）的权威源。
- 端上本地 `user_account` 表保留**镜像账号**：云端登录成功后会落地一行，`password_hash` 置为 `REMOTE_ONLY`，表示该账号本机不可离线校验密码。
- 学生/企业档案（技能、证书、岗位等）仍在本地 RDB，本期不做数据上云。
- 云端账号首次在本机登录时，会按账号匹配已有档案（`student_info.phone/email`、`company_info.contact_phone`），匹配不到则建占位档案并写入 `CLOUD-<account>` 学号。

## 部署到 AGC

1. AGC 控制台创建云函数 `auth`，运行时选 **Node.js 18**，入口 `index.handler`。
2. 上传 `cloudfunctions/auth/` 整个目录（`auth-core.js` 必须一起上传）。
3. 为函数配置 **HTTP 触发器**，路径前缀建议 `/api`，即 `POST <触发器域名>/api/auth/login`。
4. 环境变量配置 `AUTH_JWT_SECRET=<足够长的随机串>`；不配置会使用代码内默认值，仅可用于演示。
5. 端上「账号服务」填写触发器的 HTTPS 域名，点「测试连接」。

修改 `server/auth-core.js` 后需同步到云函数目录：

```powershell
Copy-Item server\auth-core.js cloudfunctions\auth\auth-core.js -Force
```

### 把内存存储换成 Cloud DB

`cloudfunctions/auth/index.js` 里的 `MemoryStore` 仅保证函数实例存活期内有效。替换步骤：

1. 在 AGC 控制台创建 Cloud DB 对象类型 `UserAccount`，字段：`role`(string)、`account`(string，唯一索引)、`passwordHash`(string)、`displayName`(string)、`verifyStatus`(string)、`createTime`(long)、`updateTime`(long)、`lastLoginTime`(long)。
2. 在云函数内用 AGC Server SDK 连到该对象类型，实现 `findByAccount / findById / insert / update / count` 五个方法。
3. 用实现替换 `new MemoryStore()`，其余代码无需改动。

## 安全说明

- 密码使用 `scrypt` + 16 字节随机盐存储，比对用 `timingSafeEqual`。
- JWT 为 HS256，access 2 小时、refresh 30 天；生产建议改为 RSA 或 EdDSA，并加黑名单与限流。
- 演示服务内存/JSON 存储不做并发控制；`server/data/accounts.json` 不要提交到公开仓库。
- 生产环境必须 HTTPS，且 JWT 密钥通过环境变量注入，不写死在代码里。
