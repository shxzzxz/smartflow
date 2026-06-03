# CLAUDE.md

## 项目概述

SmartFlow 是一款基于**复式记账法**的个人财务管理系统

## 核心文档

- `docs/01. 项目概述.md` - 项目概览与快速参考
- `CONTEXT.md` - 项目领域语言与术语表
- `docs/02. 核心功能.md` - 核心模块与功能说明
- `docs/domains/ledger/` - 账务核心领域文档
- `docs/domains/credit/` - 信贷领域文档
- `docs/domains/budget/` - 预算领域文档
- `docs/05. 设计系统.md` - 设计系统、视觉语义与组件分层规则
- `docs/06. 工程架构与实现规范.md` - 工程架构、实现规范与工程治理子文档索引
- `docs/adr/` - 跨模块边界与长期演进方向的架构决策记录

## MCP

当需要查询库/API 文档、生成代码、执行安装步骤或处理配置时，应默认使用 Context7 MCP，无需用户额外明确要求。

## 质量规则

- 优先复用现有组件、工具函数、标准库和已选型依赖；新增依赖或自研前先确认现有方案不足。
- 优先选择满足需求的最小方案；只为已知且高概率的变化做轻量预留，避免为假设需求过度设计或过早抽象。
- 实现前先查阅现有文档、设计系统和相邻模块，保持命名、结构与交互一致。
- 需求、约束或影响范围不明确时，先澄清再实施，不要基于猜测直接修改。

## 构建工具

- 使用 FVM 管理 Flutter 版本，所有 Flutter 命令必须通过 `fvm flutter <command>` 执行，同时通过 `fvm dart <command>` 调用 Flutter 自带的 Dart SDK

## 补充规则

- 坚决禁止使用数据库外键约束

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md`.
