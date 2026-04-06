# Superpowers System Architecture

> Deep dive analysis of [obra/superpowers](https://github.com/obra/superpowers) v5.0.7
> Author: Jesse Vincent (Prime Radiant) | License: MIT

## What Is Superpowers?

Superpowers is a **zero-dependency, composable skills library** for AI coding agents. It provides 14 skills that guide agents through professional software development workflows — from brainstorming through design, planning, TDD implementation, code review, and branch finishing. The system is platform-agnostic, supporting Claude Code, Cursor, Codex, OpenCode, GitHub Copilot CLI, and Gemini CLI.

**Philosophy:** Skills are not suggestions — they are mandatory process enforcement. The system uses aggressive anti-rationalization language and empirically-derived pressure testing to ensure agents follow workflows consistently.

**Key design constraints:**
- Zero third-party dependencies (zero-dep by design)
- Skills are process documentation, not code — all orchestration is through prose instructions
- No machine-readable dependency graph — the agent must parse natural language to determine workflow
- Platform-agnostic — a single skill corpus works across 6+ agent platforms

## Repository Structure

```
superpowers/                          # 170 files total (excluding .git)
├── README.md                         # Installation, workflow overview, philosophy
├── CLAUDE.md                         # Contributor guidelines (94% PR rejection rate)
├── GEMINI.md                         # Gemini CLI context file reference
├── CHANGELOG.md                      # Detailed version history
├── RELEASE-NOTES.md                  # Recent release notes
├── LICENSE                           # MIT
├── package.json                      # NPM metadata (v5.0.7, type: module)
├── gemini-extension.json             # Gemini CLI extension config
├── .version-bump.json                # Version sync across 5 files
│
├── .claude-plugin/                   # Claude Code official marketplace
│   ├── plugin.json                   # Plugin manifest (v5.0.7)
│   └── marketplace.json              # Dev marketplace config
│
├── .cursor-plugin/                   # Cursor IDE support
│   └── plugin.json                   # Plugin manifest (camelCase hooks)
│
├── .opencode/                        # OpenCode.ai support
│   ├── plugins/superpowers.js        # ES module auto-registration plugin
│   └── INSTALL.md                    # Installation guide
│
├── .codex/                           # Google Codex support
│   └── INSTALL.md                    # Symlink-based setup guide
│
├── hooks/                            # Platform-specific hook implementations
│   ├── hooks.json                    # Generic hooks (SessionStart for Windows)
│   ├── hooks-cursor.json             # Cursor-specific hooks
│   ├── session-start                 # Executable bash hook script
│   └── run-hook.cmd                  # Windows batch runner
│
├── skills/                           # 14 core skills (46 files, 456 KB)
│   ├── brainstorming/                # 8 files — Socratic design refinement
│   ├── dispatching-parallel-agents/  # 1 file  — Concurrent subagent workflows
│   ├── executing-plans/              # 1 file  — Batch execution with checkpoints
│   ├── finishing-a-development-branch/ # 1 file — Merge/PR/cleanup decisions
│   ├── receiving-code-review/        # 1 file  — Handling review feedback
│   ├── requesting-code-review/       # 2 files — Pre-review dispatch
│   ├── subagent-driven-development/  # 4 files — Fast iteration, two-stage review
│   ├── systematic-debugging/         # 11 files — 4-phase root cause analysis
│   ├── test-driven-development/      # 2 files — RED-GREEN-REFACTOR cycle
│   ├── using-git-worktrees/          # 1 file  — Isolated development branches
│   ├── using-superpowers/            # 4 files — Skill system bootstrap
│   ├── verification-before-completion/ # 1 file — Evidence before claims
│   ├── writing-plans/                # 2 files — Detailed implementation plans
│   └── writing-skills/               # 8 files — Skill creation meta-skill
│
├── commands/                         # 3 files — Deprecated slash commands
├── agents/                           # 1 file  — Code reviewer agent template
├── docs/                             # 15 files — Plans, specs, testing docs
├── scripts/                          # 1 file  — Version bump utility
├── tests/                            # 34 files — Comprehensive test suite
└── .github/                          # 5 files — CI, issue templates, PR template
```

## Plugin & Bootstrap Architecture

### How Skills Get Loaded

The bootstrap mechanism follows a two-stage process:

**Stage 1: Platform Registration** — Each platform has its own plugin manifest:

| Platform | Manifest File | Registration Method |
|----------|--------------|-------------------|
| Claude Code | `.claude-plugin/plugin.json` | Official marketplace auto-discovery |
| Cursor | `.cursor-plugin/plugin.json` | Plugin marketplace + camelCase hooks |
| Codex | `.codex/INSTALL.md` | Symlink: `~/.agents/skills/superpowers` -> `./skills/` |
| OpenCode | `.opencode/plugins/superpowers.js` | ES module auto-registration via config hook |
| Copilot CLI | `.claude-plugin/plugin.json` | Plugin registry |
| Gemini CLI | `gemini-extension.json` | Extension mechanism |

**Stage 2: SessionStart Hook** — At every session start, the `hooks/session-start` script:

1. Reads the entire `skills/using-superpowers/SKILL.md` content
2. Escapes it for JSON embedding
3. Wraps it in `<EXTREMELY_IMPORTANT>` tags to force attention
4. Outputs platform-specific JSON:
   - Claude Code: `{"hookSpecificOutput": {"additionalContext": "..."}}`
   - Cursor: `{"additional_context": "..."}`
   - Copilot CLI: `{"additionalContext": "..."}`
5. Checks for legacy `~/.config/superpowers/skills` directory and warns if found

**Critical insight:** Only `using-superpowers` is force-loaded at session start. All other 13 skills are invoked on-demand via the Skill tool. The `using-superpowers` skill contains a decision flowchart that tells the agent when to invoke which skill.

### Plugin Manifest (Claude Code)

```json
{
  "name": "superpowers",
  "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
  "version": "5.0.7",
  "author": {"name": "Jesse Vincent", "email": "jesse@fsck.com"},
  "skills": "./skills/",
  "agents": "./agents/",
  "commands": "./commands/",
  "hooks": "./hooks/hooks.json"
}
```

### Hook Configuration

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|clear|compact",
      "hooks": [{
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
        "async": false
      }]
    }]
  }
}
```

### Version Management

`.version-bump.json` defines 5 files that must stay in sync:
- `package.json`
- `.claude-plugin/plugin.json`
- `.cursor-plugin/plugin.json`
- `.claude-plugin/marketplace.json` (nested path)
- `gemini-extension.json`

The `scripts/bump-version.sh` utility handles this.

## Instruction Priority Model

The system defines a clear priority hierarchy:

```
1. User's explicit instructions (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests)  — HIGHEST
2. Superpowers skills — override default system behavior where they conflict
3. Default system prompt — LOWEST
```

This means a user can always override any skill instruction via their CLAUDE.md or direct request. Skills override the agent's default behaviour but not the user's intent.

## Skill Standard Structure

Every skill follows this standardised pattern:

```markdown
---
name: skill-name
description: Trigger condition — when to invoke this skill
---

