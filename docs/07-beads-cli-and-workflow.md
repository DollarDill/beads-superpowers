# Beads CLI Reference & Workflow Patterns

> Complete command reference, workflow patterns, and the "Land the Plane" protocol

## CLI Command Groups (100+ commands)

### Issue Lifecycle

| Command | Aliases | Purpose |
|---------|---------|---------|
| `bd create [title]` | `bd new` | Create issue |
| `bd update [id...]` | | Update issues (atomic claim, metadata merge) |
| `bd close [id...]` | `bd done` | Close issues (gate validation, auto-advance) |
| `bd reopen [id...]` | | Reopen closed issues |
| `bd delete [id...]` | | Delete permanently |
| `bd show [id...]` | `bd view` | Display details (history, watch, routing) |
| `bd assign` | | Assign issue |
| `bd priority` | | Set priority |
| `bd note` | | Append notes |
| `bd comment <id> [text]` | | Add comment |
| `bd tag` | | Add label |
| `bd label` | | Full label management (add/remove/list/propagate) |

### Key Create Flags

```bash
bd create "Title" \
  -t task|bug|feature|epic|chore|decision|spike|story|milestone \
  -p 0|1|2|3|4 \                    # P0=Critical → P4=Backlog
  -d "Description" \                 # Why this exists
  -a "assignee" \                    # Who owns it
  -l "label1,label2" \               # Tags
  --parent <epic-id> \               # Parent epic
  --deps <id1>,<id2> \               # Dependencies
  --acceptance "criteria" \           # Testable acceptance criteria
  --design "decisions" \              # Design decisions
  --notes "context" \                 # Supplementary notes
  --due "2026-04-15" \               # Due date
  --defer "2026-04-10" \             # Defer until date
  --validate \                        # Check description quality
  --dry-run \                        # Preview without creating
  --file <markdown> \                # Batch create from file
  --graph <json> \                   # Create issue DAG from JSON
  --ephemeral \                      # Temporary/wisp issue
  --external-ref "gh-123" \          # Link to external tracker
  --estimate "2h" \                  # Time estimate
  --spec-id "path/to/spec.md"       # Reference spec document
```

### Key Update Flags

```bash
bd update <id> \
  --claim \                          # Atomic: sets assignee + status=in_progress
  --title "New title" \
  --description "New desc" \
  --notes "Append to notes" \
  --design "Design decisions" \
  --add-label "new-label" \
  --remove-label "old-label" \
  --metadata '{"key": "value"}' \    # Merge (not replace) metadata
  --persistent \                     # Convert wisp to permanent
  --no-history                       # Skip audit trail for this update
```

### Key Close Flags

```bash
bd close <id1> <id2> ... \           # Close multiple at once
  -r "Completed: description" \      # Reason (for audit trail)
  --suggest-next \                   # Show newly unblocked issues
  --claim-next \                     # Auto-claim next ready issue
  --continue \                       # Auto-advance to next molecule step
  -f \                               # Force: override gates/blockers
  --session "session-id"             # Session tracking
```

### Work Discovery

| Command | Purpose | Key Flags |
|---------|---------|-----------|
| `bd ready` | **Unblocked, unclaimed work** | `--explain`, `--sort priority\|hybrid\|oldest`, `--unassigned`, `--mol`, `--gated` |
| `bd list` | General listing with filtering | `--status`, `--type`, `--priority`, `--assignee`, `--label`, `--sort`, `--tree`, `--flat`, `--watch` |
| `bd search [query]` | Text search across title/ID | `--desc-contains`, `--no-assignee`, `--metadata-field`, date ranges |
| `bd query [expr]` | Structured query language | `status=open AND priority<=2 AND updated>7d` |
| `bd blocked` | Issues with open blockers | |
| `bd stale` | Inactive issues | Configurable days threshold |
| `bd count` | Count matching issues | Same filters as list |
| `bd todo` | Personal todo (user-assigned) | |
| `bd stats` | Project health dashboard | Open/in-progress/blocked/closed counts |

### Dependencies

| Command | Purpose |
|---------|---------|
| `bd dep add <child> <depends-on>` | Create blocking dependency |
| `bd dep add <child> <depends-on> --type parent-child` | Parent-child hierarchy |
| `bd dep remove` | Remove dependency |
| `bd dep list <id>` | List deps/dependents |
| `bd dep tree <id>` | Visualise dependency tree |
| `bd dep cycles` | Detect circular dependencies |
| `bd dep relate` | Bidirectional relates_to link |

**Dependency types:** `blocks`, `parent-child`, `related`, `discovered-from`, `supersedes`, `duplicates`, `replies_to`, `conditional-blocks`

