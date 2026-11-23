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
| 岗位匹配 | 五维加权匹配、双向匹配与匹配解释 |
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
├── docs/                           # 需求、设计、测试与论文文档
├── build-profile.json5
└── oh-package.json5
```

## 快速开始

1. 安装 DevEco Studio 5.0+，并配置 HarmonyOS NEXT SDK（详见 [环境配置与安装指南](docs/00-环境配置与安装指南.md)）。
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
- 证书检索性能：1000 条数据下关键字检索平均 17.05 ms、p95 45 ms（见 `docs/perf_cert_search.json`）

## 文档索引

- [环境配置与安装指南](docs/00-环境配置与安装指南.md)：环境要求、本机配置、依赖安装与构建验证
- [需求分析](docs/01-需求分析.md)：用户角色、功能/非功能需求、用例图、业务流程与验收对照
- [数据库设计](docs/02-数据库设计.md)：ER 图、9 张表结构、建表 SQL、Preferences 键与索引优化
- [系统架构与接口设计](docs/03-系统架构与接口设计.md)：分层架构、目录规划、页面路由、核心接口与匹配算法
- [需求实现对照与差距分析](docs/04-需求实现对照与差距分析.md)：题目要求逐条对照、实现证据与差距说明
- [系统测试报告](docs/05-系统测试报告.md)：测试环境、构建与单元测试结果、覆盖率、功能用例与缺陷清单
- [毕业设计论文大纲](docs/06-毕业设计论文大纲.md)：章节字数分配、必备图表清单、答辩 PPT 结构与提交自检
- [安装与运行说明](docs/安装与运行说明.md)、[数据库表结构说明](docs/数据库表结构说明.md)、[系统测试用例表](docs/系统测试用例表.md)

## 已知限制

- 当前为单机应用，无账号服务端与云端同步能力。
- 匹配算法基于本地五维加权模型与内置词典，未接入大模型语义匹配。
- 真机 API 12 走查与分页/匹配/首屏等性能场景仍在补测中。

## 许可说明

本项目为毕业设计作品，仅供学习与交流使用。
