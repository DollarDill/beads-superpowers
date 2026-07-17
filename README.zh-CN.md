<p align="center"><a href="README.md">English</a> · <strong>中文</strong></p>

<p align="center"><em>⚠️ 本文档由 AI 机器翻译，可能存在术语或语义偏差。如有疑问，请以<a href="README.md">英文原文</a>为准。</em></p>

<p align="center">
  <img src="assets/banner.svg" alt="beads-superpowers - Process discipline and persistent memory for AI coding agents" width="100%" />
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/DollarDill/beads-superpowers?color=4f46e5"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/DollarDill/beads-superpowers?style=social"></a>
  <a href="CONTRIBUTING.md"><img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg"></a>
  <a href="https://algocents.com/beads-superpowers/"><img alt="Docs" src="https://img.shields.io/badge/docs-algocents.com-0ea5e9.svg"></a>
</p>

---

一款适用于 Claude Code、Codex、OpenCode 及另外 6 款 AI 编程智能体的插件，让你的智能体在编写代码前先写测试、有条不紊地调试而非盲目猜测，并记住昨天做了什么。可组合技能强制执行这些实践；基于 Dolt 的问题追踪器在会话间保持上下文。

## 快速开始

最快路径——Claude Code 原生插件安装：

```bash
brew install beads                    # 1. Install bd (requires beads v1.1.0+)
# From your shell:
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
# Or, inside a Claude Code session:
# /plugin marketplace add DollarDill/beads-superpowers
# /plugin install beads-superpowers@beads-superpowers-marketplace
# Then in your project directory:
bd init                               # 2. Bootstrap the Dolt database for this project
```

开启新的 Claude Code 会话，输入 "where are we"——智能体将加载你的 `bd` 上下文，从上次中断处继续。

