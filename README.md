<p align="center"><strong>English</strong> · <a href="README.zh-CN.md">中文</a></p>

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

A plugin for Claude Code, Codex, OpenCode, and 6 more AI coding agents that makes your agent write tests before code, debug systematically instead of guessing, and remember what it worked on yesterday. Composable skills enforce the practices; a Dolt-backed issue tracker keeps context across sessions.

## Quickstart

The fastest path - Claude Code with native plugin install:

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

Start a new Claude Code session and type "where are we" - the agent will load your `bd` context and pick up where you left off.

Using a different agent? Jump to install for [Codex CLI](#codex-cli), [OpenCode](#opencode), [Cursor](#cursor), [GitHub Copilot CLI](#github-copilot-cli), [Kimi Code](#kimi-code), [Antigravity](#antigravity), [Factory Droid](#factory-droid), or [Pi](#pi).

## The Basic Workflow

1. **research-driven-development** - When the task needs understanding first: parallel research agents investigate and write a verified knowledge-base document before any design happens.

2. **brainstorming** - Refines the idea through one-question-at-a-time design dialogue, checks prior decisions in the knowledge store, and ends with a spec you approved - tracked in `bd` so it survives the session.

3. **stress-test** - Adversarially interrogates the approved spec branch by branch (offered at every spec review), so flaws surface before planning.

4. **writing-plans** - Turns the spec into bite-sized tasks with exact files, code, and verification steps. Every task becomes a `bd` bead.

5. **stress-test** (again) - The same adversarial pass against the plan itself: task boundaries, parallel-safety, failure modes.

6. **subagent-driven-development** or **executing-plans** - Dispatches a fresh subagent per task, each in its own isolated worktree (implementers follow **test-driven-development**), or executes in batches with human checkpoints.

7. **requesting-code-review** - Task-level and whole-branch reviews against the plan. Critical findings block progress.

8. **verification-before-completion** - Nothing is called done without a command that proves it - evidence gates every close.

9. **document-release** - Audits the project docs against what actually shipped, before the branch merges.

10. **finishing-a-development-branch** - Presents merge/PR options and lands the plane: close the beads, sync, push.

The agent checks for relevant skills before any task - these are mandatory workflows, not suggestions. And because every task, decision, and lesson lives in `bd`'s Dolt database, the next session starts where this one ended: type "where are we" and the agent picks the thread back up.

## What's Inside

<!-- Curation rule: every distributed skill appears here except using-superpowers - the session bootstrap, which upstream's README also leaves out. The full reference lives on the docs site. -->

### Testing

| Skill | What it does |
|-------|-------------|
| `test-driven-development` | RED-GREEN-REFACTOR loop - Iron Law: no implementation without a failing test |

### Debugging

| Skill | What it does |
|-------|-------------|
| `systematic-debugging` | 4-phase root-cause analysis before proposing any fix |
| `verification-before-completion` | Evidence before claims - nothing is "done" until a command proved it |

### Design & planning

| Skill | What it does |
|-------|-------------|
| `brainstorming` | Socratic design session before any code - produces an approved spec |
| `stress-test` | Adversarial interrogation of designs and plans, with recommended answers |
| `writing-plans` | Bite-sized task plans - every task tracked as a `bd` bead |

### Execution

| Skill | What it does |
|-------|-------------|
| `subagent-driven-development` | Fresh agent per task with spec + quality review; parallel batch mode |
| `executing-plans` | Batch plan execution in a single session with checkpoints |
| `dispatching-parallel-agents` | Fans out 2+ independent tasks to parallel agents with no shared state |
| `using-git-worktrees` | Isolated development branches per feature |
| `requesting-code-review` | Dispatches a code-reviewer subagent with structured criteria |
| `receiving-code-review` | Verifies review feedback against the code before implementing it - no reflexive agreement |
| `finishing-a-development-branch` | Merge/PR flow + land the plane (close beads, sync, push) |

### Documentation

| Skill | What it does |
|-------|-------------|
| `write-documentation` | 14-rule writing system for human-facing prose - READMEs, guides, release notes |
| `document-release` | Post-ship documentation audit - keeps the docs matching what actually shipped |

### Memory & orientation

| Skill | What it does |
|-------|-------------|
| `getting-up-to-speed` | Session orientation - loads `bd` context and produces a current-state summary |
| `memory-curator` | Consolidates, deduplicates, and prunes the persistent memory store |
| `session-handoff` | Writes a grounded handoff doc so the next session resumes mid-flight work |
| `research-driven-development` | Parallel research agents → verified, persistent knowledge base |
| `project-init` | Sets up, bootstraps, and recovers the beads/Dolt database behind persistent memory |

**[Full skills reference →](https://algocents.com/beads-superpowers/skills/)**

## How it works

When you start a task, the agent runs **brainstorming** to nail down requirements before touching code, then **writing-plans** to break the work into `bd`-tracked steps that survive session restarts. During implementation it follows **test-driven-development** (failing test first, always) and can fan out to parallel subagents via **subagent-driven-development** - each agent working in its own git worktree. `bd` stores every task, decision, and note in a local Dolt database, so the agent picks up exactly where it left off next session without relying on chat history.

Underneath all of it is a production-grade standard: the agent treats every task as if real users depend on it, so it won't quietly cut a corner, drop a requirement, or weaken a security control to move faster.

## Philosophy

- **Design before code** - every feature starts as a spec a human approved, not a guess
- **TDD is an Iron Law** - no implementation without a failing test
- **Systematic over ad-hoc** - debugging follows a root-cause process, never guess-and-check
- **Evidence before claims** - "done" requires a command that proves it
- **Memory over chat history** - tasks, decisions, and lessons persist in `bd`, not in a scroll buffer

The long form lives in [Methodology](https://algocents.com/beads-superpowers/methodology/).

## Docs

**[algocents.com/beads-superpowers](https://algocents.com/beads-superpowers/)** - getting started, methodology, skills reference, example workflow, and tips.

- [Example Workflow docs](https://algocents.com/beads-superpowers/workflow/) - Full walkthrough with diagrams
- [Skills Reference](https://algocents.com/beads-superpowers/skills/) - All skills explained
- [Methodology](https://algocents.com/beads-superpowers/methodology/) - Why this workflow exists

## Installation

> **⚠️ Coexistence warning:** Do not install alongside [obra/superpowers](https://github.com/obra/superpowers). Skill names collide - pick one or the other.

### Prerequisites

**Install `bd` before the plugin.** Its hooks call `bd` on every session start; without it they fail silently and you lose persistent memory. Use Homebrew (`brew install beads`) or `npm install -g @beads/bd` on any platform. Verify with `bd version`.

**Note:** Native plugin install installs skills and hooks, but not `bd init` - run that yourself per project.

### Claude Code

```bash
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

Or as slash commands inside a Claude Code session: `/plugin marketplace add DollarDill/beads-superpowers` then `/plugin install beads-superpowers@beads-superpowers-marketplace`.

### Codex CLI

```bash
codex plugin marketplace add DollarDill/beads-superpowers
codex plugin install beads-superpowers@beads-superpowers-marketplace
```

After installing, enable hooks in `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

To get the SessionStart hook under Codex, use the scripted installer (`install.sh`) rather than the plugin channel - the plugin channel installs the skills but does not wire the hook.

### OpenCode

Add to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["beads-superpowers@git+https://github.com/DollarDill/beads-superpowers.git"]
}
```

Skills auto-register and the session bootstrap + beads context inject automatically - no other steps. Details, version pinning, migration from pre-0.12 installer copies, and troubleshooting: [.opencode/INSTALL.md](.opencode/INSTALL.md).

### Cursor

```text
/add-plugin beads-superpowers
```

Run this command inside Cursor Agent. Update via the Marketplace UI.

### GitHub Copilot CLI

```bash
copilot plugin marketplace add DollarDill/beads-superpowers
copilot plugin install beads-superpowers@beads-superpowers-marketplace
```

Update:

```bash
copilot plugin update beads-superpowers
```

Note: rides the Claude-plugin fallback (skills + session-start via the shared `hooks/hooks.json`), the same mechanism upstream ships; requires Copilot CLI v1.0.11+ for session-start context injection.

### Kimi Code

```text
/plugins install https://github.com/DollarDill/beads-superpowers
```

Run `/new` after install to start a fresh session with the plugin active.

### Antigravity

```bash
agy plugin install https://github.com/DollarDill/beads-superpowers
```

Note: reuses the Claude plugin manifest - the same mechanism upstream verified.

### Factory Droid

```bash
droid plugin marketplace add https://github.com/DollarDill/beads-superpowers
droid plugin install beads-superpowers@beads-superpowers-marketplace
```

Note: reuses the Claude plugin manifest - the same mechanism upstream verified.

### Pi

```bash
pi install git:github.com/DollarDill/beads-superpowers
```

### npx (any harness)

Installs the skills only - no hooks. Skill activation relies on your harness's native skill discovery.

```bash
npx skills add DollarDill/beads-superpowers -g --copy -y
```

### Alternative: scripted install (`curl | bash`)

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The script's role is broader than just copying files. Use it when you need any of:

- **Beads/Dolt bootstrap** - auto-detects whether `bd` is installed and guides setup
- **Hook registration** - writes the SessionStart entry to settings.json (required when using the install-script path)
- **`yegge.md` orchestrator** - optional add-on: installed only when you pass `--with-yegge`. The flag forces the scripted tarball/git install tier (the plugin and npx tiers are skipped for that run), so it can't be combined with a plugin-managed install in one command
- **Version pinning** - `--version X.Y.Z` for reproducible CI installs
- **CI environments** - use `--yes --skip-checksum` for unattended runs

Supports: `--yes` (skip prompts), `--version X.Y.Z`, `--with-yegge`, `--dry-run`, `--skip-checksum`, `--uninstall`.

Updates: rerun your install command - plugin channels update via their marketplace, npx and the script by rerunning.

## Contributing

Contributions are welcome - see [`CONTRIBUTING.md`](CONTRIBUTING.md). PRs target the **`dev`** branch (`main` is the released branch). Ideas and questions live in [Discussions](https://github.com/DollarDill/beads-superpowers/discussions).

## Built on

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent - the skill system and development practices
- **[Beads](https://github.com/gastownhall/beads)** by Steve Yegge - persistent issue tracking with cross-session memory

Individual skills adapted from:

- **Garry Tan** - `document-release`, adapted from [garrytan/gstack](https://github.com/garrytan/gstack/tree/main/document-release)
- **Matt Pocock** - `stress-test`, from [skills/grilling](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md); `session-handoff`, from [skills/handoff](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md)
- **Ivan Neustroev ("Anbeeld")** - the writing system behind `write-documentation`, adapted from [WRITING.md](https://github.com/Anbeeld/WRITING.md) (MIT)

## License

[MIT](LICENSE)

## Community

- **Ideas & questions:** [GitHub Discussions](https://github.com/DollarDill/beads-superpowers/discussions) - the pinned post is the front door
- **Bugs:** [Issues](https://github.com/DollarDill/beads-superpowers/issues)
- **Contact:** <dillon@algocents.com>
