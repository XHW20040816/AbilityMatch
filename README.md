# AbilityMatch · 学生能力画像与岗位匹配

基于 HarmonyOS 的学生能力画像与企业岗位需求匹配应用。采用 Stage 应用模型、ArkTS + ArkUI 声明式 UI、RDB 关系型数据库与 Preferences 本地持久化，单机轻量化运行，无需后端服务器。

> 毕业设计项目：覆盖学生能力档案、成长规划、证书归档、五维能力画像、招聘简章解析、双向岗位匹配与档案导出等完整业务闭环。

## 功能特性

### 学生端

| 模块 | 说明 |
| --- | --- |
| 角色登录 | 学生/企业双角色登录与账号管理 |
| 学生资料 | 基本信息、求职意向与能力标签维护 |
| 成长规划 | 成长模板、阶段任务与提醒 |
| 证书管理 | 拍照/相册录入、字段归档、关键字检索 |
| 能力画像 | 五维能力雷达图与得分构成拆解 |
| 岗位浏览 | 岗位列表、筛选与详情查看 |
| 岗位匹配 | 六维加权匹配 + 大模型语义增强、双向匹配与匹配解释 |
| 匹配记录 | 按学生/岗位/方向留存历史记录 |
| 数据工具 | 档案导出（CSV，含 UTF-8 BOM）、备份与恢复 |

### 企业端

| 模块 | 说明 |
| --- | --- |
| 企业维护 | 企业信息与岗位发布 |
| 候选人管理 | 候选人列表、详情与匹配排序 |
| 简章解析 | 从招聘简章文本解析岗位要求并抽取标签 |

## 技术栈

- **应用模型**：Stage 模型
- **开发语言**：ArkTS
- **UI 框架**：ArkUI 声明式 UI
- **数据持久化**：RDB（关系型数据库）+ Preferences（轻量存储）
- **网络与 AI**：`@kit.NetworkKit`（http）+ OpenAI 兼容的大模型 `chat/completions` 接口（可选增强）
- **账号服务**：AGC 云函数（Node.js）+ Cloud DB，或本地零依赖 Node 骨架；端上 HTTP + JWT（可选）
- **测试框架**：Hypium（单元测试 + UI 自动化测试）
- **构建工具**：Hvigor
- **目标环境**：DevEco Studio 5.0+ / HarmonyOS NEXT，最低兼容 `5.0.0(12)`（API 12），本机实测 SDK 为 API 26.0.1

## 目录结构

```
AbilityMatch/
├── AppScope/                       # 应用级配置与图标资源
├── entry/                          # 主模块（HAP）
│   └── src/
│       ├── main/
│       │   ├── module.json5        # Ability、页面路由、权限声明
│       │   ├── ets/
│       │   │   ├── entryability/   # 应用入口（启动时初始化 RDB/Preferences）
│       │   │   ├── pages/          # 16 个功能页面
│       │   │   ├── model/          # 实体、枚举与接口定义
│       │   │   ├── common/         # DbHelper/PrefsHelper/FileHelper/Logger 等
│       │   │   ├── repository/     # RDB 数据访问层
│       │   │   ├── service/        # 解析、抽取、匹配、导出、提醒、备份
│       │   │   ├── viewmodel/      # 共享状态（AppViewModel）
│       │   │   └── view/           # 通用 UI 组件（雷达图、评分条、卡片等）
│       │   └── resources/
│       │       ├── base/profile/main_pages.json
│       │       └── rawfile/        # 内置技能词典、成长模板、建议库
│       ├── test/ets/               # Hypium 单元测试
│       └── ohosTest/               # Hypium UI 自动化测试
├── server/                         # 账号服务本地骨架（零依赖 Node，可独立运行）
├── cloudfunctions/auth/            # AGC 云函数入口（HTTP 触发器，与 server 共用核心逻辑）
├── build-profile.json5
└── oh-package.json5
```

## 快速开始

1. 安装 DevEco Studio 5.0+，并配置 HarmonyOS NEXT SDK（最低 API 12）。
2. 使用 DevEco Studio 打开本目录：`File > Open`，选择 `AbilityMatch` 文件夹。
3. 首次打开后点击工具栏 **Sync** 同步依赖；如 hvigor 版本不一致，按提示自动修复。
4. 打开 `Device Manager` 启动模拟器或连接真机，点击 **Run** 构建并安装 HAP。

> 本仓库未包含签名证书与密钥口令。首次在本机运行前，请在 `File > Project Structure > Signing Configs` 中勾选 **Automatically generate signature** 生成本地签名配置。

## 构建与测试