Only `blocks` and `parent-child` affect `bd ready` calculations.

### Dolt Version Control

| Command | Purpose |
|---------|---------|
| `bd dolt push` | Push to Dolt remote (DoltHub, S3, GCS, Azure, filesystem) |
| `bd dolt pull` | Pull from Dolt remote |
| `bd dolt commit` | Explicit commit (when auto-commit: off) |
| `bd dolt show` | Show uncommitted changes |
| `bd dolt status` | Check server status |
| `bd dolt start/stop` | Server lifecycle |
| `bd dolt remote add/list/remove` | Remote management |

### Memory System

| Command | Purpose |
|---------|---------|
| `bd remember "insight"` | Store persistent memory (auto-slugified key) |
| `bd remember "insight" --key explicit-key` | Store with explicit key |
| `bd memories [keyword]` | List/search all memories |
| `bd recall <key>` | Retrieve specific memory |
| `bd forget <key>` | Remove a memory |

**How it works:** Stored in the `config` table with key prefix `kv.memory.`. Memories are injected into `bd prime` output, so they appear in every session automatically.

### Molecule/Formula System

| Command | Purpose |
|---------|---------|
| `bd formula list` | List available workflow templates |
| `bd formula show <name>` | Show formula details |
| `bd mol pour <name>` | Instantiate formula as persistent issues |
| `bd mol wisp` | Instantiate as ephemeral (temporary) issues |
| `bd mol bond` | Combine molecules |
| `bd mol distill` | Extract formula from ad-hoc epic |
| `bd mol squash` | Compress molecule |
| `bd mol burn` | Discard wisp |
| `bd mol progress` | Show molecule completion |
| `bd cook` | Compile formula into proto |

Formula search paths: `.beads/formulas/` (project) → `~/.beads/formulas/` (user) → `$GT_ROOT/.beads/formulas/` (orchestrator)

### Gate System (Async Coordination)

| Command | Purpose |
|---------|---------|
| `bd gate list` | Show open gates |
| `bd gate check` | Evaluate and auto-close resolved gates |
| `bd gate resolve <id>` | Manually close a gate |
| `bd gate discover` | Discover await_id for gh:run gates |

Gate types: `human` (manual), `timer` (auto-expire), `gh:run` (GitHub workflow), `gh:pr` (PR merge), `bead` (cross-rig bead close)

### Quality & Hygiene

| Command | Purpose |
|---------|---------|
| `bd lint [id...]` | Check issues for missing template sections |
| `bd stale` | Find inactive issues |
| `bd orphans` | Find broken dependencies |
| `bd preflight` | Pre-PR readiness checklist |
| `bd doctor [--check=...]` | 20+ diagnostic checks |
| `bd duplicates` | Find duplicate issues |
| `bd find-duplicates` | AI-powered semantic duplicate detection |

### Graph Visualisation

```bash
bd graph [id]           # Terminal DAG (default)
bd graph --box          # ASCII boxes with layers
bd graph --compact      # Tree format
bd graph --dot          # Graphviz DOT output
bd graph --html         # Interactive D3.js HTML
bd graph --all          # All open issues
bd graph check          # Check graph integrity
```

### Other Notable Commands

| Command | Purpose |
|---------|---------|
| `bd q "title"` | Quick capture — create and output only ID |
| `bd human list/respond/dismiss` | Human-needed bead triage |
| `bd worktree create/list/remove` | Git worktree management with beads redirect |
| `bd swarm create/list/status` | Parallel work coordination |
| `bd epic status/close-eligible` | Epic management |
| `bd compact/gc` | History compaction and garbage collection |
| `bd export/import` | JSONL export/import |
| `bd backup init/sync/restore` | Database backup management |
| `bd kv set/get/clear/list` | General key-value store |
| `bd audit record/label` | Audit trail for SFT/RL training data |

### Global Flags

```bash
--json           # JSON output (every command)
--flat           # Machine-parseable output
--quiet / -q     # Errors only
--verbose / -v   # Debug output
--actor <name>   # Override actor for audit trail
--db <path>      # Database path override
--readonly       # Block write operations
--sandbox        # Disable auto-sync
```

## Statuses and Types

### Built-In Statuses

| Status | Symbol | Category | Description |
|--------|--------|----------|-------------|
| `open` | circle | active | Available to work (default) |
| `in_progress` | half-circle | wip | Actively being worked on |
| `blocked` | filled-circle | wip | Blocked by dependency |
| `deferred` | snowflake | frozen | Deliberately set aside |
| `closed` | checkmark | done | Completed |
| `pinned` | pin | frozen | Persistent, stays open indefinitely |
| `hooked` | diamond | wip | Attached to agent's hook |

