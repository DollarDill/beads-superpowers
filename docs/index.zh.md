---
machine_translated: true
description: 可组合技能为 AI 智能体强制执行 TDD、调试与代码审查；基于 Dolt 的任务记忆在会话间保持上下文。已在 Claude Code、Codex 和 OpenCode 上验证；在 Cursor、GitHub Copilot CLI、Kimi Code、Antigravity、Factory Droid 和 Pi 上为尽力支持。
---
!!! warning "机器翻译"
    本页面由 AI 自动翻译，可能存在术语或语义偏差。如有疑问，请以[英文原文](index.md)为准。

# beads-superpowers

一个面向 AI 编码智能体的插件，内置 **{{ skill_count }}** 个技能，强制执行开发规范——TDD、系统性调试、先设计后编码、代码审查——以及一个跨会话持久保存上下文的任务追踪器。

技能来自 Jesse Vincent 的 [Superpowers](https://github.com/obra/superpowers)；追踪器来自 Steve Yegge 的 [Beads](https://github.com/gastownhall/beads)。本插件将二者整合，使技能在运行时自动创建和关闭议题，追踪器则在每个新会话开始时回注上下文。

**已验证**支持 Claude Code、Codex CLI 和 OpenCode。**尽力支持** Cursor、GitHub Copilot CLI、Kimi Code、Antigravity、Factory Droid 和 Pi 的原生集成。各平台安装路径请参阅[快速入门](getting-started.md)。

!!! info "初次接触 Beads？"
    上游 [Beads 文档](https://gastownhall.github.io/beads/) 深入介绍了该工具本身——概念、CLI 参考、恢复指南。本站点记录的是构建于其上的合并工作流。

**当前版本：** v{{ version }} · {{ skill_count }} 个技能

## 从哪里开始

**[快速入门](getting-started.md)**：如需安装和配置插件。

**[方法论](methodology.md)**：如需在安装前了解开发生命周期。

**[技能参考](skills.md)**：如已安装插件，想了解各技能的用途。

**[示例工作流](workflow.md)**：如需一个现成的编排智能体将一切串联起来。

**[技巧与窍门](tips.md)**：速查表与常见问题。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

然后在任意项目中执行：`bd init`。在 Claude Code 中运行 `/skills` 以确认安装。
