---
machine_translated: true
description: 快速参考 bd 命令速查表、技能路由表、常见问题故障排查指南以及 superpowers 和 beads 的上游版本跟踪。
---
!!! warning "机器翻译"
    本页面由 AI 自动翻译，可能存在术语或语义偏差。如有疑问，请以[英文原文](tips.md)为准。

# 技巧与窍门

## Beads 速查表

### 查找工作

| 命令 | 功能 |
|---------|------|
| `bd ready` | 未被阻塞、可立即处理的 beads |
| `bd ready --parent <epic>` | 某个 epic 中的剩余任务 |
| `bd list --status=open` | 所有开放的 beads |
| `bd query "status=open AND priority<=1"` | 复合查询——替代 `bd list` + jq（v1.0.5） |
| `bd count --by-status` | 分组计数（`--by-priority` / `--by-type`）（v1.0.5） |
| `bd show <id>` | 某个 bead 的完整详情 |
| `bd blocked` | 等待依赖项的 beads |
| `bd epic status <id>` | Epic 进度摘要 |

### 创建

| 命令 | 功能 |
|---------|------|
| `bd create "Epic: name" -t epic -p 2` | 新建优先级为 2 的 epic |
| `bd create "Task: title" -t task --parent <epic>` | 在 epic 下创建任务 |
| `bd q "quick title"` | 快速捕获 |

### 处理工作

| 命令 | 功能 |
|---------|------|
| `bd update <id> --claim` | 认领为进行中 |
| `bd close <id> --reason "..."` | 附带证据完成任务 |
| `bd dep add <child> <depends-on>` | 添加依赖关系 |
| `bd batch`（stdin 或 `-f`） | 原子多操作事务（close、dep、update） |
| `bd -C <path> <command>` | 在其他目录运行 bd，无需 cd |
| `bd ready --explain` | 显示任务为何就绪或未就绪 |
| `bd merge-slot acquire` / `release` | 跨并发编排器串行化合并（v1.0.5） |

### 记忆

| 命令 | 功能 |
|---------|------|
| `bd remember "insight"` | 跨会话持久化一条学习内容 |
| `bd forget <id>` | 删除过时的记忆 |
| `bd memories <keyword>` | 搜索学习内容 |

### 同步

| 命令 | 功能 |
|---------|------|
| `bd dolt push` / `pull` | 将 beads 数据库同步到/从 Dolt 远程 |
| `bd github push` / `pull` | 将 beads 同步到/从 GitHub Issues |

### 日常维护

| 命令 | 功能 |
|---------|------|
| `bd stats` | 开放/已关闭/被阻塞的计数 |
| `bd doctor` | 诊断配置问题 |
| `bd lint [id...]` | 检查 issues 是否缺少必填章节 |
| `bd note <id> "context"` | 向 bead 追加证据 |
| `bd stale` | 近期无活动的 beads |
| `bd find-duplicates` | 语义相似的 beads |
| `bd defer <id> --until="..."` | 将工作推迟到未来某个日期 |
| `bd human <id>` | 将 issue 标记为需要人工决策 |
| `bd swarm validate <epic>` | 分析并行工作图 |

**Land the Plane：** 每次会话结束时执行 `bd close` → `bd dolt push` → `git push`。`finishing-a-development-branch` 技能负责强制执行此流程。

## 技能路由

| 我需要… | 调用 |
|---|---|
| 会话开始时定向 | `getting-up-to-speed` |
| 编码前先设计 | `brainstorming` |
| 对设计进行压力测试 | `stress-test` |
| 编写任务计划 | `writing-plans` |
| 按任务执行并逐任务审查 | `subagent-driven-development` |
| 在单次会话中执行计划 | `executing-plans` |
| 编写功能或修复 bug | `test-driven-development` |
| 调试失败问题 | `systematic-debugging` |
| 声明工作已完成 | `verification-before-completion` |
| 获取代码审查 | `requesting-code-review` |
| 回应审查反馈 | `receiving-code-review` |
| 合并或关闭分支 | `finishing-a-development-branch` |
| 并行运行独立任务 | `dispatching-parallel-agents` |
| 创建或修改技能 | `writing-skills` |
| 发布后更新文档 | `document-release` |
| 研究某个主题 | `research-driven-development` |
| 编写面向用户的文档 | `write-documentation` |

`using-superpowers` 引导技能（会话开始时自动加载）包含完整的路由逻辑；如有疑问，请让 Claude Code 读取它。

## 常见问题

安装和配置问题，请参阅[入门指南——故障排查](getting-started.md)。以下是最常见问题的快速解决方法：

**技能未加载** — `/plugins` 应列出 beads-superpowers，`/skills` 应显示 {{ skill_count }} 个技能。若未显示，请重新安装。

**`bd: command not found`** — 运行 `brew install beads` 或 `npm install -g @beads/bd`。

**双重 `bd prime`** — 插件会自动检测 `bd setup claude` hooks，并跳过自身的 `bd prime` 调用。若仍出现重复，请运行 `bd setup claude --remove`。

**`bd dolt push` 失败** — 未配置 Dolt 远程。如果不需要远程同步，此错误无害。

## Windows

SessionStart hook（`hooks/session-start`）是 bash 脚本。在 Windows 上，多格式包装器 `hooks/run-hook.cmd` 通过 Git Bash 调用它。该 `.cmd` 文件同时是有效的批处理文件和 bash 脚本——在 Windows 上，`cmd.exe` 找到 Git Bash 并重新执行；在 Unix 上，`:` 命令是空操作，bash 运行其余部分。只要安装了 Git for Windows，无需 WSL 即可正常工作。

技能是纯 Markdown，不含任何平台特定代码。只有 hook 包装器处理平台差异。

## 上游跟踪

| 来源 | 基准版本 | 跟踪内容 |
|--------|----------|----------|
| [obra/superpowers](https://github.com/obra/superpowers) | v6.0.3 | 技能内容、新技能、hooks |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.0.5 | CLI 命令、`bd prime` 格式 |

在发布前或长时间间隔后，运行 `auditing-upstream-drift` 检查需要移植的变更。