Custom statuses configurable via `bd config set status.custom "name:category,..."`.

### Built-In Types

`task`, `bug`, `feature`, `chore`, `epic`, `decision`, `spike`, `story`, `milestone`

Custom types via `bd config set types.custom "type1,type2,..."`.

### Priorities

| Priority | Meaning | Aliases |
|----------|---------|---------|
| 0 | Critical | P0 |
| 1 | High | P1 |
| 2 | Medium (default) | P2 |
| 3 | Low | P3 |
| 4 | Backlog | P4 |

## Core Workflow Patterns

### Starting Work

```bash
bd ready                    # Find unblocked work
bd show <id>                # Review issue details
bd update <id> --claim      # Claim it (sets assignee + status=in_progress)
```

### Creating Dependent Work

```bash
bd create "Implement feature X" -t feature -p 2
bd create "Write tests for X" -t task -p 2
bd dep add <test-id> <feature-id>    # Tests depend on Feature
```

### Completing Work

```bash
bd close <id1> <id2> ...              # Close all completed issues
bd close <id> -r "Implemented X"      # Close with reason
bd close <id> --suggest-next          # Show newly unblocked issues
```

### The "Land the Plane" Protocol

**Every session must end with this ritual. Work is NOT complete until `git push` succeeds.**

```bash
# 1. File remaining work as new beads
bd create "Remaining work: ..." -t task -p 2

# 2. Run quality gates (if code changed)
npm test / cargo test / etc.

# 3. Close completed beads
bd close <id1> <id2> ... -r "Description of what was done"

# 4. Push beads to Dolt remote
bd dolt push

# 5. Push code to git remote
git pull --rebase && git push

# 6. Verify clean state
git status    # MUST show "up to date with origin"
```

### Epic/Sub-Task Pattern

```bash
bd create "Epic: Build auth system" -t epic -p 1
# Returns: bd-auth-abc

bd create "Add login endpoint" -t task --parent bd-auth-abc
bd create "Add session management" -t task --parent bd-auth-abc
bd create "Write integration tests" -t task --parent bd-auth-abc
bd dep add <tests-id> <login-id>      # Tests depend on login endpoint
```

### Discovery Pattern

When work on one issue reveals new work:

```bash
bd create "Fix discovered race condition" -t bug -p 1
bd dep add <new-bug-id> <original-task-id> --type discovered-from
```

## The `bd prime` Command

The critical agent integration point. Outputs ~1-2k tokens of structured markdown containing:

1. **Session close protocol** — Mandatory git push checklist
2. **Core rules** — Use beads for ALL tracking; prohibited alternatives (TodoWrite, TaskCreate, markdown)
3. **Essential commands** — Finding work, creating, updating, dependencies, sync, health, quality, lifecycle
4. **Common workflows** — Starting work, completing work, creating dependent work
5. **Persistent memories** — All stored `bd remember` entries

The output adapts to context:
- **MCP mode** (~50 tokens): Minimal, assumes MCP tools available
- **CLI mode** (~1-2k tokens): Full command reference
- **Stealth mode**: Skips git push instructions
- **Ephemeral branch**: Adjusts close protocol
- **No remote**: Skips push instructions
- **Custom override**: `.beads/PRIME.md` replaces default output

Injected at session start via Claude Code's `SessionStart` hook, and refreshed before context compaction via `PreCompact` hook.

## Git Integration

### Installed Hooks (5)

All hooks follow an identical pattern:
1. Check if `bd` is installed
2. Set `BD_GIT_HOOK=1` environment variable
3. Run `bd hooks run <hook-name>` with configurable timeout (300s default)
4. Handle timeout gracefully (continue without beads)
5. Handle exit code 3 (database not initialised — skip gracefully)

| Hook | Fires When |
|------|-----------|
| `pre-commit` | Before git commit |
| `prepare-commit-msg` | Before commit message editor |
| `post-merge` | After git merge |
| `pre-push` | Before git push |
| `post-checkout` | After git checkout |

### Worktree Support

```bash
bd worktree create <name>    # Create git worktree with beads redirect
bd worktree list             # List worktrees
bd worktree remove <name>    # Remove worktree
bd worktree info             # Show worktree context
```

Worktrees automatically get a `.beads/redirect` file pointing back to the main `.beads/` database, so all worktrees share the same issue state.

---

**Next:** [08-beads-agent-optimization.md](./08-beads-agent-optimization.md) — Why beads is the most optimised agentic PM solution
