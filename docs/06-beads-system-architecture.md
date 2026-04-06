# Beads System Architecture

> Deep dive analysis of [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.0
> Creator: Steve Yegge | License: MIT | 20,285 GitHub stars

## What Is Beads?

Beads (bd) is a **distributed, graph-aware issue tracker** designed as persistent memory for AI coding agents. Built on Dolt (a version-controlled SQL database), it provides hash-based collision-free IDs, cell-level merge for conflict-free multi-agent operation, dependency graphs, and a CLI-first interface optimised for agent consumption.

**Tagline:** "A memory upgrade for your coding agent"

**Key innovation:** Hash-based IDs + Dolt's cell-level merge enable seamless multi-agent concurrent development without central coordination. Multiple agents can create, update, and close issues simultaneously — Dolt merges their changes at the SQL cell level, not file-level.

**Stats:** v1.0.0 released April 3, 2026 | 1,419 files | ~252k lines of Go | 100+ CLI commands | 30+ releases in 6 months | 30+ contributors

## Repository Structure

```
beads/                              # 1,419 files total
├── cmd/bd/                         # CLI entry point + 100+ command files (Go/Cobra)
│   ├── main.go                     # Entry point, PersistentPreRun/PostRun
│   ├── context.go                  # CommandContext — 20+ global vars consolidated
│   ├── create.go                   # Issue creation (extensive flags)
│   ├── update.go                   # Issue updates (atomic claim, metadata merge)
│   ├── close.go                    # Issue closing (gate validation, auto-advance)
│   ├── show.go                     # Issue display (history, watch, routing)
│   ├── ready.go                    # Unblocked work query (recursive CTE)
│   ├── list.go                     # General listing (filtering, sorting, tree)
│   ├── search.go                   # Text search with extensive filtering
│   ├── dep.go                      # Dependency management (cycle detection)
│   ├── prime.go                    # AI context generation (~1-2k tokens)
│   ├── memory.go                   # Persistent memory system (KV store)
│   ├── formula.go                  # Workflow templates
│   ├── mol.go                      # Molecule commands (pour, wisp, bond)
│   ├── dolt.go                     # Dolt version control operations
│   ├── doctor.go                   # 20+ diagnostic checks
│   ├── init.go                     # Database initialisation
│   ├── setup/claude.go             # Claude Code hook installation
│   └── ... (70+ more command files)
│
├── internal/                       # Core libraries (~124k lines)
│   ├── beads/                      # Database discovery, redirect following
│   ├── types/                      # Issue, Dependency, Label, Comment, Event types
│   ├── storage/
│   │   ├── storage.go              # Master interface (DoltStorage)
│   │   ├── dolt/                   # Dolt SQL driver wrapper
│   │   ├── embeddeddolt/           # Embedded Dolt engine
│   │   │   └── schema/            # 26 SQL migration files (0001-0026)
│   │   ├── issueops/              # Issue CRUD operations
│   │   └── versioncontrolops/     # Version control integration
│   ├── config/                    # Configuration management (Viper)
│   ├── configfile/                # YAML config parser + credentials
│   ├── doltserver/                # Dolt server lifecycle (start/stop/status)
│   ├── hooks/                     # Git hook management
│   ├── git/                       # Git integration (worktree awareness)
│   ├── idgen/                     # Hash-based ID generation
│   ├── audit/                     # Audit trail and event logging
│   ├── compact/                   # Compaction (semantic memory decay)
│   ├── molecules/                 # Compound issue support
│   ├── formula/                   # Formula and expression evaluation
│   ├── query/                     # Query language parser
│   ├── telemetry/                 # OpenTelemetry observability
│   ├── routing/                   # Issue routing rules
│   ├── templates/                 # Agent and issue templates
│   ├── ui/                        # CLI output formatting
│   └── integration modules:       # Linear, Jira, GitHub, GitLab, ADO, Notion
│
├── integrations/
│   ├── beads-mcp/                 # Python MCP server (FastMCP 3.2.0)
│   ├── claude-code/               # Claude Code integration
│   └── junie/                     # Jira Universal Integration Engine
│
├── docs/                          # 40+ documentation files
├── tests/                         # Integration + regression tests
├── scripts/                       # Build, test, release automation
├── website/                       # Docusaurus documentation site
├── npm-package/                   # npm distribution (@beads/bd)
├── .agent/                        # Agent workflow definitions
├── .claude/                       # Claude Code hooks
├── .claude-plugin/                # Claude plugin resources
├── Makefile                       # Build targets
├── go.mod                         # Go 1.25.8
└── .goreleaser.yml                # Cross-platform release builds
```

## Database Architecture (Dolt)

### Storage Modes

| Mode | How It Works | When to Use |
|------|-------------|-------------|
| **Embedded** (default) | Dolt runs in-process, data in `.beads/embeddeddolt/` | Solo/small team, zero setup |
| **Server** | External `dolt sql-server`, MySQL protocol | Multi-writer, advanced queries |
| **Shared Server** | One server at `~/.beads/shared-server/`, one DB per project | Many projects, one machine |

### Core Tables (26 migrations)

**`issues`** — The main table with 60+ columns:

```sql
-- Core fields
id VARCHAR(255) PRIMARY KEY          -- Hash-based: bd-a1b2, bd-a3f8.1
title VARCHAR(500)
description TEXT
design TEXT                          -- Design decisions
acceptance_criteria TEXT              -- Testable conditions
notes TEXT                           -- Supplementary notes
status VARCHAR(32)                   -- open|in_progress|closed|deferred|blocked|pinned|hooked
priority INT (0-4)                   -- 0=Critical → 4=Backlog
issue_type VARCHAR(32)               -- task|bug|feature|epic|chore|decision|spike|story|milestone
assignee VARCHAR(255)

-- Audit trail
created_at, updated_at, closed_at DATETIME
created_by, owner VARCHAR(255)

-- External integration
external_ref VARCHAR(255)            -- gh-123, jira-PROJ-456
source_system VARCHAR(255)           -- linear|jira|ado|github

-- Advanced
spec_id VARCHAR(1024)                -- Reference to spec document
compaction_level INT                 -- Memory decay level (0-3+)
content_hash VARCHAR(64)             -- SHA-256 for change detection
work_type VARCHAR(32)                -- mutex|serial|parallel (concurrency model)
metadata JSON                        -- Flexible extension field
mol_type VARCHAR(32)                 -- Molecule type
ephemeral BOOLEAN                    -- Wisp (temporary) flag
due_at, defer_until DATETIME
-- Plus 16+ more specialised fields (rig, role_bead, hook_bead, agent_state, etc.)
```

**`dependencies`** — Relationship graph:

```sql
issue_id VARCHAR(255)                -- Source
depends_on_id VARCHAR(255)           -- Target
type VARCHAR(32)                     -- blocks|parent-child|related|discovered-from|
                                     -- supersedes|duplicates|replies_to|conditional-blocks
metadata JSON
PRIMARY KEY (issue_id, depends_on_id)
-- CASCADE delete from issues
```

**`labels`** — Tags and operational state:

```sql
issue_id VARCHAR(255)
label VARCHAR(255)                   -- "urgent", "docs", "dimension:value" for state
PRIMARY KEY (issue_id, label)
```

**`events`** — Complete audit trail:

```sql
id CHAR(36) PRIMARY KEY              -- UUID
issue_id VARCHAR(255)
event_type VARCHAR(32)               -- created|updated|closed|labeled|commented
actor VARCHAR(255)
old_value, new_value TEXT            -- Before/after for every change
comment TEXT
created_at DATETIME
```

**`comments`** — Threaded discussions:

```sql
id CHAR(36) PRIMARY KEY
issue_id, author VARCHAR(255)
text TEXT
created_at DATETIME
```

**`config`** — Key-value store (also used for memories):

```sql
key VARCHAR(255) PRIMARY KEY
value TEXT
```

**Additional tables:** `child_counters`, `issue_counter`, `interactions`, `federation_peers`, `routes`, `repo_mtimes`, `issue_snapshots`, `compaction_snapshots`, `wisps`, `wisp_auxiliary`, `custom_statuses`, `custom_status_types`

### Critical SQL Views

**`ready_issues`** — The heart of `bd ready`. Uses a recursive CTE:

1. Find all issues with `status='open'` (or custom active statuses)
2. NOT blocked by any non-closed/non-pinned blocker (direct or transitive through parent-child, up to depth 50)
3. NOT ephemeral
4. NOT deferred (`defer_until <= NOW`)
5. NOT having a deferred parent

**`blocked_issues`** — Issues with at least one open blocker (considering custom done/frozen statuses)

### How Dolt Powers Beads

| Dolt Feature | How Beads Uses It |
|-------------|------------------|
| **Version control** | Every write auto-commits to Dolt history |
| **Cell-level merge** | Conflicts resolved at SQL cell level, not file-based |
| **Time travel** | `bd show --as-of` queries any historical state |
| **Branching** | Separate sync branches for protected workflows |
| **Hash-based storage** | Enables content-addressed IDs with collision avoidance |
| **Push/pull** | `bd dolt push/pull` syncs via DoltHub, S3, GCS, Azure, filesystem |
| **Stored procedures** | `CALL DOLT_PUSH()`, `CALL DOLT_PULL()` for remote ops |

### .beads/ Directory (What Gets Committed vs What Stays Local)

```
.beads/
  config.yaml          # COMMITTED — Project configuration
  metadata.json        # COMMITTED — Backend metadata (Dolt mode, DB name, UUID)
  README.md            # COMMITTED — Auto-generated README
  .gitignore           # COMMITTED — Separates committed from local
  hooks/               # COMMITTED — 5 git hooks (pre-commit, prepare-commit-msg,
                       #              post-merge, pre-push, post-checkout)

  embeddeddolt/        # LOCAL (gitignored) — The actual Dolt database
  backup/              # LOCAL — JSONL + Dolt archive backups
  interactions.jsonl   # LOCAL — Append-only audit trail
  last-touched         # LOCAL — Last-touched issue ID
  .local_version       # LOCAL — Prevents upgrade nag
  .env                 # LOCAL — Per-project Dolt credentials
  PRIME.md             # LOCAL (optional) — Custom prime output override
  formulas/            # LOCAL — Project-level formula templates
```

**Key insight:** The issue data itself (the Dolt database) is NOT committed to git. It syncs separately via `bd dolt push/pull`. Only the configuration, hooks, and metadata are committed.

## ID Generation (Hash-Based)

Beads uses content-hashed IDs with a configurable prefix:

```
beads-superpowers-hha    # prefix: "beads-superpowers", hash: "hha"
beads-superpowers-v74    # prefix: "beads-superpowers", hash: "v74"
```

**Why hash-based IDs?**
- No central counter needed — agents can create IDs independently
- No collision in concurrent multi-agent scenarios (Dolt merge handles any unlikely collisions)
- IDs are short but unique within the project
- Epic children get hierarchical IDs: `bd-a3f8.1`, `bd-a3f8.2`

The collision probability analysis is documented in `docs/COLLISION_MATH.md`.

## CLI Architecture (Go/Cobra)

### Entry Point Flow

```
main.go → PersistentPreRun:
  1. Create CommandContext (consolidates 20+ global vars)
  2. Signal-aware context (graceful shutdown on SIGTERM/SIGHUP)
  3. Initialise OpenTelemetry tracing
  4. Load .beads/.env for credentials
  5. Apply viper config (flags > config > defaults)
  6. Early return for no-DB commands (init, version, prime, doctor, setup, etc.)
  7. Auto-discover .beads/ directory
  8. Resolve actor: --actor flag > BEADS_ACTOR env > BD_ACTOR env > git user.name > $USER
  9. Open Dolt store (embedded or server mode)
  10. Wrap store with hook-firing decorator
  11. Load molecule templates

→ Command execution

→ PersistentPostRun:
  1. Dolt auto-commit if writes occurred
  2. Auto-backup, auto-export, auto-push
  3. Store close, OTel shutdown, profiling cleanup
```

### Read-Only vs Write Commands

Read-only commands open the store in read-only mode to avoid triggering file watchers: `list`, `ready`, `show`, `stats`, `blocked`, `count`, `search`, `graph`, `duplicates`, `comments`, `backup`, `export`.

All other commands open in read-write mode and trigger auto-commit in PostRun.

## Configuration Layers

Three layers with clear priority:

| Layer | File | Scope | Contents |
|-------|------|-------|---------|
| **CLI flags** | N/A | Per-invocation | `--json`, `--actor`, `--readonly` |
| **Environment** | `.beads/.env` | Per-project | `DOLT_USER`, `BEADS_ACTOR` |
| **Config** | `.beads/config.yaml` | Per-project/team | Prefix, sync, validation, routing |
| **Metadata** | `.beads/metadata.json` | Per-project | Dolt mode, DB name, project ID |
| **Database** | `config` table | Per-project (runtime) | Issue prefix, KV store, memories |

Priority: CLI flags > environment > config.yaml > metadata.json > database defaults.

## Integrations

### External Tracker Sync

| Tracker | Module | Capability |
|---------|--------|-----------|
| Jira | `internal/jira/` | Two-way sync |
| Linear | `internal/linear/` | Full sync |
| GitHub Issues | `internal/github/` | Import + sync |
| GitLab | `internal/gitlab/` | Work items sync |
| Azure DevOps | `internal/ado/` | Board sync |
| Notion | `internal/notion/` | Page integration |

### MCP Server

A Python FastMCP server (`integrations/beads-mcp/`) published on PyPI as `beads-mcp`. Exports tools for: list, create, update, close, show dependencies, search, query, export, import. Adds ~10-50k tokens of schema overhead per session (which is why the CLI approach is preferred for agents).

### Federation

Peer-to-peer issue federation between beads instances. No central server required. Configured via `bd federation` commands.

---

**Next:** [07-beads-cli-and-workflow.md](./07-beads-cli-and-workflow.md) — Complete CLI reference and workflow patterns
