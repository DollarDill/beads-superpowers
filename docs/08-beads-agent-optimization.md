# Why Beads Is the Most Optimised Agentic PM Solution

> Design decisions, comparison with alternatives, and what makes beads uniquely effective for AI coding agents

## The Core Problem Beads Solves

AI coding agents have **no persistent memory between sessions**. When a session ends:
- Todo lists vanish
- Task context disappears
- Dependencies are forgotten
- Work-in-progress has no audit trail
- The next session starts blind

Traditional issue trackers (Jira, Linear, GitHub Issues) solve persistence but are designed for humans, not agents:
- Web UIs add friction (agents need CLI/API)
- Token overhead is massive (MCP schemas: 10-50k tokens per session)
- No local-first operation (network dependency)
- No version-controlled data (no merge, no time travel)
- No hash-based IDs (sequential IDs cause conflicts in multi-agent scenarios)

**Beads bridges this gap:** persistent, agent-optimised, local-first, conflict-free, and token-efficient.

## Design Decisions That Make Beads Agent-Optimal

### 1. CLI-First, Not MCP-First

**Decision:** The primary interface is the `bd` CLI, not the MCP server.

**Why:**
- MCP tool schemas add **10-50k tokens** of overhead per session
- `bd prime` outputs **~1-2k tokens** — 10-50x more efficient
- CLI is universal across editors (Claude Code, Cursor, Windsurf, Zed)
- Every token costs compute, latency, and energy

**The MCP server exists** (`beads-mcp` on PyPI) for cases where CLI access isn't available, but CLI is strongly preferred.

### 2. Hash-Based IDs

**Decision:** Issue IDs are content-hashed (e.g., `bd-a1b2`) not sequential integers.

**Why:**
- Multiple agents can create issues simultaneously without central coordination
- No counter conflicts in multi-agent concurrent development
- Dolt's cell-level merge resolves any unlikely hash collisions automatically
- IDs are short but unique within the project
- Epic children get hierarchical IDs: `bd-a3f8.1`, `bd-a3f8.2`

The collision probability is formally analysed in `docs/COLLISION_MATH.md`.

### 3. Dolt as Backend (Version-Controlled SQL)

**Decision:** Use Dolt instead of SQLite, flat files, or a traditional database.

**Why Dolt specifically:**
| Capability | SQLite | Postgres | Flat Files | Dolt |
|-----------|--------|----------|-----------|------|
| Embedded (no server) | Yes | No | Yes | Yes |
| SQL queries | Yes | Yes | No | Yes |
| Version history | No | No | Git (file-level) | Native (cell-level) |
| Branch & merge | No | No | Git (conflict-prone) | Native (cell-level merge) |
| Push/pull remote | No | Replication | Git push | Native push/pull |
| Time travel queries | No | Limited | Git checkout | `AS OF` queries |
| Multi-writer merge | No | Locks | Git merge (conflicts) | Cell-level merge (conflict-free) |

**Cell-level merge** is the killer feature: when two agents both modify the issues table — one creates issue A, the other closes issue B — Dolt merges at the SQL cell level with zero conflicts. Git would see the entire file as conflicting.

### 4. The `bd prime` Context Injection

**Decision:** Inject a ~1-2k token context at session start via hook, not load the full database.

**Why:**
- Agent sessions have limited context windows
- Loading 50+ issues would waste 10k+ tokens
- `bd prime` provides just the workflow instructions and command reference
- Agents query on-demand with `bd ready`, `bd show`, `bd list` — pulling only what they need
- The prime output adapts to context (MCP mode, stealth mode, ephemeral branch, etc.)

**How it works:** The `SessionStart` hook runs `bd prime` automatically. The `PreCompact` hook refreshes it before context compaction.

### 5. Persistent Memories

**Decision:** A key-value memory store (`bd remember`) injected into every session via `bd prime`.

**Why:**
- Agents discover project conventions, debugging patterns, and user preferences
- These insights would be lost between sessions without persistent storage
- By injecting memories into `bd prime`, every new session gets the full history of learned insights
- No separate memory file (like MEMORY.md) that fragments across accounts

