<p align="center"><strong>English</strong> · <a href="README.zh-CN.md">中文</a></p>

<p align="center">
  <img src="assets/banner.svg" alt="beads-superpowers — Process discipline and persistent memory for AI coding agents" width="100%" />
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href=".claude-plugin/plugin.json"><img alt="Plugin version" src="https://img.shields.io/badge/plugin-v0.8.0-4f46e5.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml"><img alt="Release" src="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/DollarDill/beads-superpowers?style=social"></a>
</p>

---

A plugin for Claude Code, Codex, OpenCode, and 7 more AI coding agents that makes your agent write tests before code, debug systematically instead of guessing, and remember what it worked on yesterday. 23 skills enforce the practices; a Dolt-backed issue tracker keeps context across sessions.

## How it works

When you start a task, the agent runs **brainstorming** to nail down requirements before touching code, then **writing-plans** to break the work into `bd`-tracked steps that survive session restarts. During implementation it follows **test-driven-development** (failing test first, always) and can fan out to parallel subagents via **subagent-driven-development** — each agent working in its own git worktree. `bd` stores every task, decision, and note in a local Dolt database, so the agent picks up exactly where it left off next session without relying on chat history.

Underneath all of it is a production-grade standard: the agent treats every task as if real users depend on it, so it won't quietly cut a corner, drop a requirement, or weaken a security control to move faster.

## What's Inside

### Testing

| Skill | What it does |
|-------|-------------|
| `test-driven-development` | RED-GREEN-REFACTOR loop — Iron Law: no implementation without a failing test |
| `verification-before-completion` | Evidence before claims — requires proof before marking anything done |

### Debugging

| Skill | What it does |
|-------|-------------|
| `systematic-debugging` | 4-phase root-cause analysis before proposing any fix |

### Collaboration

| Skill | What it does |
|-------|-------------|
| `requesting-code-review` | Dispatches a code-reviewer subagent with structured criteria |
| `receiving-code-review` | Anti-sycophancy reception — evaluates each finding on its merits |
| `subagent-driven-development` | Fresh agent per task with spec + quality review; parallel batch mode for independent tasks |
| `dispatching-parallel-agents` | Fan-out to 2+ independent agents without shared state |

### Project management

| Skill | What it does |
|-------|-------------|
| `brainstorming` | Socratic design session before any code — produces a spec bead |
| `stress-test` | Adversarial interrogation of plans with recommended answers |
| `writing-plans` | Breaks work into bite-sized tasks, each tracked as a `bd` bead |
| `executing-plans` | Batch plan execution in a single session |
| `using-git-worktrees` | Isolated development branches per task |
| `finishing-a-development-branch` | Merge/PR flow + Land the Plane (close beads, push) |
| `document-release` | Post-ship doc audit — keeps README, CHANGELOG, and ARCHITECTURE in sync |
| `project-init` | Beads/Dolt DB setup, bootstrap, and recovery |
| `getting-up-to-speed` | Session orientation — loads `bd` context and produces a current-state summary |
| `memory-curator` | Session-close/on-demand memory consolidation — deduplicates and prunes the `bd` memory store |
| `research-driven-development` | Parallel research agents → synthesized knowledge-base document |
| `write-documentation` | Human-quality prose — 14-rule writing system with context-first drafting |

### Meta

| Skill | What it does |
|-------|-------------|
| `using-superpowers` | Bootstrap — injected at session start, routes to the right skill |
| `setup` | Post-install hook configuration (SessionStart + UserPromptSubmit) |
| `writing-skills` | Meta-skill for creating or modifying skills in this plugin |
| `auditing-upstream-drift` | Detects staleness vs upstream superpowers and beads releases |

## Docs

