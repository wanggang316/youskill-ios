# Design Doc: YouSkill iOS MVP

**Status:** Draft
**Author:** Codex
**Date:** 2026-04-02

## Problem Statement

现有 Agent Skill 主要以 GitHub 仓库或桌面端工具形式被消费，在手机上浏览体验较差。用户需要一个针对 iPhone 阅读场景优化的产品，能够快速发现 Skill、阅读 `SKILL.md` 与关联文件，并在需要时将 Markdown 文档翻译成目标语言。

## Goals

- 提供适配 iPhone 的 Skill 浏览与阅读体验。
- 提供最小但完整的 Skill 发现闭环：列表、搜索、排序、本地收藏。
- 提供最小但完整的 Skill 阅读闭环：默认文档、目录抽屉、文件切换、Markdown/代码展示。
- 提供面向用户自定义模型的 OpenAI-compatible 翻译能力。
- 将产品需求、技术方案、TODO 清单明确落位到仓库文档。

## Non-Goals

- 首版不做账号体系与云同步。
- 首版不做 Skill 安装、下载、执行。
- 首版不做评论、评分、社交关系。
- 首版不做离线优先架构。
- 首版不建设新的后端聚合服务。

## Proposed Solution

### 1. 产品范围与信息架构

首版包含 4 个核心体验单元：

- `首页`：Skill 列表、搜索、排序/筛选、本地收藏入口。
- `详情页`：展示 Skill 标题、翻译按钮、目录按钮、正文内容。
- `目录抽屉`：展示当前 Skill 的完整文件树，点击切换文件。
- `设置`：翻译模型设置、目标语言、GitHub、版本信息。

页面关系如下：

- 首页通过 `NavigationStack` 进入详情页。
- 设置页通过 `sheet` 打开。
- 排序/筛选通过底部 `confirmation dialog` 或自定义 action sheet 呈现。
- 目录通过右侧抽屉式 overlay 呈现，符合需求中的“右侧出现抽屉视图”。

### 2. 视觉与交互原则

虽然 Stitch 项目存在深色 editorial 风格设计，但本需求明确要求“iOS 原生风格 + 深蓝主色调 + 简洁”。因此首版采用以下取舍：

- 视觉方向以 `iOS 原生导航、分组列表、卡片、sheet、drawer` 为主。
- 主品牌色使用深蓝色，主要用于导航强调、主按钮、选中态、检测成功态。
- 大面积背景保持浅色中性底，保证阅读舒适度。
- 不引入桌面化边栏、复杂说明文案或强装饰性布局。
- Stitch 设计稿作为页面结构和内容密度参考，不直接继承其深色设计系统。

### 3. 客户端架构

项目遵循仓库既定分层：

`Types -> Config -> Repo -> Service -> Runtime -> UI`

建议按以下业务域组织：

- `SkillCatalog`
  - 列表读取、搜索、排序、收藏过滤
- `SkillContent`
  - GitHub 文件树、文件内容、Markdown/代码展示
- `Translation`
  - 翻译配置、可用性检测、翻译请求、翻译缓存
- `Settings`
  - 目标语言、版本、GitHub 入口、偏好项持久化

### 4. 数据源设计

#### 4.1 Skill 列表

服务端接口：

- `GET /api/skills`
- 鉴权方式：请求头 `X-API-Key`

已确认可用字段：

- `id`
- `name`
- `description`
- `url`
- `path`
- `branch`
- `star_count`
- `install_count`
- `source`
- `skill_path_sha`
- `tags`

首版列表策略：

- 默认请求 `sort_by=star_count&sort_order=desc`
- 菜单项切换：
  - `安装最多` -> `sort_by=install_count`
  - `Star 最多` -> `sort_by=star_count`
  - `我的收藏` -> 本地过滤，不请求远程排序
- 搜索框使用 `search` 参数透传后端
- 分页首版先支持基础分页加载，优先实现首屏和下拉刷新

