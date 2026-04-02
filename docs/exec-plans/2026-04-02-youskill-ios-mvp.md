# ExecPlan: YouSkill iOS MVP

**Status:** Active
**Author:** Codex
**Created:** 2026-04-02
**Last Updated:** 2026-04-02

## Purpose / Big Picture

完成 YouSkill iOS 首版的信息架构、产品规格、技术设计与实现路线，使后续开发能围绕同一份系统化文档推进。最终产出要明确产品边界、页面结构、核心数据流、GitHub 文件读取方案、翻译模型方案，以及可执行的 TODO 拆分。

## Context and Orientation

当前仓库处于文档初始化阶段，`docs/product-specs/`、`docs/design-docs/`、`docs/exec-plans/` 仅有模板文件。需求已经给出功能清单、页面说明、Stitch 项目与后端 OpenAPI 地址，但尚未沉淀为仓库内可执行文档。

本次工作涉及的关键外部事实：

- Stitch 项目：`13014460760730922080`
- 页面 screen id：
  - `home` `d79730fc231d42f48d286c66af8c562b`
  - `home-with-filter` `b33a6595352740948b7c8d90f40f6b6e`
  - `detail` `754cffbe95834219b384bd8c31b8a6b3`
  - `detial-with-catalog` `4f5b8aa12bf7439cad927f5940b8d057`
  - `settings` `e49f7d4d89984ef89cc74c2195d462a3`
  - `setting-model` `8a0d68ab60b840ddaa83840de31e6a29`
- OpenAPI：`https://api.youskill.cc/api/openapi.json`
- API key：需求中已提供测试 key

## Plan of Work

先读取仓库规范和模板，确认文档落位方式。随后核对 Stitch 页面结构与 OpenAPI 字段，保证产品规格不是抽象描述。再参考现有桌面项目 `/Users/wanggang/dev/00/you-skill/you-skill` 的 GitHub 目录与文件读取策略，总结为适用于 iOS 的技术方案。最后生成三类文档并更新 README 索引，同时补出 TODO 事项和后续实现优先级。

## Progress

- [x] 2026-04-02 读取仓库根 `AGENTS.md` 与 `docs/` 模板，确认文档结构与约束
- [x] 2026-04-02 读取 Stitch 项目与关键 screen，确认页面层级与交互元素
- [x] 2026-04-02 读取 OpenAPI，确认 `/api/skills` 鉴权方式与响应字段
- [x] 2026-04-02 参考既有 `you-skill` 项目，总结 GitHub 文件树与文件内容读取策略
- [x] 2026-04-02 产出产品规格文档
- [x] 2026-04-02 产出技术设计文档
- [x] 2026-04-02 产出执行计划文档
- [ ] 后续根据文档开始 SwiftUI 项目初始化与模块落地

## Surprises & Discoveries

- Stitch 项目内存在一套深色 editorial 风格设计系统，但用户需求明确要求 iOS 原生浅色信息架构，因此需要以需求文本优先，不能直接继承 Stitch 的视觉主题。
- `/api/skills` 的正确鉴权头是 `X-API-Key`，不是 `Authorization: Bearer`。
- Skill 列表返回中已包含 `skill_path_sha`，这个字段对 GitHub 文件树缓存非常有价值，可直接作为缓存版本戳。
- 既有 `you-skill` 项目并未通过 `git clone` 拉取远程内容，而是使用 GitHub Trees API 和 Raw URL 直接读取，这很适合移动端首版。

## Decision Log

- **Decision:** 首版采用“客户端直接读业务 API + GitHub”的 MVP 原生方案。
  **Rationale:** 当前后端接口已足够支撑列表，GitHub 直读能满足详情页文件树与文件内容需求，避免扩大范围。
  **Date/Author:** 2026-04-02 / Codex

- **Decision:** 翻译能力采用 OpenAI-compatible 接口。
  **Rationale:** 用户已明确确认，且设置项 `BASE_URL / API_KEY / Model` 与该策略天然一致。
  **Date/Author:** 2026-04-02 / Codex

- **Decision:** 收藏首版仅做本地持久化。
  **Rationale:** 用户已明确确认；该策略显著降低账号与同步复杂度。
  **Date/Author:** 2026-04-02 / Codex

- **Decision:** 首版网络层默认使用 `URLSession + async/await`。
  **Rationale:** 这是现代 iOS 标准能力，比为了“主流框架”引入额外依赖更稳。
  **Date/Author:** 2026-04-02 / Codex

## Outcomes & Retrospective

本轮工作完成了需求收敛和文档落位，已经把产品目标、页面要求、技术边界、GitHub 策略和 TODO 路线沉淀到仓库。剩余缺口主要在实现阶段：需要初始化 SwiftUI 工程结构、落地数据层、页面和缓存能力，并补充可执行的 build/test 命令。
