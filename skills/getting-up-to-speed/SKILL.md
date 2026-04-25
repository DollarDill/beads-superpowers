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

Run this single command first to pick a path:

```bash
TRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
HAS_BEADS=$([ -d .beads ] && echo 1 || echo 0)
HAS_GIT=$([ -d .git ] && echo 1 || echo 0)
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