#### 4.2 GitHub 文件树与文件内容

本项需要参考已有项目 `/Users/wanggang/dev/00/you-skill/you-skill`。现有实现已经验证了移动端所需的两个关键动作：

- 读取文件树：`GET https://api.github.com/repos/{owner}/{repo}/git/trees/{branch}?recursive=1`
- 读取文件内容：`GET https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{fullPath}`

总结后的 iOS 策略如下：

1. 从 Skill 元数据中的 `url + path + branch` 解析 GitHub 仓库位置。
2. 使用 Git Trees API 一次性获取仓库文件树。
3. 按 `path` 作为 skill 根目录裁剪，只保留当前 skill 目录内的文件。
4. 基于文件路径推导目录节点，生成本地文件树模型。
5. 默认优先打开 `SKILL.md`，若不存在则打开首个文件。
6. 文件内容使用 `raw.githubusercontent.com` 直接读取文本。

这个方案的优点：

- 不需要 `git clone`
- 不依赖服务端新增代理能力
- 与已有桌面项目读取逻辑一致，便于复用经验

需要补充的移动端约束：

- 使用 `skill_path_sha` 作为文件树缓存版本号，避免每次进入详情都请求 GitHub Tree API。
- 文件内容缓存按 `skill_id + branch + relative_path + skill_path_sha` 建 key。
- 对大文件、二进制文件、图片文件需要做展示降级或拒绝展示。

#### 4.3 本地收藏

收藏仅做本地持久化：

- 数据结构：`skill_id + name + url + path + branch + source + counts + timestamp`
- 持久化位置：首版建议 `SwiftData` 或 `UserDefaults + Codable`
- 推荐：收藏和设置使用 `SwiftData`，便于后续扩展；若首版追求最小实现，也可先使用 `UserDefaults`

#### 4.4 翻译

翻译能力采用 `OpenAI-compatible` 接口，设置项包括：

- `baseURL`
- `apiKey`
- `model`
- `targetLanguage`

翻译范围：

- 仅 Markdown 文件支持翻译按钮
- 支持 `md`、`markdown`、`mdx` 等 Markdown 扩展名

翻译流程：

1. 用户点击“翻译”
2. 校验设置是否完整
3. 若缺失配置，跳转或弹出设置引导
4. 若已有缓存结果，直接显示
5. 否则发起翻译请求，成功后缓存
6. 再次点击“翻译”时切回原文

缓存 key 建议：

- `skill_id`
- `relative_path`
- `target_language`
- `model`
- `original_content_hash`

### 5. 页面设计细化

#### 5.1 首页

导航栏：

- 左：菜单按钮
- 中：`YouSkill`
- 右：设置按钮

内容区：

- 顶部搜索框
- Skill 卡片列表

卡片结构：

- 第一行：`skill-name(@source-or-author)` + 收藏 icon
- 第二行：安装数、Star 数

交互：

- 点击卡片进入详情页
- 点击收藏 icon 切换收藏状态
- 点击菜单按钮弹出：
  - 安装最多
  - Star 最多
  - 我的收藏

#### 5.2 详情页

导航栏：

- 中：Skill 标题
- 右：翻译按钮、目录按钮

内容区：

- 默认打开 `SKILL.md`
- Markdown 文件用阅读视图展示
- 代码文件使用等宽字体展示，后续可升级为高亮
- 若内容加载失败，显示轻量错误态与重试

#### 5.3 目录抽屉

- 由右侧滑入
- 展示完整文件树
- 文件夹可折叠
- 点击文件后切换主体内容并关闭抽屉
- 当前选中文件高亮

#### 5.4 设置页

分组：

- `模型设置`
  - 翻译模型
  - 目标语言
- `关于`
  - GitHub
  - 版本

模型设置二级页字段：

- `BASE_URL`
- `API_KEY`
- `Model`
- `检测`按钮

检测结果需要有明确状态：

