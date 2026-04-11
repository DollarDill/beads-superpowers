# beads-superpowers

**Superpowers skills + Beads issue tracking** — a Claude Code plugin that gives AI coding agents a complete, persistent development workflow.

Every task is a bead. Every session starts with context. Every session ends with a push.

## What Is This?

This plugin merges two proven systems into one:

- **[Superpowers](https://github.com/obra/superpowers)** (v5.0.7) — 15 composable skills that enforce professional software development workflows: brainstorming, TDD, systematic debugging, two-stage code review, and more. Created by Jesse Vincent.
- **[Beads](https://github.com/gastownhall/beads)** (v1.0.0) — A persistent, Dolt-backed issue tracker designed as memory for AI coding agents. Hash-based IDs, dependency graphs, and cross-session persistence. Created by Steve Yegge.

The result: skills that don't just tell agents *how* to work — they give agents a persistent ledger to track *what* they're working on, across sessions, with full audit trails and dependency awareness.

## Why?

AI coding agents have two problems:

1. **No process discipline.** Without explicit workflow enforcement, agents skip tests, rush to code, and claim work is done without verification. Superpowers solves this with 15 mandatory skills backed by empirically-tested anti-rationalization techniques.

2. **No persistent memory.** When a session ends, todo lists vanish. Task context disappears. The next session starts blind. Beads solves this with a version-controlled SQL database that survives across sessions, agents, and projects.

Neither system alone is complete. Together, they are.

## Quick Start

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) installed
- [Beads](https://github.com/gastownhall/beads) installed (`brew install beads` or `npm install -g @beads/bd`)

### Install the Plugin

```bash
# Step 1: Add the marketplace (one-time setup)
claude plugin marketplace add DollarDill/beads-superpowers

# Step 2: Install the plugin
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

> **Note:** You can also run these as slash commands inside Claude Code: `/plugin marketplace add DollarDill/beads-superpowers` and `/plugin install beads-superpowers@beads-superpowers-marketplace`

### Initialize Beads in Your Project

```bash
cd your-project
bd init
```

### Remove Duplicate Hooks (Important)

The plugin's SessionStart hook already runs `bd prime`. If you previously ran `bd setup claude`, remove the duplicate hooks:

```bash
bd setup claude --remove
```

If you skip this step, the plugin will detect the duplication and warn you.

### Verify Installation

```bash
# Check plugin is loaded (in Claude Code)
/skills

# You should see skills prefixed with beads-superpowers:
#   beads-superpowers:brainstorming
#   beads-superpowers:test-driven-development
#   beads-superpowers:systematic-debugging
#   ... (15 skills total)
```

## How It Works

### Session Lifecycle

```text
Session Start
  │
  ▼
SessionStart hook fires automatically
  ├── Injects using-superpowers skill (skill routing + beads awareness)
  └── Runs bd prime (beads CLI context + persistent memories)
  │
  ▼
Agent receives task from user
  │
  ▼
Skill system activates
  ├── brainstorming → design spec → user approval
  ├── writing-plans → implementation plan → beads created for each task
  ├── subagent-driven-development → execute tasks → two-stage review
  │     └── Per task: bd create → bd update --claim → implement → bd close
  └── finishing-a-development-branch → merge/PR → Land the Plane
  │
  ▼
Land the Plane (mandatory session close)
  ├── bd close <completed-beads> --reason "description"
  ├── bd dolt push (sync beads to Dolt remote)
  ├── git push (sync code to remote)
  └── git status (verify clean state)
```

### Every Task Is a Bead

When an agent executes an implementation plan, each task becomes a bead:

```bash
# Plan has 5 tasks → 5 beads created
bd create "Epic: Authentication System" -t epic -p 2
bd create "Task 1: Login endpoint" -t task --parent <epic-id>
bd create "Task 2: Session management" -t task --parent <epic-id>
bd create "Task 3: JWT middleware" -t task --parent <epic-id>
bd dep add <task-3-id> <task-1-id>    # Task 3 depends on Task 1

# Agent works through tasks
bd update <task-1-id> --claim         # Start work
# ... implement, test, review ...
bd close <task-1-id> --reason "Implemented login with bcrypt hashing"

# Check what's next
bd ready --parent <epic-id>           # Shows unblocked tasks
```

### Skills Are Mandatory, Not Optional

The `using-superpowers` skill (loaded at every session start) enforces:

> **IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.**

Skills are not suggestions. They use bright-line rules, anti-rationalization tables, and empirically-tested enforcement language. See [docs/METHODOLOGY.md](docs/METHODOLOGY.md) for the research basis.

## Skills Reference

### The Happy Path Pipeline

```text
brainstorming → writing-plans → subagent-driven-development → finishing-a-development-branch
                                 (or executing-plans)
```

### All 15 Skills

| Skill | Category | When to Use |
|-------|----------|-------------|
| **using-superpowers** | Meta | Every session start — routes to the right skill |
| **brainstorming** | Design | Before any creative work — explores design before code |
| **writing-plans** | Planning | After design approval — creates bite-sized task plans |
| **subagent-driven-development** | Execution | Execute plans with fresh subagent per task + two-stage review |
| **executing-plans** | Execution | Execute plans in a single session with checkpoints |
| **test-driven-development** | Quality | Any feature or bugfix — RED-GREEN-REFACTOR cycle |
| **systematic-debugging** | Quality | Any bug or test failure — 4-phase root cause analysis |
| **verification-before-completion** | Quality | Before any "done" claim — evidence before assertions |
| **requesting-code-review** | Review | After implementation — dispatches code reviewer |
| **receiving-code-review** | Review | When receiving feedback — anti-sycophancy review reception |
| **using-git-worktrees** | Infrastructure | Isolated development branches with safety checks |
| **finishing-a-development-branch** | Infrastructure | Merge/PR decision tree + Land the Plane protocol |
| **dispatching-parallel-agents** | Advanced | 2+ independent tasks without shared state |
| **writing-skills** | Meta | Creating or modifying skills — TDD for process docs |
| **auditing-upstream-drift** | Meta | Periodic audit for staleness vs upstream superpowers and beads |

### Beads Commands Used in Skills

| Action | Command | Used In |
|--------|---------|---------|
| Create epic | `bd create "Epic: name" -t epic` | subagent-driven-dev, executing-plans |
| Create task | `bd create "Task: name" -t task --parent <epic>` | subagent-driven-dev, executing-plans |
| Claim work | `bd update <id> --claim` | executing-plans |
| Complete work | `bd close <id> --reason "description"` | all execution skills |
| Check remaining | `bd ready --parent <epic>` | subagent-driven-dev, executing-plans |
| Add dependency | `bd dep add <child> <parent>` | subagent-driven-dev, writing-plans |
| Store learning | `bd remember "insight"` | any session |
| Sync to remote | `bd dolt push` | finishing-a-development-branch |
| Session context | `bd prime` | SessionStart hook (automatic) |

## Project Structure

```text
beads-superpowers/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest (v0.1.0)
├── hooks/
│   ├── hooks.json               # SessionStart hook registration
│   ├── session-start            # Injects skills + runs bd prime
│   └── run-hook.cmd             # Windows polyglot wrapper
├── skills/
│   ├── brainstorming/           # 3 files — Socratic design refinement
│   ├── dispatching-parallel-agents/  # 1 file — Concurrent subagent workflows
│   ├── executing-plans/         # 1 file — Batch execution with checkpoints
│   ├── finishing-a-development-branch/  # 1 file — Merge/PR + Land the Plane
│   ├── receiving-code-review/   # 1 file — Anti-sycophancy review reception
│   ├── requesting-code-review/  # 2 files — Review dispatch
│   ├── subagent-driven-development/  # 4 files — Two-stage review orchestration
│   ├── systematic-debugging/    # 11 files — 4-phase root cause analysis
│   ├── test-driven-development/ # 2 files — RED-GREEN-REFACTOR
│   ├── using-git-worktrees/     # 1 file — Isolated development branches
│   ├── using-superpowers/       # 4 files — Bootstrap + beads awareness
│   ├── verification-before-completion/  # 1 file — Evidence before claims
│   ├── writing-plans/           # 2 files — Detailed implementation plans
│   ├── writing-skills/          # 6 files — Skill creation meta-skill
│   └── auditing-upstream-drift/ # 1 file  — Upstream staleness detection
├── agents/
│   └── code-reviewer.md         # Senior code reviewer agent
├── commands/
│   ├── brainstorm.md            # Deprecated → use brainstorming skill
│   ├── execute-plan.md          # Deprecated → use executing-plans skill
│   └── write-plan.md            # Deprecated → use writing-plans skill
├── docs/
│   ├── METHODOLOGY.md           # Design philosophy and research basis
│   ├── SETUP-GUIDE.md           # Detailed installation and configuration
│   ├── testing.md               # Test methodology
│   ├── windows/                 # Cross-platform hook docs
│   └── upstream-reference/      # Key design docs from upstream
├── tests/
│   ├── brainstorm-server/       # WebSocket server tests
│   ├── claude-code/             # Claude Code integration tests
│   ├── explicit-skill-requests/ # Skill explicit invocation tests
│   ├── skill-triggering/        # Automatic skill detection tests
│   └── subagent-driven-dev/     # End-to-end workflow tests
├── scripts/
│   └── bump-version.sh          # Version management across manifests
├── package.json
├── CLAUDE.md                    # Plugin development instructions
├── AGENTS.md                    # Agent instructions
├── LICENSE                      # MIT License
└── README.md                    # This file
```

## Development: Keeping Installed Plugin in Sync

When you edit skills in this repo, the installed plugin cache goes stale. Two options:

### Option A: Symlink (Recommended)

One-time setup — source changes take effect on next Claude Code restart.

```bash
rm -rf ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.1.0
ln -s ~/workplace/beads-superpowers \
  ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.1.0
```

### Option B: Nuke Cache

Quick one-shot refresh — Claude Code re-copies from marketplace on next start.

```bash
rm -rf ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/
```

### Verify Sync

```bash
# Should print nothing if in sync
diff -rq skills/ ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.1.0/skills/
```

> **Note:** `claude plugin update` exists but has a [cache invalidation bug](https://github.com/anthropics/claude-code/issues/14061). Use the symlink approach instead.

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Orchestrator-only beads** | Only the main agent manages beads. Subagents focus on implementation — no concurrent bead conflicts. |
| **Plugin subsumes bd hooks** | The plugin's SessionStart hook runs `bd prime` itself. No need for separate `bd setup claude` hooks. |
| **TodoWrite fully replaced** | Every TodoWrite reference is replaced with `bd` commands. Zero active TodoWrite usage. |
| **Land the Plane in finishing skill** | Session close protocol lives in the terminal skill, not a separate skill. Every pipeline path ends here. |
| **Skills are Markdown, not code** | Pure documentation — no build step, no dependencies, works on any platform with a file system. |

## Attribution

- **Superpowers skills** — [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent (MIT License)
- **Beads issue tracker** — [gastownhall/beads](https://github.com/gastownhall/beads) by Steve Yegge (MIT License)
- **beads-superpowers integration** — Dillon Frawley

## License

MIT