**Example workflow:**
```bash
bd remember "User prefers functional style over OOP"
bd remember "CI runs on GitHub Actions, not Jenkins"
bd remember "The auth module uses JWT with RS256 signing"
# All three memories appear in every future bd prime output
```

### 6. Atomic Claim

**Decision:** `bd update <id> --claim` is a single atomic operation that sets both assignee and status.

**Why:**
- In multi-agent scenarios, two agents might try to claim the same work
- Atomic claim prevents race conditions: only one agent can claim an issue
- Eliminates the "forgot to set status to in_progress" failure mode
- Single command, not two separate operations

### 7. Dependency-Aware Work Queue

**Decision:** `bd ready` uses a recursive CTE to resolve transitive blocking.

**Why:**
- Simple "what's open?" queries miss blocked work, leading agents to pick up tasks they can't complete
- Transitive blocking means if A blocks B blocks C, then C shows as blocked even though it has no direct blocker
- The recursive CTE (up to depth 50) catches deep dependency chains
- `--explain` mode shows exactly why something is blocked — agents can debug their own workflow

### 8. The "Land the Plane" Protocol

**Decision:** A mandatory end-of-session ritual that MUST complete before the agent can say "done."

**Why:**
- Without explicit session close, agents leave work stranded locally
- `git push` is the final verification that work is persistent
- `bd dolt push` ensures the issue state is synced for the next session
- The protocol is injected via `bd prime` so every agent knows it

```
File remaining work → Run quality gates → Close beads → bd dolt push → git push → git status
```

**Critical rule:** Work is NOT complete until `git push` succeeds. The agent NEVER says "ready to push when you are" — the agent pushes.

### 9. Graph-Based Issue Structure

**Decision:** Dependencies form a directed acyclic graph (DAG), not a flat list.

**Why:**
- Real work has dependencies: tests depend on implementation, PR depends on review
- The DAG enables `bd ready` to show only truly unblocked work
- `bd graph` provides visual debugging of workflow bottlenecks
- Cycle detection prevents impossible dependency chains
- Multiple dependency types (`blocks`, `parent-child`, `discovered-from`, `supersedes`) model real relationships

### 10. Batch Creation from JSON Plans

**Decision:** `bd create --graph <json>` can create an entire issue DAG in one command.

**Why:**
- Agents create implementation plans with many interdependent tasks
- Without batch creation, an agent would need N commands to create N issues plus M commands for M dependencies
- A single `--graph` command can create the entire plan as a DAG
- This pairs perfectly with the writing-plans skill — the plan output can be directly ingested

## Comparison with Alternatives

### Beads vs Claude Code Native Tasks

| Dimension | Beads | Claude Code Tasks |
|-----------|-------|------------------|
| Persistence | Full (Dolt DB, survives sessions) | Session-scoped (gone when session ends) |
| Dependencies | Full DAG with recursive blocking | Basic blocking |
| Multi-agent | Hash IDs + cell-level merge | Shared task list |
| Remote sync | Dolt push/pull (DoltHub, S3, etc.) | None |
| Custom fields | 60+ columns + metadata JSON | Fixed schema |
| Audit trail | Full event history | None |
| Memory system | `bd remember` injected into every session | None |
| Token cost | ~1-2k (bd prime) | ~0 (built-in) |
| Complexity | High (Go binary, Dolt, hooks) | Zero (built-in) |

**Verdict:** Beads is strictly more capable. Claude Code native tasks are a lightweight subset inspired by Beads (Anthropic has acknowledged this).

### Beads vs Flat File Trackers (Ticket, markdown TODOs)

| Dimension | Beads | Flat Files |
|-----------|-------|-----------|
| Storage | Version-controlled SQL | Git-tracked markdown |
| Query capability | Full SQL, structured search | grep |
| Merge strategy | Cell-level (conflict-free) | Line-level (conflict-prone) |
| Dependencies | DAG with recursive resolution | Manual tracking |
| Scalability | 1000+ issues, O(1) queries | Degrades with file size |
| Agent integration | SessionStart hook, `bd prime` | Read file, parse manually |

