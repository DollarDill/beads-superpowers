# Beads Design Patterns & Ecosystem

> Advanced features, the molecule/formula system, community ecosystem, and integration opportunities

## Design Pattern 1: Compaction (Semantic Memory Decay)

Beads implements **memory decay** for closed issues — reducing token overhead as issues age:

```
Tier 1 (30 days old, ≤2 dependency levels):  Summarise description
Tier 2 (90 days old, ≤5 dependency levels):  Further compress
Tier 3+:                                      Minimal stub
```

**Why this matters for agents:** Without compaction, a project with 500+ closed issues would consume enormous tokens just listing them. Compaction preserves the essential context (what was done, why) while shedding implementation details.

**Commands:**
- `bd compact` — Run compaction
- `bd gc` — Full lifecycle: decay + compact + garbage collection
- `bd restore <id>` — Restore compacted issue from Dolt history (time travel!)
- `bd config set auto_compact_enabled true` — Enable automatic compaction

## Design Pattern 2: Molecules & Formulas (Workflow Templates)

### What Are Formulas?

Formulas are YAML/TOML/JSON workflow templates that define repeatable patterns of work. Think of them as "issue factories" that create a structured set of beads with dependencies.

**Example use case:** Every new feature follows the same pattern: design spec → implementation plan → TDD implementation → code review → deploy. Instead of manually creating 5 beads every time, you define a formula once and `pour` it.

### Formula Structure

```yaml
# .beads/formulas/feature-workflow.yaml
name: feature-workflow
type: workflow
description: Standard feature development workflow
variables:
  feature_name:
    description: Name of the feature
    required: true
  priority:
    description: Priority level
    default: "2"
    enum: ["0", "1", "2", "3", "4"]

steps:
  - id: design
    title: "Design: {{feature_name}}"
    type: task
    priority: "{{priority}}"
    description: "Create design spec for {{feature_name}}"

  - id: plan
    title: "Plan: {{feature_name}}"
    type: task
    depends_on: [design]
    description: "Write implementation plan"

  - id: implement
    title: "Implement: {{feature_name}}"
    type: task
    depends_on: [plan]
    description: "TDD implementation"

  - id: review
    title: "Review: {{feature_name}}"
    type: task
    depends_on: [implement]
    description: "Code review"
```

### Formula Types

| Type | Purpose |
|------|---------|
| `workflow` | Ordered steps with dependencies |
| `expansion` | Template that expands into multiple issues |
| `aspect` | Cross-cutting concern applied to other formulas |
| `convoy` | Multiple formulas coordinated together |

### Formula Operations

```bash
bd formula list                    # List available templates
bd formula show <name>             # Show formula details
bd mol pour <name>                 # Create persistent issues from formula
bd mol wisp <name>                 # Create ephemeral (temporary) issues
bd mol bond <mol1> <mol2>          # Combine molecules
bd mol distill <epic-id>           # Extract formula from ad-hoc work pattern
bd mol squash <mol-id>             # Compress to digest
bd mol burn <mol-id>               # Discard ephemeral molecule
bd mol progress <mol-id>           # Check completion status
bd cook <formula>                  # Compile formula into proto (dry run)
```

### Composition System

Formulas support composition via:
- **`extends`** — Inherit from another formula
- **`compose`** — Combine multiple formulas
- **`aspects`** — Apply cross-cutting concerns (like adding "security review" to every workflow)
- **`pointcuts`** — Hook into specific steps of another formula
- **`advice rules`** — before/after/around modification of steps

This is a full aspect-oriented programming model for workflow templates.

## Design Pattern 3: Gates (Async Coordination)

Gates are checkpoints that block issue progress until an external condition is met:

| Gate Type | Trigger |
|-----------|---------|
| `human` | Manual resolution by a human |
| `timer` | Auto-expire after duration |
| `gh:run` | GitHub Actions workflow completion |
| `gh:pr` | Pull request merge |
| `bead` | Another bead's closure (cross-rig) |

**Example:** An implementation bead has a `gh:run` gate that waits for CI to pass before the review bead can start.

```bash
bd gate list                       # Show open gates
bd gate check                      # Evaluate and auto-close resolved gates
bd gate resolve <id>               # Manually close
bd gate discover                   # Find await_id for gh:run gates
```

## Design Pattern 4: Swarms (Parallel Multi-Agent Work)

For epics with many independent children:

```bash
bd swarm create <epic-id>          # Create swarm from epic
bd swarm list                      # List active swarms
bd swarm status <swarm-id>         # Check swarm progress
bd swarm validate <epic-id>        # Validate epic is swarm-compatible
```

Swarms coordinate multiple agents working on independent subtasks of the same epic. Hash-based IDs and Dolt's cell-level merge handle the concurrent writes.

## Design Pattern 5: Labels as Operational State

Labels in beads serve double duty:
1. **Tags:** `urgent`, `docs`, `frontend` — standard categorisation
2. **Dimensional state:** `review:pending`, `deploy:staging`, `qa:passed` — operational state tracking

The `dimension:value` pattern enables rich state machines without adding columns to the schema:

```bash
bd label add <id> "review:pending"
bd label add <id> "review:approved"     # Replaces pending
bd set-state <id> deploy=staging        # Shorthand
bd state <id> deploy                    # Query: "staging"
```

## Design Pattern 6: Audit Trail for Training Data

The `events` table records every mutation with before/after values:

```sql
-- Every create, update, close, label change, comment
id | issue_id | event_type | actor | old_value | new_value | created_at
```

Plus the `interactions.jsonl` file provides an append-only record for SFT/RL fine-tuning:

```bash
bd audit record                    # Append interaction entry
bd audit label <entry-id> <label>  # Label for training classification
```

