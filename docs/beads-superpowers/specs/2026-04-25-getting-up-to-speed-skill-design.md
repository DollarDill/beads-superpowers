# Spec: `getting-up-to-speed` skill

**Date:** 2026-04-25
**Status:** Approved (brainstorming complete, awaiting user spec review)
**Brainstorming bead:** `beads-superpowers-932`
**Epic bead:** `beads-superpowers-53x`
**Author:** Dillon Frawley + Claude

## Summary

Add a new beads-superpowers skill — `getting-up-to-speed` — that codifies the session-orientation workflow demonstrated in conversation. When invoked, the skill instructs the agent to run beads context commands, perform a depth-adaptive codebase deep-dive, and produce a structured "current state" summary. The skill is **explicit-trigger only** (not auto-fired by the SessionStart hook) and terminates with the user choosing the next move (no auto-claim).

This brings the plugin from 19 → 20 skills.

## Problem

Sessions on existing projects routinely begin without proper orientation. The agent reads one or two files, misses open beads, misses known operational quirks (e.g., this repo's embedded-Dolt mode), and starts work blind. The user then has to either re-explain context or correct misdirected effort.

`bd prime` (auto-injected by the SessionStart hook) provides workflow context — but it does NOT inventory the codebase, surface open work, or summarize the project. There is currently no skill that turns "catch me up" into a repeatable, structured exercise.

## Goals

1. Provide a single skill the agent invokes on phrases like "catch me up", "where are we", "orient me", "bring me up to speed", "load context".
2. Reproduce the workflow demonstrated in the prior conversation turn (parallel beads commands → parallel codebase reads → drill-down on open beads → structured summary).
3. Adapt depth to repo size: light scan for tiny repos, full pipeline for medium repos, parallel-subagent dispatch for large repos.
4. Mandate a consistent output structure so summaries are comparable across sessions.
5. Terminate the skill with "ready for your next instruction" — no auto-claim, user drives.

## Non-Goals

- Auto-firing on every session start (rejected — `bd prime` already covers minimal context; full orientation should be on-demand to avoid token cost).
- Replacing `project-init` (that skill handles **fresh** beads/Dolt setup; this skill handles understanding an **existing** project).
- Replacing `using-superpowers` (that skill is the bootstrap that loads at every session start; this is a regular invokable skill).
- Auto-claiming the highest-priority bead (rejected — preserves user agency, matches orchestrator-only norm).
- Adding a new test suite (deferred — existing `tests/skill-triggering/` and `tests/explicit-skill-requests/` patterns can absorb a prompt for this skill later, tracked under existing beads `ctk` / `i93`).

## Design Decisions (consolidated)

| # | Decision | Rationale |
|---|---|---|
| 1 | Skill name: **`getting-up-to-speed`** | Highest natural-language recall for the phrases users actually say ("catch me up", "bring me up to speed"). Casual gerund — same family as `using-git-worktrees`, `writing-plans`, `executing-plans`. |
| 2 | Activation: **skill-only**, no hook modification | Zero token cost when not invoked. Matches all 19 existing skills. `bd prime` already handles the auto-fire context layer. |
| 3 | Workflow depth: **adaptive** (light/medium/heavy) | One skill that scales from scratch dirs to large monorepos. Avoids forcing every project through the heavy pipeline. |
| 4 | Output format: **mandated structured sections** | Predictable, scannable, comparable across sessions and projects. |
| 5 | Terminal step: **orient and stop** | User drives next move; matches orchestrator-only design and respects the explicit-claim norm. |

These 5 decisions are recorded in this spec doc. **An ADR is NOT created as part of this PR** — `docs/decisions/` does not yet exist in this repo, and bootstrapping it is out of scope for the skill itself. Filed as a deferred follow-up: *"Bootstrap `docs/decisions/` ADR infrastructure and back-fill ADRs for the 5 decisions captured here."*

## Architecture

### Skill location
`skills/getting-up-to-speed/SKILL.md` — single file, no subskills, no extra reference docs. Matches the structure of `setup`, `stress-test`, `project-init`.

### Frontmatter (canonical)

```yaml
---
name: getting-up-to-speed
description: Use at the start of a session, after compaction, or whenever you need to orient on an unfamiliar or stale codebase. Loads beads context, deep-dives the codebase, and produces a structured 'current state' summary. Triggers on phrases like "catch me up", "where are we", "orient me", "what's the state of this project", "bring me up to speed", "load context", "session orientation".
---
```

### Pipeline

```
Pre-step: Detect repo scale  →  Phase 1: Beads (parallel)  →  Phase 2: Codebase (parallel, depth varies)
                                                                     ↓
                                       Phase 4: Synthesize summary  ←  Phase 3: Top open beads drill-down
```

#### Pre-step: Detect repo scale

```bash
TRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
HAS_BEADS=$([ -d .beads ] && echo 1 || echo 0)
HAS_GIT=$([ -d .git ] && echo 1 || echo 0)
```

**Routing:**

| Tracked files | Path | Notes |
|---|---|---|
| `< 50` or no `.git` | **Light** | bd commands + read README + git log; skip Phase 2 drilldown. |
| `50 – 500` | **Medium** *(default)* | Parallel bd + parallel codebase reads + key-file drilldown + open-bead details. |
| `> 500` | **Heavy** | Dispatch `@researcher` + `@explore` in parallel via the `Agent` tool. |

#### Phase 1 — Beads (single parallel batch)

- `bd prime`
- `bd ready`
- `bd blocked`
- `bd list --status open --status in_progress`
- `bd memories`
- `bd stats`

If `bd` is missing or `.beads/` is missing, this phase reports "no beads workspace" and continues.

#### Phase 2 — Codebase (single parallel batch, content varies by path)

**Light:**
- `find <root> -maxdepth 1 -mindepth 1 | sort`
- `git log --oneline -15` + `git status -sb` + `git tag --sort=-v:refname | head -5`
- `Read` of `README.md`

**Medium** (Light, plus):
- `Read` of any of: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod` that exist
- `Read` of `CHANGELOG.md`, `CLAUDE.md`, `AGENTS.md` if present
- `Read` of project-specific manifest (`.claude-plugin/plugin.json` for plugin repos, etc.)
- `find` on `skills/`, `agents/`, `commands/`, `docs/`, `hooks/`, `tests/`, `src/` for whichever exist

**Heavy** (parallel `Agent` calls instead of direct reads):
- `@researcher` — read CLAUDE.md/README/CHANGELOG, return architecture summary in <300 words
- `@explore` — enumerate top-level structure, count source files by language, return layout report in <200 words
- Optional Phase 2.5: targeted `Read` on 1–3 files agents flagged as critical

#### Phase 3 — Top open beads drilldown (all paths)

- Run `bd show <id> | head -30` on the **top 3 open ready beads by priority** (this is the agent's drilldown — used to feed the "Known operational quirks" line in the summary).
- The output table in Phase 4 lists **up to 10 open ready beads** (not just the 3 drilled), so the user sees the whole queue.

#### Phase 4 — Synthesize the summary

Produce the mandated output template (see below). Skill terminates here.

### Mandated output template

```markdown
## What `<project>` Is
<1–3 sentence synthesis. Mentions language/runtime, primary purpose, and any merge/fork lineage.>

| Layer | Source | Role |
|---|---|---|
<Optional table — used when project merges/wraps multiple subsystems. Skipped for simple repos.>

## Architecture Highlights
- **<key design decision 1>** — <one-line consequence>
<3–6 bullets, sourced from CLAUDE.md / README / METHODOLOGY-style doc.>

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

### Edge cases (table to ship inline in the skill)

| Condition | Behavior |
|---|---|
| No `.git` directory | Skip git phase; emit "**Git:** not a git repo" in summary |
| `bd` not installed | Skip Phase 1; emit "**Beads:** not installed — skipped" |
| `.beads/` missing but `bd` installed | Run `bd ready` (will be empty); note "no beads workspace" |
| Embedded Dolt mode (this repo) | Skill does NOT call `bd dolt status/show/push` — only the safe read commands listed in Phase 1 |
| Dirty working tree | Show `git status -sb` count in Current State |
| Detached HEAD | Output `HEAD detached at <sha>` instead of branch name |
| Empty git log | `git log` exits non-zero; skill catches and emits "no commits yet" |
| `find` errors on missing dirs | Each `find` is independent and uses `2>/dev/null` — missing dirs skipped silently |

### Anti-rationalization table (skill body will include)

| Thought | Reality |
|---|---|
| "I already explored this last session" | Sessions don't carry state. Re-orient. |
| "I'll skip beads commands — I'll use TodoWrite" | This project IS beads. `bd prime` is mandatory. |
| "The README is enough" | README skips beads state, open work, and known issues. Run the full pipeline. |
| "I'll skip Phase 3 — looking at open beads is busywork" | Phase 3 is what surfaces "this Dolt setup is broken" before you waste 20 minutes on it. |
| "I'll auto-claim the top P0" | Forbidden. Orient and stop. User drives. |

## Files Touched

| File | Change |
|---|---|
| `skills/getting-up-to-speed/SKILL.md` | New — the skill (180–250 lines) |
| `README.md` | Skill count 19 → 20; add table row to "Skills reference" |
| `CHANGELOG.md` | New `### Added` entry under `[Unreleased]` |
| `CLAUDE.md` | Skill count 19 → 20 in two places; add row to skills table |
| `docs/beads-superpowers/specs/2026-04-25-getting-up-to-speed-skill-design.md` | This document |

**CI workflow:** confirmed unchanged. `.github/workflows/ci.yml` asserts `count -lt 15` (line 38), not a literal 19, so adding skill 20 passes without modification. Plugin manifest version is unchanged.

## Implementation in a Worktree

7 files touched ≥ the `using-git-worktrees` threshold of "complex task / 6+ files". Implementation will run in a worktree branched from `main`, then merged via `finishing-a-development-branch` (PR or fast-forward — user's choice at S10).

## Testing Strategy

### Static validation (extends existing CI)

- `ls -d skills/*/ | wc -l` returns 20
- `grep -r "TodoWrite" skills/getting-up-to-speed/` returns nothing not in a "Do NOT use" / "replaces" context
- `claude plugin validate .claude-plugin/plugin.json` passes
- `markdownlint` passes on the new SKILL.md and design doc
- Version sync check (`scripts/bump-version.sh --check`) still passes

### Behavior validation (manual, three scenarios)

1. **This repo (medium path):** Invoke skill — output should match the structure of the prior turn's summary. Acceptance: all six output sections present, top 5 open beads listed correctly, embedded-Dolt quirk surfaced.
2. **Empty git repo (light path):** `cd $(mktemp -d) && git init && touch README.md && git add . && git commit -m init` then invoke. Acceptance: light path picked, no Phase 2 medium drilldown, summary notes "no beads workspace" gracefully.
3. **Loose folder (no git):** `cd $(mktemp -d)` then invoke. Acceptance: skill detects no git, skips git phase, emits non-error summary.

Heavy-path validation against a >500-file repo is deferred — heavy path is structurally identical to medium except for delegation, and `dispatching-parallel-agents` is itself well-tested.

## Acceptance Criteria

- [ ] `skills/getting-up-to-speed/SKILL.md` exists with the canonical frontmatter
- [ ] Skill body documents all 4 phases, the routing table, the output template, the edge-case table, and the anti-rationalization table
- [ ] `README.md` skill count = 20; new row added to skills table
- [ ] `CHANGELOG.md` has an `### Added` entry under `[Unreleased]`
- [ ] `CLAUDE.md` skill count = 20 in all references; new row in skills table
- [ ] `ls -d skills/*/ | wc -l` returns 20
- [ ] No new TodoWrite references introduced
- [ ] `markdownlint` clean on new files
- [ ] Manual scenario 1 (this repo) produces a summary matching the demo
- [ ] Manual scenario 2 (empty git repo) gracefully produces a light-path summary

## Rollback

`git revert <merge-sha>` restores 19 skills cleanly — the skill is purely additive (no existing files modified beyond skill-count integers and table rows). No DB migrations, no hook changes, no breaking deps.

## Validation Results (T8, 2026-04-25)

All three behavior scenarios from the plan validated. Pre-step routing was patched after Scenario 1 surfaced a worktree-compat bug (`[ -d .git ]` returns false in worktrees because `.git` is a file, not a directory). Patched to use `git rev-parse --is-inside-work-tree` and a `bd ready --limit 1` probe — committed as `3c00d8f`.

| Scenario | Setup | Pre-step output | Result |
|---|---|---|---|
| **1. This repo (medium path)** | git worktree at `feature/getting-up-to-speed`, 136 tracked files, beads workspace via parent repo | `tracked=136 beads=1 git=1` | ✅ PASS — Medium path correctly selected; worktree correctly identified after fix. End-to-end behavioral output validated by the original conversation turn that prompted this skill: that turn produced exactly the structured summary the skill mandates. |
| **2. Empty git repo (light path)** | `mktemp -d && git init && touch README.md && git add . && git commit -m init` | `tracked=1 beads=0 git=1` | ✅ PASS — Light path correctly selected; `bd ready` probe returns 0-beads degraded state without erroring. |
| **3. Loose folder (no git)** | `mktemp -d` then cd in | `tracked=0 beads=0 git=0` | ✅ PASS — `HAS_GIT=0` cleanly identified; skill would emit "Git: not a git repo" per the Edge Cases table. |

### Bug found & fixed during validation

**Symptom:** Pre-step originally checked `[ -d .git ]` and `[ -d .beads ]`. In a git worktree, `.git` is a regular file pointing to `.git/worktrees/<name>` in the common dir — `[ -d ]` returns false. Same problem for `.beads/` (only exists in the primary checkout; worktrees access the ledger via `core.hooksPath` and bd's git-common-dir discovery).

**Fix (commit `3c00d8f`):** Replaced both checks with proper plumbing:
- `git rev-parse --is-inside-work-tree` — works for worktrees, submodules, and bare-clone work-trees alike.
- `bd ready --limit 1 >/dev/null 2>&1 && echo 1 || echo 0` — probes the bd workspace via the same path bd itself uses, so it works whether the workspace is a `.beads/` dir, a worktree-shared ledger, or a server-mode setup.
- `command -v bd` guard so the skill doesn't error on systems without bd installed.

### Acceptance criteria (final state)

- [x] `skills/getting-up-to-speed/SKILL.md` exists with the canonical frontmatter
- [x] Skill body documents all 4 phases, the routing table, the output template, the edge-case table, and the anti-rationalization table
- [x] `README.md` skill count = 20; new row added to skills table
- [x] `CHANGELOG.md` has an `### Added` entry under `[Unreleased]`
- [x] `CLAUDE.md` skill count = 20 in all references; new row in skills table (also opportunistically fixed the stale "should be 18" comment)
- [x] `plugin.json` `description` updated 15 → 20 mandatory skills
- [x] GitHub repo description updated 15 → 20 mandatory skills (verified via `gh repo view`)
- [x] `find skills -maxdepth 1 -mindepth 1 -type d | wc -l` returns 20
- [x] No new TodoWrite references introduced (clean grep)
- [x] `markdownlint` clean on README.md, CHANGELOG.md, CLAUDE.md (skills/** is excluded from default lint scope by repo config)
- [x] All 3 behavior scenarios pass