# Skill Title

[Iron Law / Core Mandate — bold, absolute language]

## Process / Steps / Checklist
[Numbered steps with verification gates]

## Red Flags / Common Rationalizations
[Table of excuses with reality checks]

## Integration
[Cross-references to other skills: "Called by", "Pairs with", "REQUIRED SUB-SKILL"]
```

### Companion File Types

Some skills include supporting files beyond `SKILL.md`:

| File Type | Purpose | Examples |
|-----------|---------|---------|
| `*-prompt.md` | Subagent dispatch templates | `implementer-prompt.md`, `spec-reviewer-prompt.md` |
| `references/*.md` | Platform-specific tool mappings | `gemini-tools.md`, `codex-tools.md` |
| `scripts/*.sh` | Executable utilities | `start-server.sh`, `find-polluter.sh` |
| `*.cjs` / `*.js` | Server/helper code | `server.cjs` (brainstorming visual companion) |
| `test-pressure-*.md` | Adversarial test scenarios | Pressure scenarios for skill testing |

## File Counts

| Directory | Files | Purpose |
|-----------|-------|---------|
| `skills/` | 46 | Core skill implementations |
| `tests/` | 34 | Comprehensive test suite |
| `docs/` | 15 | Documentation & internal planning |
| `.github/` | 5 | CI, issue/PR templates |
| `hooks/` | 4 | Platform hook implementations |
| `commands/` | 3 | Deprecated slash commands |
| Root | 10 | Config, README, LICENSE |
| **Total** | **170** | |

Maximum directory depth: 4 levels (`tests/explicit-skill-requests/prompts/`).

## Testing Infrastructure

The test suite covers multiple dimensions:

- **`tests/brainstorm-server/`** — Jest tests for the visual brainstorming WebSocket server
- **`tests/explicit-skill-requests/`** — Tests that skills fire when explicitly requested via `/skill`
- **`tests/skill-triggering/`** — Tests that skills fire automatically when relevant
- **`tests/claude-code/`** — Claude Code integration tests (subagent-driven-dev, document review)
- **`tests/opencode/`** — OpenCode plugin loading and tool tests
- **`tests/subagent-driven-dev/`** — Full workflow scenarios (Svelte todo app, Go fractal renderer)

## Contributor Guidelines

The `CLAUDE.md` file enforces a **94% PR rejection rate** with these acceptance criteria:

- Zero third-party dependencies
- Genuine human involvement in code review
- Evidence-based changes to skills (not compliance rewrites)
- One problem per PR (no bulk updates)
- Real problems with specific error context (not theoretical)
- General-purpose skills only (domain-specific belongs in separate plugins)
- Changing "human partner" to "user" is explicitly forbidden

---

**Next:** [02-workflow-orchestration.md](./02-workflow-orchestration.md) — The happy path pipeline, dependency graph, and skill chaining