```bash
# 构建 HAP
hvigorw assembleHap

# 执行单元测试
hvigorw test

# 执行 UI 自动化测试（需已连接设备或模拟器）
hvigorw --mode module -p module=entry@ohosTest test
```

当前验证结果（2026-11-22）：

- `assembleHap`：33 个任务构建成功，耗时约 39.6 s
- 单元测试：2 套件 / 9 用例全部通过，行覆盖率 40.45%
- UI 自动化测试：`Tests run: 5, Failure: 0, Pass: 5`（3 条主流程 + 2 条性能用例）
- 证书检索性能：1000 条数据下关键字检索平均 17.05 ms、p95 45 ms

## 账号服务（可选）

登录注册默认走本机账号库；开启账号服务后改为「服务端权威 + 本地镜像 + 失败降级」：

1. **服务端权威**：注册/登录请求云端接口，服务端存 scrypt 密码哈希并签发 JWT（access 2 h / refresh 30 d）。
2. **本地镜像**：登录成功后落地 `user_account` 镜像行（`password_hash=REMOTE_ONLY`），其余页面继续按本地 `linkedId` 取档案，UI 层不用改。
3. **自动降级**：网络错误、超时、5xx 时回退本机校验并记日志；服务端明确拒绝（密码错、角色不符、账号已存在）直接提示，不降级。

服务端有两份同构实现，共用 `server/auth-core.js`：

| 目录 | 用途 | 说明 |
| --- | --- | --- |
| `server/local.js` | 本地演示 | 零依赖，`node server/local.js` 启动；数据存 `server/data/accounts.json` |
| `cloudfunctions/auth/` | AGC 云函数 | HTTP 触发器，Node.js 18；存储默认内存，生产替换为 Cloud DB |

端上配置：登录后「我的 → 数据工具 → 账号服务」，填写地址（模拟器 `http://10.0.2.2:8080`，真机用局域网 IP 或 `hdc rport`）并「测试连接」。完整接口契约、错误码、AGC 部署步骤与 Cloud DB 字段映射见 [server/README.md](server/README.md)。

**边界**：本期只做账号服务化——账号、密码、角色、核验状态上云，学生/企业业务数据仍在本地 RDB。要做多设备同步，需要在此基础上补 `updated_at/version/墓碑` 字段与 `pull/push` 增量接口。

## 大模型语义匹配（可选增强）

匹配采用「本地六维加权 + 大模型语义融合」的混合架构：

1. **本地基线**（始终执行）：学历、技能、证书、经验、荣誉、方向六维达成度，由内置技能词典、分类体系与建议库计算，可离线运行。
2. **语义评估**（配置后执行）：把学生画像（学校/专业/方向/技能/证书/项目/荣誉）与岗位信息（方向/学历/技能/证书/经验/描述）组装成结构化提示词，请求兼容 OpenAI 的 `/chat/completions` 接口，要求模型返回六维语义分、综合分、评价理由、优势与差距（纯 JSON）。
3. **加权融合**：`达成度 = 规则分 × (1 - α) + 语义分 × α`，α 按维度区分——技能 45%、经验 40%、方向 35%、证书 30%、学历 20%、荣誉 20%，客观事实维度只做微调；总分仍按岗位六维权重归一化，得分明细页会展示语义分对照与融合系数。
4. **降级与成本控制**：未配置、超时（15 s）、HTTP 非 200、返回非 JSON 时自动沿用本地规则分，页面明确提示当前评分方式；列表场景只对规则分前 8 个结果调用模型，并带 10 分钟结果缓存与并发度 3 的限制。

配置方式：企业/学生登录后进入「我的 → 数据工具 → 大模型语义匹配」，填写接口地址（如 `https://api.deepseek.com/v1`）、模型名（如 `deepseek-chat`）与 API Key，打开开关后点「测试连接」即可验证；保存后下一次进入匹配页生效。

## 已知限制

- 账号已支持服务端化（AGC 云函数 / 本地 Node 骨架，见 [账号服务说明](server/README.md)），端上走 HTTP + JWT，网络异常自动降级本机账号库；但业务数据（技能、证书、岗位、匹配记录）仍存本地 RDB，尚未实现多设备增量同步。
- 匹配主链路为本地六维加权模型（内置词典 + 分类体系），大模型语义匹配是**可选增强**：需在「数据工具」页填写接口地址、模型名与 API Key 后才会启用；未配置或调用失败时自动降级为纯本地评分，离线可用不受影响。
- 大模型 API Key 仅保存在本机 Preferences 中，用于演示；正式环境应改为服务端签发临时凭证。
- 真机 API 12 走查与分页/匹配/首屏等性能场景仍在补测中。

## 许可说明

本项目仅供学习与交流使用。