- 成功：绿色或品牌色正反馈
- 失败：错误文案 + 保留原输入

### 6. 技术选型

建议技术栈如下：

- 语言：`Swift`
- UI：`SwiftUI`
- 状态管理：`Observation` + `@Observable`
- 并发：`async/await`
- 导航：`NavigationStack`
- 网络：`URLSession`
- Markdown 渲染：首选 `MarkdownUI`
- 图片：`AsyncImage`
- 持久化：
  - 首选 `SwiftData` 处理收藏与设置
  - 若实现成本受限，可退化为 `UserDefaults + Codable`

关于“网络请求使用社区主流框架 TODO”的结论：

- 首版不建议为了“主流框架”而引入 `Alamofire` 或 `Moya`
- `URLSession + async/await` 已经是 iOS 现代标准实现，复杂度更低、依赖更少
- 如果后续 API target、插件式拦截器、Mock 需求变重，再评估 `Moya`

### 7. 错误处理

- 列表加载失败：展示可重试空态
- GitHub 文件树失败：展示目录错误态，允许重试
- 文件内容失败：在正文区域提示失败
- 翻译失败：保留原文并提示失败原因
- 模型检测失败：在设置页内展示可读错误，不打断已有配置

### 8. 缓存策略

- Skill 列表：内存缓存，必要时做短期磁盘缓存
- 文件树：按 `skill_id + skill_path_sha` 缓存
- 文件内容：按 `skill_id + relative_path + skill_path_sha` 缓存
- 翻译结果：按 `content_hash + target_language + model` 缓存

### 9. 风险与缓解

- `GitHub API rate limit`
  - 风险：Git Trees API 未鉴权访问存在速率限制
  - 缓解：文件树按 `skill_path_sha` 做本地缓存，减少重复请求
- `原始文件内容编码不一致`
  - 风险：部分仓库文件可能非 UTF-8
  - 缓解：首版仅保证 UTF-8 文本，异常文件走不可预览提示
- `翻译模型兼容性不一致`
  - 风险：不同 OpenAI-compatible 服务商响应格式和能力存在差异
  - 缓解：模型检测页先做连通性校验，并在请求层统一 schema 映射
- `代码文件显示体验不足`
  - 风险：首版若不做高亮，代码可读性一般
  - 缓解：MVP 允许等宽字体展示，把语法高亮列为后续增强项

## Alternatives Considered

### 方案 A：MVP 原生方案

客户端直接请求业务 API 与 GitHub，最少依赖，最贴合首版目标。该方案被采用。

### 方案 B：重缓存方案

更适合离线和弱网，但首版复杂度显著上升，需要处理缓存一致性与失效策略，暂不采用。

### 方案 C：服务端聚合方案

可降低客户端复杂度，但当前后端未提供聚合接口，会把范围扩展到服务端，暂不采用。

## Dependencies

- `api.youskill.cc` Skill 列表接口
- GitHub Trees API
- `raw.githubusercontent.com` 文件内容服务
- OpenAI-compatible 翻译服务
- iOS 17+ 运行环境假设（若采用 SwiftData / Observation）

## Risks

- GitHub 访问速率限制可能影响首次详情页加载。
- 第三方模型配置错误会导致翻译体验不稳定。
- 若后续需要兼容 iOS 16，则 `SwiftData` 和部分 Observation API 需要降级替代。

## References

- [YouSkill iOS MVP Product Spec](../product-specs/youskill-ios-mvp.md)
- [YouSkill iOS MVP ExecPlan](../exec-plans/2026-04-02-youskill-ios-mvp.md)
- [Architecture](../architecture.md)
- [Golden Rules](../golden-rules.md)
- `https://api.youskill.cc/api/openapi.json`
- `/Users/wanggang/dev/00/you-skill/you-skill/src/routes/skills/[type]/[name]/+page.svelte`
- `/Users/wanggang/dev/00/you-skill/you-skill/src-tauri/src/utils/github.rs`