**[dollardill.github.io/beads-superpowers](https://dollardill.github.io/beads-superpowers/)** — getting started, methodology, skills reference, example workflow, and tips.

## Quickstart

The fastest path — Claude Code with native plugin install:

```bash
brew install beads                    # 1. Install bd (requires beads v1.0.5+)
# From your shell:
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
# Or, inside a Claude Code session:
# /plugin marketplace add DollarDill/beads-superpowers
# /plugin install beads-superpowers@beads-superpowers-marketplace
# Then in your project directory:
bd init                               # 2. Bootstrap the Dolt database for this project
```

Start a new Claude Code session and type "where are we" — the agent will load your `bd` context and pick up where you left off.

Using a different agent? See [Installation](#installation) for native install on Codex, OpenCode, Cursor, Gemini CLI, GitHub Copilot CLI, Kimi Code, Antigravity, Factory Droid, and Pi.

## Prerequisites

**Install `bd` before the plugin.** Its hooks call `bd` on every session start; without it they fail silently and you lose persistent memory. The Quickstart above uses Homebrew, or `npm install -g @beads/bd` on any platform. Verify with `bd version`.

**Note:** Native plugin install (Tier 1) installs skills and hooks, but not `bd init` — run that yourself per project.

## Installation

> **⚠️ Coexistence warning:** Do not install alongside [obra/superpowers](https://github.com/obra/superpowers). Skill names collide — pick one or the other.

### Tier 1 — Verified

These paths are tested end-to-end. Prefer them.

#### Claude Code

```bash
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

Or as slash commands inside a Claude Code session: `/plugin marketplace add DollarDill/beads-superpowers` then `/plugin install beads-superpowers@beads-superpowers-marketplace`.

#### Codex CLI

```bash
codex plugin marketplace add DollarDill/beads-superpowers
codex plugin install beads-superpowers@beads-superpowers-marketplace
```

After installing, enable hooks in `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

#### OpenCode

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The installer detects OpenCode and copies skills to `~/.config/opencode/skills/` and the TypeScript plugin to `~/.config/opencode/plugins/` (active automatically).

### Tier 2 — Best-effort

Config validated; not E2E-tested by us. Use with that in mind.

#### Cursor

```text
/add-plugin beads-superpowers
```

Run this command inside Cursor Agent. Update via the Marketplace UI.

#### Gemini CLI

```bash
gemini extensions install https://github.com/DollarDill/beads-superpowers
```

Update:

```bash
gemini extensions update beads-superpowers
```

#### GitHub Copilot CLI

```bash
copilot plugin marketplace add DollarDill/beads-superpowers
copilot plugin install beads-superpowers@beads-superpowers-marketplace
```

Update:

```bash
copilot plugin update beads-superpowers
```

Note: rides the Claude-plugin fallback (skills + session-start via the shared `hooks/hooks.json`), the same mechanism upstream ships; requires Copilot CLI v1.0.11+ for session-start context injection.

#### Kimi Code

```text
/plugins install https://github.com/DollarDill/beads-superpowers
```

Run `/new` after install to start a fresh session with the plugin active.

#### Antigravity

```bash
agy plugin install https://github.com/DollarDill/beads-superpowers
```

Note: reuses the Claude plugin manifest — the same mechanism upstream verified.

#### Factory Droid

```bash
droid plugin marketplace add https://github.com/DollarDill/beads-superpowers
droid plugin install beads-superpowers@beads-superpowers-marketplace
```

Note: reuses the Claude plugin manifest — the same mechanism upstream verified.

#### Pi

```bash
pi install git:github.com/DollarDill/beads-superpowers
```

#### Universal fallback (npx)

Works on any CLI that supports the Vercel Skills format:

```bash
npx skills add DollarDill/beads-superpowers -g --copy -y
```

### Alternative: scripted install (`curl | bash`)

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The script's role is broader than just copying files. Use it when you need any of:

- **Beads/Dolt bootstrap** — auto-detects whether `bd` is installed and guides setup
- **Hook registration** — writes SessionStart and UserPromptSubmit entries to `settings.json` (required when using npx or manual install paths)
- **`yegge.md` orchestrator** — optionally installs the orchestrator agent globally
- **Version pinning** — `--version X.Y.Z` for reproducible CI installs
- **CI environments** — use `--yes --skip-checksum` for unattended runs

Supports: `--yes` (skip prompts), `--version X.Y.Z`, `--dry-run`, `--skip-checksum`, `--uninstall`.

## Built on

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — the skill system and development practices
- **[Beads](https://github.com/gastownhall/beads)** by Steve Yegge — persistent issue tracking with cross-session memory

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Ideas welcome in **[Discussions](https://github.com/DollarDill/beads-superpowers/discussions/27)**.

## License

[MIT](LICENSE)