**Verdict:** Flat files work for solo developers on small projects. Beads is necessary when there are multiple agents, complex dependencies, or >20 issues.

### Beads vs Traditional Trackers (Jira, Linear)

| Dimension | Beads | Jira/Linear |
|-----------|-------|-------------|
| Agent interface | CLI (2 tokens per command) | REST API (50+ tokens per call) |
| Local-first | Yes (embedded Dolt) | No (requires network) |
| Token overhead | ~1-2k (bd prime) | 10-50k+ (API schemas) |
| Version control | Built-in (Dolt) | None (external DB) |
| Setup | `bd init` (30 seconds) | Account creation, project setup, API keys |
| Multi-agent merge | Cell-level (automatic) | Last-write-wins (conflicts) |

**Verdict:** Beads replaces Jira/Linear for agent workflows. Traditional trackers are still needed for human-facing project management, but beads can sync with them via integrations.

## What Makes Beads Proven

### Adoption Metrics

- **20,285 GitHub stars** in 6 months (Oct 2025 → Apr 2026)
- **1,345 forks**
- **30+ contributors** with meaningful contributions
- **30+ releases** — approximately weekly release cadence
- **Anthropic acknowledged influence** on Claude Code's native task system
- **Jordan Hubbard** (FreeBSD co-founder) is a contributor

### Production Usage Patterns

1. **Solo AI coding** — Single developer with Claude Code, using beads for session memory
2. **Multi-agent swarms** — Gas Town multi-agent system built on beads for coordination
3. **Team development** — Multiple developers with AI agents, using Dolt sync for shared state
4. **Cross-project federation** — Multiple beads instances syncing via peer-to-peer federation

### Community Validation

- Better Stack, paddo.dev, bruton.ai, DEV Community have all published guides
- Neovim plugin (`nvim-beads`) demonstrates editor ecosystem adoption
- Multiple MCP marketplace listings show the MCP server is being used
- The 280KB CHANGELOG demonstrates the depth of ongoing development

## The Agent-Optimal Workflow

The ideal beads workflow for an AI agent:

```
Session Start:
  bd prime (auto via SessionStart hook)
  ├── Get workflow instructions (~1-2k tokens)
  ├── Get persistent memories
  └── Get session close protocol

Task Discovery:
  bd ready                    # What can I work on?
  bd show <id>                # Full context for chosen task

Task Execution:
  bd update <id> --claim      # Atomic claim
  [do the work]
  bd create "Discovered work" # File new work as it's found
  bd dep add <new> <current>  # Link discoveries

Task Completion:
  bd close <id> -r "Done: X"  # Close with reason
  bd close <id> --suggest-next # See what's unblocked now

Session End:
  bd close <completed-ids>    # Close all done work
  bd dolt push                # Sync issue state
  git push                    # Sync code
  git status                  # Verify clean
```

Every step is one CLI command. No web UI. No API pagination. No token-expensive schema loading. The agent stays in its natural environment (the terminal) and interacts with beads through the same interface it uses for everything else.

## Key Insight: Beads as Agent Memory Architecture

Beads isn't just an issue tracker. It's a **memory architecture for AI agents**:

| Memory Type | How Beads Provides It |
|-------------|----------------------|
| **Working memory** | `bd show --current` — what am I doing right now? |
| **Short-term memory** | `bd list --status=in_progress` — what's active? |
| **Long-term memory** | `bd remember` + `bd prime` injection |
| **Procedural memory** | `bd formula` — reusable workflow templates |
| **Episodic memory** | `events` table — complete audit trail of what happened |
| **Semantic memory** | `bd search`, `bd query` — find related work by meaning |
| **Prospective memory** | `bd ready` — what should I do next? |
| **Social memory** | `bd memories` — team conventions and preferences |

No other tool provides all seven types of agent memory in a single, integrated system.

---

**Next:** [09-beads-design-patterns.md](./09-beads-design-patterns.md) — Design patterns, the molecule system, and ecosystem analysis