This makes beads not just a tracker but a **data collection system for improving agent behaviour**.

## Design Pattern 7: Adaptive Context via `bd prime`

The `bd prime` output adapts to the environment:

| Context | Adaptation |
|---------|-----------|
| MCP mode detected | Minimal output (~50 tokens) |
| CLI mode | Full command reference (~1-2k tokens) |
| Stealth mode | Skip git push instructions |
| Ephemeral branch | Adjust close protocol |
| No remote configured | Skip push instructions |
| Custom PRIME.md exists | Use custom output entirely |

This means the same `bd prime` command works correctly in every environment without the agent needing to know which environment it's in.

## Community Ecosystem

### Official Integrations

| Integration | Status | Description |
|-------------|--------|-------------|
| Claude Code | Production | SessionStart/PreCompact hooks, `bd setup claude` |
| GitHub Copilot | Documented | `docs/COPILOT_INTEGRATION.md` |
| MCP Server | PyPI published | `beads-mcp` (FastMCP 3.2.0) |
| Jira | Production | Two-way sync |
| Linear | Production | Full sync |
| GitHub Issues | Production | Import + sync |
| GitLab | Production | Work items sync |
| Azure DevOps | Production | Board sync |
| Notion | Production | Page integration |

### Community Tools

| Tool | Description |
|------|-------------|
| `bdh` | Transparent wrapper: work claiming, file reservation, presence awareness, web dashboard |
| `nvim-beads` | Neovim plugin for in-editor bead management |
| `beads_skill` (mcoquet) | Third-party Claude Code skill |
| `beads_rust` | Rust port (Dicklesworthstone) |
| Various terminal UIs | Kanban boards, tree views |

### Distribution Channels

| Channel | Command |
|---------|---------|
| Homebrew | `brew install beads` |
| npm | `npm install -g @beads/bd` |
| PyPI | `pip install beads-mcp` (MCP server) |
| go install | `go install github.com/steveyegge/beads/cmd/bd` |
| Shell script | `curl -fsSL .../install.sh \| bash` |
| Nix | `flake.nix` present |
| WinGet | Windows package manager |
| GoReleaser | Cross-platform binaries on GitHub Releases |

## Ecosystem Maturity Assessment

### Strengths

1. **Battle-tested:** 30+ releases, 20k+ stars, acknowledged by Anthropic
2. **Active development:** 5 commits on April 6, 2026 (today); weekly release cadence
3. **Comprehensive documentation:** 40+ docs, Docusaurus site, 280KB CHANGELOG
4. **Real contributor ecosystem:** 30+ contributors, Jordan Hubbard (FreeBSD co-founder)
5. **Integration breadth:** 6 external trackers + 3 editor integrations + MCP
6. **Zero external runtime dependencies:** Embedded Dolt runs in-process

### Known Challenges

1. **Complexity trajectory:** GitHub issue #2938 ("Beads feels painful to use") and HN alternatives (Ticket, Trekker, Beans) suggest friction for some users
2. **Single-maintainer risk:** Steve Yegge accounts for ~85% of commits
3. **Org transition:** Move from `steveyegge/beads` to `gastownhall/beads` broke some URLs and `go install`
4. **Embedded Dolt is new:** v1.0.0 was gated on embedded Dolt completion; stability is still proving out
5. **Doctor command unavailable in embedded mode** — limits self-diagnosis

### The Beads Influence on the Industry

Anthropic engineer explicitly stated: "We took inspiration from projects like Beads by Steve Yegge." Claude Code's native task system (v2.1.16+) implements a similar pattern. This validates beads' core design — the best ideas are being absorbed into the platforms themselves.

## Beads + Superpowers: The Integration Opportunity

The previous analysis (docs 01-05) identified 7 gaps in Superpowers. Beads fills most of them:

| Superpowers Gap | Beads Solution |
|----------------|---------------|
| No persistent issue tracking (TodoWrite is session-scoped) | `bd create/update/close` — persistent, version-controlled |
| No knowledge management | `bd remember` — persistent memories injected every session |
| No session close protocol | "Land the Plane" — mandatory push ritual |
| No plan update mid-execution | `bd update` — modify issues on the fly |
| TodoWrite loses state on session end | Beads survives indefinitely (Dolt DB) |
| No audit trail | `events` table + `interactions.jsonl` |
| No cross-session context | `bd prime` — automatically provides full context at session start |

### The Vision: Superpowers + Beads

Replace every `TodoWrite` call in Superpowers skills with `bd` commands:

```
TodoWrite("Task 1: Implement login")    →  bd create "Implement login" -t task
TodoWrite("Task 1: ✓")                 →  bd close <id> -r "Implemented login"
TodoWrite("Task 2: in progress")       →  bd update <id> --claim
```

Every task in a plan becomes a bead. Every dependency is tracked in the graph. Every session starts with context via `bd prime`. Every session ends with the "Land the Plane" protocol.

The result: **persistent, auditable, dependency-aware, multi-session workflow tracking** that survives across sessions, agents, and projects.

---

## Sources

All analysis sourced from:
- **Repository:** https://github.com/gastownhall/beads (v1.0.0)
- **Clone:** /tmp/beads-analysis/
- **Live instance:** /home/dfrawley/workplace/beads-superpowers/.beads/
- **GitHub API:** `gh repo view`, `gh issue list`, `gh release list`
- **Web research:** Better Stack guide, paddo.dev, bruton.ai, Hacker News discussions, Medium articles by Steve Yegge
- **Key files:** `cmd/bd/main.go`, `cmd/bd/prime.go`, `cmd/bd/memory.go`, `cmd/bd/create.go`, `cmd/bd/ready.go`, `internal/storage/storage.go`, `internal/storage/embeddeddolt/schema/0025_update_ready_issues_view.up.sql`
