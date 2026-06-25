<p align="center">
  <img src="assets/banner.svg" alt="beads-superpowers — Process discipline and persistent memory for AI coding agents" width="100%" />
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href=".claude-plugin/plugin.json"><img alt="Plugin version" src="https://img.shields.io/badge/plugin-v0.7.0-4f46e5.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml"><img alt="Release" src="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/DollarDill/beads-superpowers?style=social"></a>
</p>

---

A plugin for Claude Code, Codex, and OpenCode that makes your AI coding agent write tests before code, debug systematically instead of guessing, and remember what it worked on yesterday. 22 skills enforce the practices; a Dolt-backed issue tracker keeps context across sessions.

## How it works

When you start a task, the agent runs **brainstorming** to nail down requirements before touching code, then **writing-plans** to break the work into `bd`-tracked steps that survive session restarts. During implementation it follows **test-driven-development** (failing test first, always) and can fan out to parallel subagents via **subagent-driven-development** — each agent working in its own git worktree. `bd` stores every task, decision, and note in a local Dolt database, so the agent picks up exactly where it left off next session without relying on chat history.

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
| `research-driven-development` | Parallel research agents → synthesized knowledge-base document |
| `write-documentation` | Human-quality prose — 14-rule writing system with context-first drafting |

### Meta

| Skill | What it does |
|-------|-------------|
| `using-superpowers` | Bootstrap — injected at session start, routes to the right skill |
| `setup` | Post-install hook configuration (SessionStart + UserPromptSubmit) |
| `writing-skills` | Meta-skill for creating or modifying skills in this plugin |
| `auditing-upstream-drift` | Detects staleness vs upstream superpowers and beads releases |

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

Start a new Claude Code session and type "where are we" — the agent will orient itself using your beads context.

## Prerequisites

**`bd` must be installed before the plugin will work.** The plugin registers hooks that call `bd` on every session start; if `bd` isn't present, those hooks fail silently and you lose persistent memory.

```bash
brew install beads          # macOS / Linux
# or
npm install -g @beads/bd    # any platform
```

Verify with `bd version`. Then install the plugin (see below), then run `bd init` in each project.

**Note:** Native plugin install (Tier 1) installs skills and hooks automatically. It does NOT run `bd init` — you must do that yourself per project.

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

### Tier 2 — Community / Best-effort

These paths work but are not tested by us. Use with that in mind.

| CLI | How to install | Status |
|-----|----------------|--------|
| Cursor | `npx skills add DollarDill/beads-superpowers -g --copy -y`, then run the `setup` skill to register hooks | community-verified, not tested by us — last reviewed 2026-06 |
| Gemini CLI | `npx skills add DollarDill/beads-superpowers -g --copy -y` | community-verified, not tested by us — last reviewed 2026-06 |
| GitHub Copilot CLI | `npx skills add DollarDill/beads-superpowers -g --copy -y` | community-verified, not tested by us — last reviewed 2026-06 |

For other CLIs, see [obra/superpowers' install list](https://github.com/obra/superpowers#installation) — the same `npx skills add` mechanism applies.

### Alternative: scripted install (`curl | bash`)

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The script's role is broader than just copying files. Use it when you need any of:

- **Beads/Dolt bootstrap** — auto-detects whether `bd` is installed and guides setup
- **Hook registration** — writes SessionStart and UserPromptSubmit entries to `settings.json` (required when using npx or manual install paths)
- **`yegge.md` orchestrator** — optionally installs the 11-state FSM agent globally
- **Version pinning** — `--version X.Y.Z` for reproducible CI installs
- **CI environments** — use `--yes --skip-checksum` for unattended runs

Supports: `--yes` (skip prompts), `--version X.Y.Z`, `--dry-run`, `--skip-checksum`, `--uninstall`.

## First project setup

Initialise beads in your project:

```bash
cd your-project
bd init
```

## Updating

**Claude Code:**

```bash
claude plugin marketplace update beads-superpowers-marketplace
```

**Codex CLI:**

```bash
codex plugin marketplace update beads-superpowers-marketplace
```

**OpenCode / scripted / npx:**

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
# or
npx skills add DollarDill/beads-superpowers -g --copy -y
```

Re-running the installer or `npx skills add` overwrites the existing installation. No `bd init` needed — your existing `.beads/` database is untouched.

## Docs

**[dollardill.github.io/beads-superpowers](https://dollardill.github.io/beads-superpowers/)** — getting started, methodology, skills reference, example workflow, and tips.

## Built on

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — the skill system and development practices
- **[Beads](https://github.com/gastownhall/beads)** by Steve Yegge — persistent issue tracking with cross-session memory

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Ideas welcome in **[Discussions](https://github.com/DollarDill/beads-superpowers/discussions/27)**.

## License

[MIT](LICENSE)
