---
description: Install beads-superpowers via the native plugin system, curl, or npx for Claude Code, Codex, and OpenCode. Set up your first project with bd init in under 5 minutes.
---

# Getting Started

## Prerequisites

**`bd` must be installed before the plugin will work.** The plugin registers hooks that call `bd` on every session start; if `bd` isn't present, those hooks fail silently and you lose persistent memory.

```bash
brew install beads          # macOS / Linux
# or
npm install -g @beads/bd    # any platform
```

Verify with `bd version`. Then install the plugin (see below), then run `bd init` in each project.

**Note:** Native plugin install (Tier 1) installs skills and hooks automatically. It does NOT run `bd init` — you must do that yourself per project.

**Optional:** A [DoltHub](https://dolthub.com) account if you want cross-session sync via `bd dolt push/pull`. Without it, beads still works locally.

## Supported Platforms

### Tier 1 — Verified

These paths are tested end-to-end. Prefer them.

| CLI | Install method |
|-----|---------------|
| Claude Code | Native plugin marketplace (see below) |
| Codex CLI | Native plugin marketplace + `codex_hooks = true` (see below) |
| OpenCode | curl installer (see below) |

### Tier 2 — Best-effort

Config validated; not E2E-tested by us. Use with that in mind.

| CLI | Install | Update | Notes |
|-----|---------|--------|-------|
| Cursor | `/add-plugin beads-superpowers` (in Cursor Agent) | Marketplace UI | config validated by us; not E2E-tested |
| GitHub Copilot CLI | `copilot plugin marketplace add DollarDill/beads-superpowers` then `copilot plugin install beads-superpowers@beads-superpowers-marketplace` | `copilot plugin update beads-superpowers` | rides the Claude-plugin fallback (skills + session-start via the shared `hooks/hooks.json`), the same mechanism upstream ships; requires Copilot CLI v1.0.11+ |
| Kimi Code | `/plugins install https://github.com/DollarDill/beads-superpowers` (run `/new` after) | — | |
| Antigravity | `agy plugin install https://github.com/DollarDill/beads-superpowers` | — | reuses the Claude plugin manifest — the same mechanism upstream verified; not E2E-tested by us |
| Factory Droid | `droid plugin marketplace add https://github.com/DollarDill/beads-superpowers` then `droid plugin install beads-superpowers@beads-superpowers-marketplace` | — | reuses the Claude plugin manifest — the same mechanism upstream verified; not E2E-tested by us |
| Pi | `pi install git:github.com/DollarDill/beads-superpowers` | — | config validated by us; not E2E-tested |

## Install the plugin

> **⚠️ Coexistence warning:** Do not install alongside [obra/superpowers](https://github.com/obra/superpowers). Skill names collide — pick one or the other.

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

Codex plugin-channel installs do not register the SessionStart hook — use the scripted installer (`install.sh`), which wires it explicitly.

### OpenCode

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The installer detects OpenCode and copies skills to `~/.config/opencode/skills/` and the TypeScript plugin to `~/.config/opencode/plugins/` (active automatically).

### Scripted install (`curl | bash`)

The curl installer also works for Claude Code and Codex when you need more than a plain plugin install:

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The installer auto-detects which CLIs are on your system and installs skills and hooks for each:

| CLI | Skills path | Hooks / Plugin |
|-----|------------|----------------|
| Claude Code | `~/.claude/skills/` | SessionStart hook in `settings.json` |
| Codex | `~/.codex/skills/` | Enable with `codex_hooks = true` in `~/.codex/config.toml` |
| OpenCode | `~/.config/opencode/skills/` | TypeScript plugin at `~/.config/opencode/plugins/` (active automatically) |

Use the scripted install when you need any of:

- **Beads/Dolt bootstrap** — auto-detects whether `bd` is installed and guides setup
- **Hook registration** — writes the SessionStart entry to `settings.json` (required when using npx or manual install paths)
- **`yegge.md` orchestrator** — optional add-on: installed only when you pass `--with-yegge`
- **Version pinning** — `--version X.Y.Z` for reproducible CI installs
- **CI environments** — use `--yes --skip-checksum` for unattended runs

Supports `--yes` (skip prompts), `--version X.Y.Z`, `--with-yegge`, `--dry-run`, `--skip-checksum`, and `--uninstall`.

### npx (Vercel Skills CLI)

```bash
npx skills add DollarDill/beads-superpowers -a claude-code -g --copy -y
# Use -a codex to also install for Codex CLI.
```

Installs the skills only — no hooks. Skill activation relies on your harness's native skill discovery. For the full experience (session-start context injection + automatic `bd prime`), use the plugin install or the scripted install above. To get beads context on an npx install, run `bd setup claude` (beads' own hook installer).

## First project setup

Initialise beads in your project:

```bash
cd your-project
bd init
```

This creates `.beads/` (config, metadata, git hooks), `CLAUDE.md`, and `AGENTS.md`. The plugin's session-start hook automatically detects if `bd setup claude` hooks are present and skips its own `bd prime` call, so no manual cleanup is needed.

### Dolt remote (optional)

For cross-session sync of your task history:

```bash
bd dolt remote add origin https://doltremoteapi.dolthub.com/your-org/your-repo
bd dolt push    # test the connection
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

**Copilot CLI:**

```bash
copilot plugin update beads-superpowers
```

**OpenCode / scripted / npx:**

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
# or
npx skills add DollarDill/beads-superpowers -g --copy -y
```

Re-running the installer or `npx skills add` overwrites the existing installation. No `bd init` needed — your existing `.beads/` database is untouched.

## Verify it works

Start a fresh session in your CLI of choice, then:

1. **Check skills loaded:** Type `/skills` (Claude Code/Codex) or check the skill list in OpenCode — you should see {{ skill_count }} skills prefixed with `beads-superpowers:`
2. **Check beads works:** Run `bd ready` and `bd stats` in the terminal

If skills aren't showing, the plugin may not be installed for your CLI. If `bd ready` fails, beads isn't initialised in this project (`bd init`).

## How the hooks work

Claude Code and Codex share one hook, registered via `hooks/hooks.json`: **SessionStart**. It fires on every session start, clear, and compact. It reads the `using-superpowers` skill (which routes to all other skills), runs `bd prime` to capture beads state and persistent memories, and outputs the combined context (~2–3k tokens). If `bd prime` is already registered as a hook elsewhere, this step is skipped automatically.

```mermaid
sequenceDiagram
  participant CC as CLI (Claude Code / Codex)
  participant SH as SessionStart Hook
  participant Agent as Agent

  CC->>SH: Session begins
  SH->>SH: Read using-superpowers skill
  SH->>SH: Run bd prime
  SH-->>Agent: Inject skills context + beads state
  Note over Agent: Agent is now skill-aware
```

OpenCode uses its own TypeScript plugin instead of `hooks/hooks.json`, with two in-process hooks: a `chat.message` hook injects the same bootstrap once per session, and an `experimental.session.compacting` hook re-injects beads context after the context window compacts.

## Configuration

**Instruction priority** when things conflict:

1. Your project's `CLAUDE.md` (highest)
2. Plugin skills
3. Default system prompt (lowest)

To override a skill's behaviour, add instructions to your project's `CLAUDE.md` — no need to fork the plugin.

**Beads project config** lives in `.beads/config.yaml`. The defaults work for most projects.

## Troubleshooting

**Skills not loading** — Run `/plugins` to check the plugin is installed, then `/skills` to check skills are visible. If missing, reinstall: `claude plugin marketplace update beads-superpowers-marketplace`.

**`bd: command not found`** — Beads isn't installed or isn't on your PATH. Run `brew install beads` or `npm install -g @beads/bd`, then verify with `bd version`.

**No `.beads` directory** — Run `bd init` in your project directory. The plugin automatically handles duplicate hook detection.

**Double context injection** — The plugin detects `bd setup claude` hooks in project and global settings and automatically skips its own `bd prime` call. If you still see duplicates, run `bd setup claude --remove`.

**Stale plugin cache** — The cache doesn't update when you edit skill files locally. Either symlink the cache to your checkout:

```bash
rm -rf ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/{{ version }}
ln -s ~/workplace/beads-superpowers \
  ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/{{ version }}
```

Or reinstall. Note: `claude plugin update` has a known [cache bug](https://github.com/anthropics/claude-code/issues/14061) — the symlink is more reliable.

**Hook not firing** — Check the hook is executable: `chmod +x hooks/session-start`.

**Stale reminder hook after updating from ≤0.8.2** — Earlier versions registered a per-prompt `superpowers-reminder.sh` hook that no longer ships. See the migration one-liner in the README's [npx section](https://github.com/DollarDill/beads-superpowers#universal-fallback-npx).

**`bd dolt push` fails** — You need a Dolt remote configured first (`bd dolt remote add origin <url>`). If you don't need remote sync, the failure is harmless — beads works fine locally.
