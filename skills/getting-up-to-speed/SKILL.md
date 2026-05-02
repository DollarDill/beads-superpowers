---
name: getting-up-to-speed
description: Use at the start of a session, after compaction, or whenever you need to orient on an unfamiliar or stale codebase. Loads beads context, deep-dives the codebase, and produces a structured 'current state' summary. Triggers on phrases like "catch me up", "where are we", "orient me", "what's the state of this project", "bring me up to speed", "load context", "session orientation".
---

# Getting Up to Speed

Orient on the current project before doing any work. Run beads context commands, deep-dive the codebase, and produce a structured "current state" summary so you (and the user) know exactly where things stand.

**Announce at start:** "I'm using the getting-up-to-speed skill to orient on the project."

## When to Use

- Start of a fresh session on an existing project
- After `/compact` or context loss
- User says "catch me up", "where are we", "orient me", "bring me up to speed", "load context", "session orientation"
- You're about to do non-trivial work in a repo and have no recent context

## When NOT to Use

- The user just asked a single targeted question that doesn't depend on broad context
- You already oriented in this session and nothing has changed
- Fresh empty repo with nothing to orient on (use `project-init` instead)

## Pipeline

```
Pre-step: Detect repo scale  →  Phase 1: Beads (parallel)  →  Phase 2: Codebase (parallel, adaptive)
                                                                     ↓
                                       Phase 4: Synthesize summary  ←  Phase 3: Top open beads drilldown
```

## Pre-step: Detect repo scale

Run this single command first to pick a path. Uses git plumbing (`rev-parse --is-inside-work-tree`) and a probe of `bd ready` so it works correctly inside git worktrees and submodules — checking for a literal `.git`/`.beads` directory misidentifies worktrees as "no git" because `.git` there is a file, not a directory.

```bash
TRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
HAS_GIT=$(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo 1 || echo 0)
if command -v bd >/dev/null 2>&1; then
  HAS_BEADS=$(bd ready --limit 1 >/dev/null 2>&1 && echo 1 || echo 0)
else
  HAS_BEADS=0
fi
echo "tracked=$TRACKED beads=$HAS_BEADS git=$HAS_GIT"
```

| Tracked files | Path | Behavior |
|---|---|---|
| `< 50` or no `.git` | **Light** | bd commands + read README + git log; skip Phase 2 medium drilldown. |
| `50 – 500` | **Medium** *(default)* | Parallel bd + parallel codebase reads + key-file drilldown + open-bead details. |
| `> 500` | **Heavy** | Dispatch `@researcher` + `@explore` in parallel via the `Agent` tool (use `dispatching-parallel-agents`). |

## Phase 1 — Beads context (single parallel batch)

Issue all six commands in **one message, multiple Bash tool calls in parallel**:

- `bd prime`
- `bd ready`
- `bd blocked`
- `bd list --status open --status in_progress`
- `bd memories`
- `bd stats`

If `bd` is not installed or `.beads/` is missing, skip Phase 1 entirely and emit "**Beads:** not installed/initialized — skipped" in the Phase 4 summary.

**Do NOT run `bd dolt status`, `bd dolt show`, or `bd dolt push` here** — these fail in embedded-Dolt-mode repos and are not needed for orientation.

## Phase 2 — Codebase exploration (single parallel batch, content varies by path)

Issue **all reads in one message, multiple tool calls in parallel**. Do NOT serialize.

### Light path

- `find <repo-root> -maxdepth 1 -mindepth 1 | sort`
- `git log --oneline -15` + `git status -sb` + `git tag --sort=-v:refname | head -5`
- `Read` of `README.md`

### Medium path *(default)*

Light path, plus:

- `Read` of any of these that exist: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json`
- `Read` of any of these that exist: `CHANGELOG.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`
- `Read` of project-specific manifests when relevant (e.g., `.claude-plugin/plugin.json` for plugin repos)
- `find` on any of these dirs that exist: `skills/`, `agents/`, `commands/`, `docs/`, `hooks/`, `tests/`, `src/`, `lib/`, `app/`

### Heavy path

Use `dispatching-parallel-agents` to dispatch in one message:

- `@researcher` — read CLAUDE.md/README/CHANGELOG, return architecture summary in <300 words
- `@explore` — enumerate top-level structure, count source files by language, return layout report in <200 words

After both return, optionally `Read` 1–3 files the agents flagged as critical.

## Phase 3 — Top open beads drilldown (all paths)

- Run `bd show <id> | head -30` on the **top 3 open ready beads by priority** from Phase 1's `bd ready` output.
- This is the agent's drilldown — used to feed the "Known operational quirks" line in the Phase 4 summary.
- The output table in Phase 4 lists **up to 10 open ready beads** (not just the 3 drilled), so the user sees the whole queue.

If Phase 1 was skipped (no beads), skip Phase 3.

## Phase 4 — Synthesize the structured summary

Produce **exactly this Markdown structure**. Heading levels are H2; tables and lists scale to project content. Sections you cannot fill from earlier phases are marked with the degraded-state language from the Edge Cases table — never invented.

```markdown
## What `<project>` Is
<1–3 sentence synthesis. Mentions language/runtime, primary purpose, and any merge/fork lineage if discoverable from CHANGELOG/README.>

| Layer | Source | Role |
|---|---|---|
<Optional table — used when project merges/wraps multiple subsystems. Skipped for simple repos.>

## Architecture Highlights
- **<key design decision 1>** — <one-line consequence>
- **<key design decision 2>** — <one-line consequence>
<3–6 bullets, sourced from CLAUDE.md / README / a METHODOLOGY-style doc.>

## Repo Layout (verified)
<code-fenced tree, ONLY directories actually present per `find` output. Never invented.>

## Current State
**Git:** <branch> <clean|N changes>, <in sync|N ahead|N behind> origin. Latest = `<sha>` <subject>. Tags: <top 5>.
**Last release:** <if version detectable> shipped: <CHANGELOG bullet summary>. `[Unreleased]` <empty|has N entries>.
**Beads ledger:** <total> total · <closed> closed · <open> open · <in-progress> · <blocked>.

| Bead | Pri | Title |
|---|---|---|
<Up to 10 open ready beads, sorted by priority. Top 3 were drilled into in Phase 3.>

**Known operational quirks:** <from `bd memories` keyword scan; from docs/known-issues/* if present>
**Other captured memories:** <one line per memory not surfaced above>

---
I'm ready for your next instruction. The highest-priority unblocked work right now is **`<bead-id>`** (<priority> — <title>).
```

The trailing "I'm ready" line is the **terminal contract**: the skill stops here. Do NOT auto-claim the next bead. Do NOT start working on anything. The user drives the next move.

If any memories from Phase 1 are stale or incorrect, clean them up:

```bash
bd forget <id>              # Remove outdated memory
bd remember "corrected: <updated insight>"  # Replace if needed
```

## Edge Cases

| Condition | Behavior |
|---|---|
| No `.git` directory | Skip the git phase entirely; emit "**Git:** not a git repo" in the summary |
| `bd` not installed | Skip Phase 1; emit "**Beads:** not installed — skipped" |
| `.beads/` missing but `bd` installed | Run `bd ready` (will return empty); note "no beads workspace" |
| Embedded Dolt mode | Do NOT call `bd dolt status/show/push` — only the safe read commands listed in Phase 1 |
| Dirty working tree | Show `git status -sb` count in the Current State line |
| Detached HEAD | Output `HEAD detached at <sha>` instead of branch name |
| Empty git log | `git log` exits non-zero; catch and emit "no commits yet" |
| `find` errors on missing dirs | Each `find` is independent and uses `2>/dev/null` — missing dirs skipped silently |

## Red Flags / Anti-Rationalization

These thoughts mean STOP — you're rationalizing skipping orientation:

| Thought | Reality |
|---|---|
| "I already explored this last session" | Sessions don't carry state. Re-orient. |
| "I'll skip beads commands — I'll use TodoWrite" | This project IS beads. `bd prime` is mandatory. TodoWrite is forbidden. |
| "The README is enough" | README skips beads state, open work, and known issues. Run the full pipeline. |
| "I'll skip Phase 3 — looking at open beads is busywork" | Phase 3 is what surfaces "this Dolt setup is broken" before you waste 20 minutes on it. |
| "I'll auto-claim the top P0" | Forbidden. Orient and stop. User drives. |
| "This is a small repo, I can skim" | Run the Light path of this skill. It's still 30 seconds and produces a summary you can refer back to. |

## Output Contract

The skill is complete when you have produced the structured summary AND emitted the trailing "I'm ready for your next instruction" line. No claiming, no continuation. Wait for user input.