使用其他智能体？跳转至 [Codex CLI](#codex-cli)、[OpenCode](#opencode)、[Cursor](#cursor)、[GitHub Copilot CLI](#github-copilot-cli)、[Kimi Code](#kimi-code)、[Antigravity](#antigravity)、[Factory Droid](#factory-droid) 或 [Pi](#pi) 的安装说明。

## 基本工作流

1. **brainstorming** — 在任何代码编写前启动。通过一次一个问题的设计对话打磨想法，检查知识库中先前的决策，并以你批准的规格说明收尾——记录在 `bd` 中，从而在会话之间留存。

2. **using-git-worktrees** — 在设计获批后启动。在全新分支上创建一个隔离的 worktree，确保实现工作不会触碰你的主工作区。

3. **writing-plans** — 将获批的规格说明转化为带有确切文件、代码和验证步骤的小任务。每项任务都成为一个 `bd` bead。

4. **subagent-driven-development** 或 **executing-plans** — 为每项任务派遣全新子智能体，在任务之间进行规格与质量审查；或分批执行并设置人工检查点。

5. **test-driven-development** — 强制执行 RED-GREEN-REFACTOR：先写失败的测试，写最少的代码使其通过，再重构。没有失败的测试就不写实现代码。

6. **requesting-code-review** — 在集成前对照计划审查工作成果。严重问题会阻塞进度。

7. **finishing-a-development-branch** — 验证测试、审计文档、给出合并/PR 选项，并执行 Land the Plane：关闭 beads、同步、推送。

智能体会在执行任何任务前检查相关技能——这些是强制性工作流，而非建议。并且因为每项任务、决策和经验都保存在 `bd` 的 Dolt 数据库中，下一次会话会从上一次结束的地方开始：输入 "where are we"，智能体就会接续之前的工作。

## 功能概览

<!-- 收录规则：基本工作流中提及的每一项技能都会出现在此处；beads 差异化技能同样收录；条目上限约 14-15 条。完整参考位于文档站点——不要让本表格重新膨胀为详尽清单。 -->

### 测试

| 技能 | 作用 |
|------|------|
| `test-driven-development` | RED-GREEN-REFACTOR 循环——铁律：没有失败的测试就不写实现代码 |

### 调试

| 技能 | 作用 |
|------|------|
| `systematic-debugging` | 在提出任何修复方案前进行 4 阶段根因分析 |
| `verification-before-completion` | 主张之前先有证据——除非有命令证明，否则任务不算"完成" |

### 设计与规划

| 技能 | 作用 |
|------|------|
| `brainstorming` | 写代码前的苏格拉底式设计会话——产出一份已获批准的规格说明 |
| `stress-test` | 对设计与计划进行对抗性审问，并提供推荐答案 |
| `writing-plans` | 拆解为小任务的计划——每项任务都作为 `bd` bead 追踪 |

### 执行

| 技能 | 作用 |
|------|------|
| `subagent-driven-development` | 每项任务派遣全新智能体，含规格与质量审查；支持并行批处理模式 |
| `executing-plans` | 在单次会话内批量执行计划，并设置检查点 |
| `using-git-worktrees` | 每个功能使用独立的开发分支 |
| `requesting-code-review` | 按结构化标准派遣代码审查子智能体 |
| `finishing-a-development-branch` | 合并/PR 流程 + Land the Plane（关闭 beads、同步、推送） |

### 记忆与定向

| 技能 | 作用 |
|------|------|
| `getting-up-to-speed` | 会话定向——加载 `bd` 上下文并生成当前状态摘要 |
| `memory-curator` | 整合、去重并清理持久记忆库 |
| `session-handoff` | 生成有据可查的交接文档，让下一次会话接续进行中的工作 |
| `research-driven-development` | 并行研究智能体 → 经过验证的持久知识库 |

**[完整技能参考 →](https://algocents.com/beads-superpowers/skills/)**

## 工作原理

开始任务时，智能体先运行 **brainstorming** 以在触碰代码前明确需求，再通过 **writing-plans** 将工作拆解为 `bd` 追踪的步骤——这些步骤在会话重启后仍然保留。实现阶段遵循 **test-driven-development**（始终先写失败的测试），并可通过 **subagent-driven-development** 扇出到并行子智能体——每个智能体在各自的 git worktree 中工作。`bd` 将每项任务、决策和备注存储在本地 Dolt 数据库中，因此智能体在下次会话时能从上次中断处精确接续，无需依赖聊天记录。

这一切之下是生产级标准：智能体将每项任务视为真实用户依赖的事项，因此它不会为了速度偷偷走捷径、遗漏需求或削弱安全控制。

## 理念

- **设计先于代码** — 每个功能都始于一份经过人工批准的规格说明，而非猜测
- **TDD 是铁律** — 没有失败的测试就不能实现代码
- **系统化优于临时应对** — 调试遵循根因分析流程，绝不靠猜测和试错
- **有证据才有主张** — "完成"需要一条命令来证明
- **记忆优于聊天记录** — 任务、决策和经验教训持久保存在 `bd` 中，而非保存在滚动的对话缓冲区里

完整版本参见[方法论](https://algocents.com/beads-superpowers/methodology/)。

## 文档

**[algocents.com/beads-superpowers](https://algocents.com/beads-superpowers/)** — 快速入门、方法论、技能参考、示例工作流与使用技巧。

- [示例工作流文档](https://algocents.com/beads-superpowers/workflow/) — 含图示的完整演练
- [技能参考](https://algocents.com/beads-superpowers/skills/) — 所有技能详解
- [方法论](https://algocents.com/beads-superpowers/methodology/) — 为何采用此工作流

文档*内容*存放在本仓库中（`docs/` ——欢迎提交 PR）；网站则由另一个独立的部署仓库构建并发布。

## 安装

> **⚠️ 共存警告：** 请勿与 [obra/superpowers](https://github.com/obra/superpowers) 同时安装。技能名称存在冲突——请二选一。

### 前提条件

**先安装 `bd`，再安装插件。** 其钩子在每次会话启动时调用 `bd`；若未安装，钩子将静默失败，导致丢失持久记忆。可使用 Homebrew（`brew install beads`），或在任何平台上使用 `npm install -g @beads/bd`。通过 `bd version` 验证安装。

**注意：** 原生插件安装会安装技能和钩子，但不会执行 `bd init`——请在每个项目中手动运行。

### Claude Code

```bash
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

或在 Claude Code 会话内通过斜杠命令执行：`/plugin marketplace add DollarDill/beads-superpowers`，然后 `/plugin install beads-superpowers@beads-superpowers-marketplace`。

### Codex CLI

```bash
codex plugin marketplace add DollarDill/beads-superpowers
codex plugin install beads-superpowers@beads-superpowers-marketplace
```

安装后，在 `~/.codex/config.toml` 中启用钩子：

```toml
[features]
codex_hooks = true
```

要在 Codex 下获得 SessionStart hook，请使用脚本安装器（`install.sh`）而不是插件渠道——插件渠道只安装 skills，不会接线 hook。

### OpenCode

将其添加到你的 `opencode.json`（全局或项目级）的 `plugin` 数组中：

```json
{
  "plugin": ["beads-superpowers@git+https://github.com/DollarDill/beads-superpowers.git"]
}
```

技能会自动注册，会话引导 + beads 上下文也会自动注入——无需其他步骤。详情、版本固定、从 pre-0.12 安装程序副本迁移及故障排除，请参阅 [.opencode/INSTALL.md](.opencode/INSTALL.md)。

### Cursor

```text
/add-plugin beads-superpowers
```

在 Cursor 智能体内运行此命令。通过 Marketplace UI 更新。

### GitHub Copilot CLI

```bash
copilot plugin marketplace add DollarDill/beads-superpowers
copilot plugin install beads-superpowers@beads-superpowers-marketplace
```

更新：

```bash
copilot plugin update beads-superpowers
```

注意：使用 Claude 插件回退方案（通过共享的 `hooks/hooks.json` 加载技能和 session-start），与上游相同机制；会话启动上下文注入需要 Copilot CLI v1.0.11+。

### Kimi Code

```text
/plugins install https://github.com/DollarDill/beads-superpowers
```

安装后运行 `/new` 以启动含插件的新会话。

### Antigravity

```bash
agy plugin install https://github.com/DollarDill/beads-superpowers
```

注意：复用 Claude 插件清单——与上游验证的机制相同。

### Factory Droid

```bash
droid plugin marketplace add https://github.com/DollarDill/beads-superpowers
droid plugin install beads-superpowers@beads-superpowers-marketplace
```

注意：复用 Claude 插件清单——与上游验证的机制相同。

### Pi

```bash
pi install git:github.com/DollarDill/beads-superpowers
```

### npx（任意智能体）

仅安装技能——不包含钩子。技能激活依赖于你所用智能体自身的原生技能发现机制。

```bash
npx skills add DollarDill/beads-superpowers -g --copy -y
```

### 替代方案：脚本安装（`curl | bash`）

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

该脚本的作用不仅限于复制文件。当你需要以下任何功能时使用它：

- **Beads/Dolt 初始化** — 自动检测 `bd` 是否已安装并引导设置
- **钩子注册** — 将 SessionStart 条目写入 settings.json（使用脚本安装路径时必需）
- **`yegge.md` 编排器** — 可选附加组件：仅在传入 `--with-yegge` 时安装。该标志会强制使用脚本化的 tarball/git 安装层级（该次运行会跳过 plugin 和 npx 层级），因此无法在一条命令中与插件管理的安装方式组合使用
- **版本锁定** — `--version X.Y.Z` 用于可重现的 CI 安装
- **CI 环境** — 使用 `--yes --skip-checksum` 进行无人值守运行

支持：`--yes`（跳过提示）、`--version X.Y.Z`、`--with-yegge`、`--dry-run`、`--skip-checksum`、`--uninstall`。

更新：重新运行你的安装命令——插件渠道通过其市场更新，npx 与脚本安装通过重新运行完成更新。

## 贡献

欢迎贡献——参见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。PR 请提交至 **`dev`** 分支（`main` 为已发布分支）。想法与问题请前往 [Discussions](https://github.com/DollarDill/beads-superpowers/discussions)。

## 基于

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — 技能体系与开发实践
- **[Beads](https://github.com/gastownhall/beads)** by Steve Yegge — 跨会话记忆的持久化问题追踪

部分技能改编自：

- **Garry Tan** — `document-release`，改编自 [garrytan/gstack](https://github.com/garrytan/gstack/tree/main/document-release)
- **Matt Pocock** — `stress-test`，源自 [skills/grilling](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md)；`session-handoff`，源自 [skills/handoff](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md)
- **Ivan Neustroev（"Anbeeld"）** — `write-documentation` 背后的写作体系，改编自 [WRITING.md](https://github.com/Anbeeld/WRITING.md)（MIT）

## 许可证

[MIT](LICENSE)

## 社区

- **想法与问题：** [GitHub Discussions](https://github.com/DollarDill/beads-superpowers/discussions) — 置顶帖是入口
- **Bug：** [Issues](https://github.com/DollarDill/beads-superpowers/issues)
- **联系方式：** <dillon@algocents.com>
