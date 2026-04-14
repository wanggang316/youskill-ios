# Product Spec: YouSkill iOS MVP

**Status:** Draft
**Author:** Codex
**Date:** 2026-04-02

## Summary

YouSkill iOS 是一个面向移动端的 Agent Skill 浏览与阅读应用。产品聚焦三件事：高效发现 Skill、在手机上舒适阅读 Skill 内容、对 Markdown 文档进行一键翻译。首版采用 SwiftUI 原生交互，围绕列表、详情、目录切换、翻译、设置、本地收藏构建最小可用闭环。

## User Stories

- As a mobile user, I want to browse popular skills on my phone so that I can quickly discover useful agent workflows.
- As a learner, I want to open a skill and read its `SKILL.md` and related files so that I can understand the complete skill implementation.
- As a non-native reader, I want to translate Markdown files into my target language so that I can read community skills more efficiently.
- As a returning user, I want to bookmark interesting skills locally so that I can revisit them later.
- As a power user, I want to configure my own Chat Completion API translation endpoint so that I can control cost, region, and model quality.

## Requirements

### Must Have
- [ ] 首页展示 Skill 卡片列表。
- [ ] 首页支持搜索。
- [ ] 首页支持排序/筛选：`install_count`、`star_count`、`我的收藏`。
- [ ] 首页左上角菜单按钮使用 iOS 风格底部弹出菜单。
- [ ] 首页右上角设置按钮以 `sheet` 方式打开设置页。
- [ ] Skill 详情页默认展示 `SKILL.md`。
- [ ] 详情页支持展示 Skill 文件树，并支持切换任意文件。
- [ ] Markdown 文件支持一键翻译。
- [ ] 翻译设置支持 `BASE_URL / API_KEY / Model / Target Language`。
- [ ] 模型设置页支持“检测”动作，并能给出成功/失败状态反馈。
- [ ] 收藏数据保存在本地设备，不依赖账号系统。
- [ ] 设置页包含 GitHub 入口与版本信息。

### Nice to Have
- [ ] 首页支持下拉刷新。
- [ ] 详情页记住上次打开的文件。
- [ ] 文件内容与翻译结果做本地缓存。
- [ ] 代码文件提供基础语法高亮。
- [ ] 详情页支持复制文件内容或分享链接。

## Acceptance Criteria

- 用户首次打开应用后，可看到 Skill 列表，并能通过搜索词过滤结果。
- 用户点击左上角菜单后，可在 `安装最多`、`Star 最多`、`我的收藏` 之间切换，列表同步刷新。
- 列表卡片至少展示：名称、作者/来源、安装数、Star 数、收藏状态。
- 用户打开 Skill 后，默认看到 `SKILL.md` 内容；若无 `SKILL.md`，自动展示首个可读文件。
- 用户点击“目录”后，可看到当前 Skill 的文件树；点击任意文件后，主体内容切换且目录关闭。
- 当当前文件为 Markdown 时，用户点击“翻译”可切换为翻译结果；再次点击可恢复原文。
- 当翻译配置缺失时，点击“翻译”会引导用户前往设置补全配置。
- 用户在模型设置页点击“检测”后，可明确知道配置是否可用。
- 用户收藏某 Skill 后，在重新启动应用后仍能在“我的收藏”中看到它。
- UI 采用 iOS 手机信息架构和交互范式，不使用桌面式布局。

## Design

- 设计文档：[YouSkill iOS MVP Design](../design-docs/youskill-ios-mvp.md)
- 执行计划：[YouSkill iOS MVP ExecPlan](../exec-plans/2026-04-02-youskill-ios-mvp.md)

## Open Questions

- 首版代码文件是否必须提供完整语法高亮，还是允许先提供等宽字体阅读。
- 是否需要在详情页提供“打开 GitHub 原仓库”快速入口。
- 是否需要在首页直接暴露标签筛选，还是仅保留搜索与排序。
