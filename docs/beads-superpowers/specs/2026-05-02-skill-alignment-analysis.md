# Skill Alignment Analysis — FSM, Worktrees, and Inter-Skill Gaps

**Date:** 2026-05-02
**Status:** Analysis
**Epic bead:** bd-vtg

## Executive Summary

The beads-superpowers plugin has 22 skills, an 11-state FSM development lifecycle, and two worktree systems that conflict. This document maps every skill to its purpose, chains, and gaps. The goal is to identify what's broken, what's missing, and what's misaligned before making changes.

---

## Part 1: The Worktree Isolation Problem

### Two Competing Worktree Systems

| System | Mechanism | Beads DB | .gitignore | Used By |
|--------|-----------|----------|-----------|---------|
| `bd worktree create` | git worktree + beads integration | Auto-shared via git common dir | Auto-added | `using-git-worktrees` skill |
| Claude's `EnterWorktree` / `isolation: "worktree"` | git worktree (native Claude Code) | Not aware of beads | Creates in `.claude/worktrees/` | Claude Code Agent tool |

**Conflict:** Our `using-git-worktrees` skill's Iron Law says "ALWAYS use `bd worktree`, NEVER `git worktree`." But Claude Code's Agent tool has an `isolation: "worktree"` parameter that uses its own native `EnterWorktree` mechanism, completely bypassing `bd worktree`. Any subagent dispatched with `isolation: "worktree"` gets a worktree without beads DB sharing.

### Current Subagent-Driven Development Flow

```
Orchestrator invokes using-git-worktrees → bd worktree create → ONE worktree for the epic
  └── Subagent 1: implementer runs in shared worktree, commits
  └── Review 1: spec reviewer + code quality reviewer
  └── Subagent 2: implementer runs in SAME worktree, sees subagent 1's commits
  └── Review 2: spec reviewer + code quality reviewer
  └── ... all sequential, all in the same directory
```

**Problems with current design:**
1. If subagent's work fails review, can't cleanly discard just that task's changes (committed on shared branch)
2. Can't run independent tasks in parallel (all write to same worktree)
3. No rollback granularity — all or nothing

### Correct Architecture

The orchestrator should create `bd worktree`s and pass paths to subagents. Subagents never run `bd worktree` themselves (orchestrator-only design preserved).

**For sequential tasks (have dependencies):**
```
Orchestrator creates one bd worktree for the epic
Tasks run sequentially in that worktree (current behavior, fine)
```

**For parallel-eligible tasks (no dependencies between them):**
```
Orchestrator reads bd dep tree → identifies independent task batch
Per independent task:
  bd worktree create task-N --branch feature/epic/task-N
Dispatches subagents in parallel, each given their worktree path
After all complete + pass review:
  Orchestrator merges task branches into epic worktree
  Runs full test suite on merged result
Next batch of unblocked tasks
```

### Files That Need Changes

| File | Change |
|------|--------|
| `skills/subagent-driven-development/SKILL.md` | Add parallel batch mode. Orchestrator creates bd worktrees, passes paths. Keep sequential for dependent tasks. |
| `skills/subagent-driven-development/implementer-prompt.md` | `Work from: [directory]` already exists — orchestrator sets this correctly per task |
| `skills/dispatching-parallel-agents/SKILL.md` | Generalize from "parallel bug-fixing" to "parallel independent work." Add SDD integration section. |
| `skills/using-git-worktrees/SKILL.md` | Add section: "Multiple worktrees for parallel subagent work" |

---

## Part 2: FSM State Machine Issues

### Issue 1: `getting-up-to-speed` Not In FSM

**Current:** Session Start says "beads-superpowers plugin injects `bd prime` context automatically" + `bd ready` + claim.

**Problem:** `getting-up-to-speed` does much more than `bd prime` — reads codebase, checks git state, drills into open beads, produces structured summary. It's the real session orientation skill but isn't referenced.

**Fix:** Add as pre-FSM step or rename Session Start to reference it. `getting-up-to-speed` is the skill; `bd prime` is just one command within it.

### Issue 2: S2 Reimplements `research-driven-development`

**Current:** S2 describes manually dispatching `@researcher` + `@explore` agents in parallel.

**Problem:** The `research-driven-development` skill exists and does exactly this. The FSM reimplements the same logic inline instead of invoking the skill.

**Fix:** S2 should say `Invoke Skill(beads-superpowers:research-driven-development)`.

### Issue 3: S9 Doesn't Reference `write-documentation`

**Current:** S9 invokes only `Skill(document-release)`.

**Problem:** `write-documentation` fires when writing/rewriting prose, which is exactly what happens when `document-release` identifies sections needing major rewrites.

**Fix:** S9 should mention both: `document-release` for syncing, `write-documentation` for quality when new content is written.

### Issue 4: `stress-test` Not Placed In FSM Flow

**Current:** Listed as an interrupt trigger, but logically sits between S4 (brainstorm) and S5 (ADR capture).

**Fix:** S4 should note that brainstorming may invoke `stress-test` before completing.

### Issue 5: S10/S11 Overlap

**Current:** S10 = `finishing-a-development-branch` (which includes Land the Plane as Step 6). S11 = `bd close` → `bd dolt push` → `git push` → `git status` (which is Land the Plane).

**Problem:** Redundant. The finishing skill already does everything S11 describes.

**Fix:** Merge S11 into S10, or clarify that S11 only fires if S10 chose "Keep as-is" (Option 3).

---

## Part 3: Complete Skill Map

### All 22 Skills — Purpose, Triggers, Chains

| # | Skill | Purpose | Triggered By | Invokes / Chains To |
|---|-------|---------|-------------|-------------------|
| 1 | `using-superpowers` | Bootstrap — loaded at session start, routes to other skills | SessionStart hook (automatic) | Routes to ANY other skill |
| 2 | `setup` | Post-install hook configuration | User says "set up beads-superpowers" | Terminal (no chain) |
| 3 | `getting-up-to-speed` | Session orientation — codebase + beads + git state | Session start, after compaction, "catch me up" | Terminal (produces summary, user drives next) |
| 4 | `brainstorming` | Socratic design before code | Any creative work, new feature | → `stress-test` (optional) → `writing-plans` |
| 5 | `stress-test` | Adversarial design interrogation | After brainstorming, "stress test this" | → back to `brainstorming` or → `writing-plans` |
| 6 | `writing-plans` | Bite-sized task plans with beads | After brainstorming approval | → `subagent-driven-development` or `executing-plans` |
| 7 | `subagent-driven-development` | Fresh subagent per task + two-stage review | Plan exists, tasks independent, same session | Uses: `using-git-worktrees`, `test-driven-development` (via subagents), `requesting-code-review` → `finishing-a-development-branch` |
| 8 | `executing-plans` | Batch execution in single session | Plan exists, parallel session | Uses: `using-git-worktrees`, `test-driven-development` → `finishing-a-development-branch` |
| 9 | `dispatching-parallel-agents` | 2+ independent tasks without shared state | Multiple independent failures/tasks | Terminal (results integrated by orchestrator) |
| 10 | `test-driven-development` | RED-GREEN-REFACTOR | Before writing any implementation code | Used BY `subagent-driven-development` and `executing-plans` |
| 11 | `systematic-debugging` | 4-phase root cause analysis | Bug, test failure, unexpected behaviour | Interrupt — returns to interrupted state |
| 12 | `verification-before-completion` | Evidence before claims | About to claim done | Gates `bd close` and commit/PR |
| 13 | `requesting-code-review` | Dispatches code reviewer subagent | After implementation, before merge | → `receiving-code-review` (if feedback received) |
| 14 | `receiving-code-review` | Anti-sycophancy review reception | Review feedback received | → implementation fixes → re-review |
| 15 | `using-git-worktrees` | Isolated development branches | Before implementation, complex tasks | Used BY `subagent-driven-development`, `executing-plans` |
| 16 | `finishing-a-development-branch` | Merge/PR + Land the Plane | Implementation complete, tests pass | Terminal (merges, pushes, closes beads) |
| 17 | `document-release` | Post-ship documentation audit and sync | After code committed, before PR merge | May trigger `write-documentation` for major rewrites |
| 18 | `write-documentation` | Human-quality prose for human-facing text | Writing/rewriting docs, emails, posts | Terminal (produces prose) |
| 19 | `project-init` | Beads/Dolt DB setup, bootstrap, recovery | bd commands fail, new project | Terminal (DB initialized) |
| 20 | `writing-skills` | Meta-skill for creating/modifying skills | Creating new skills | Terminal (skill created) |
| 21 | `auditing-upstream-drift` | Detect staleness vs upstream | Before release, periodic check | May trigger skill updates |
| 22 | `research-driven-development` | Parallel research agents → KB document | "Research this", "what is X" | Terminal (KB document written) |

### Skill Categories

```
LIFECYCLE (session flow):
  using-superpowers → getting-up-to-speed → [work] → finishing-a-development-branch

DESIGN PHASE:
  brainstorming → stress-test → writing-plans

EXECUTION PHASE:
  subagent-driven-development (uses: using-git-worktrees, dispatching-parallel-agents, test-driven-development)
  executing-plans (uses: using-git-worktrees, test-driven-development)

QUALITY PHASE:
  test-driven-development
  verification-before-completion
  requesting-code-review ↔ receiving-code-review

DOCUMENTATION PHASE:
  document-release + write-documentation

DEBUGGING (interrupt):
  systematic-debugging

RESEARCH:
  research-driven-development

INFRASTRUCTURE:
  using-git-worktrees
  project-init
  setup

META:
  writing-skills
  auditing-upstream-drift
```

### Expected Skill Chains (Happy Path)

```
Session Start:
  using-superpowers (auto) → getting-up-to-speed (orient) → bd ready (find work)

Non-trivial Feature:
  brainstorming → [stress-test] → writing-plans → subagent-driven-development
    → using-git-worktrees (create epic worktree)
    → [dispatching-parallel-agents for independent tasks]
    → test-driven-development (per task, via subagents)
    → requesting-code-review (per task)
    → verification-before-completion
    → document-release → [write-documentation]
    → finishing-a-development-branch (merge + land the plane)

Simple Fix:
  using-git-worktrees → test-driven-development → verification-before-completion
    → document-release → finishing-a-development-branch

Research Query:
  research-driven-development → (KB document written)

Bug:
  systematic-debugging → (root cause found) → test-driven-development (fix)
```

---

## Part 4: Identified Gaps

### Gap 1: SDD ↔ dispatching-parallel-agents Disconnection
**What:** SDD runs all tasks sequentially. `dispatching-parallel-agents` exists for parallel work but isn't referenced by SDD. Independent plan tasks could run in parallel.
**Impact:** Slower execution of plans with independent tasks.
**Fix:** SDD should check `bd dep tree`, identify independent batches, use `dispatching-parallel-agents` pattern for those batches.

### Gap 2: No Per-Task Rollback in SDD
**What:** All subagent commits go to the same branch. If review fails, the failed task's commits are mixed with prior successful task commits.
**Impact:** Can't cleanly undo a single task without interactive rebase.
**Fix:** Per-task branches (orchestrator creates `bd worktree` per task, merges after review passes).

### Gap 3: `getting-up-to-speed` Not Referenced in FSM
**What:** The skill exists and works but the FSM Session Start section doesn't mention it.
**Impact:** Agents may skip orientation and go straight to `bd ready`.
**Fix:** Add to Session Start as the orientation step.

### Gap 4: `research-driven-development` Not Referenced in S2
**What:** S2 describes manual agent dispatch. The skill does the same thing.
**Impact:** FSM reimplements what the skill provides. If the skill improves, the FSM doesn't benefit.
**Fix:** S2 invokes the skill.

### Gap 5: `write-documentation` Not Referenced in S9
**What:** `document-release` syncs docs. `write-documentation` writes quality prose. S9 only mentions the former.
**Impact:** Major doc rewrites don't get prose quality treatment.
**Fix:** S9 mentions both skills.

### Gap 6: `stress-test` Not Placed in FSM
**What:** Listed as interrupt but logically sits in the design phase flow.
**Impact:** Agents may not know when to invoke it.
**Fix:** Note in S4 that brainstorming may invoke stress-test.

### Gap 7: S10/S11 Redundancy
**What:** `finishing-a-development-branch` Step 6 IS Land the Plane. S11 repeats it.
**Impact:** Confusing — agents may run Land the Plane twice, or skip S11 thinking S10 covered it.
**Fix:** Merge into one state.

### Gap 8: Three Copies of UserPromptSubmit Reminder
**What:** The reminder hook content exists in `hooks/superpowers-reminder.sh`, `skills/setup/SKILL.md`, and `install.sh`.
**Impact:** Adding a skill requires updating 3 files. We just found this — `write-documentation` was missing from 2 of 3.
**Fix:** `setup` and `install.sh` should read from a shared source, or the reminder content should be generated from a template.

### Gap 9: `dispatching-parallel-agents` Is Bug-Fix Scoped
**What:** The skill describes parallel bug-fixing (test failures). Its examples, "When to Use", and "Real Example" all focus on debugging scenarios.
**Impact:** Agents don't think to use it for parallel plan task execution.
**Fix:** Generalize the skill description and add plan execution examples.

### Gap 10: No Skill for "Add a New Skill and Update Everything"
**What:** Adding a skill requires: create SKILL.md, update CLAUDE.md (table + count), update README, update install.sh (KNOWN_SKILLS), update 3 reminder hook copies, update docs-src/skills.md (5 places), update CI threshold, run sync-skill-count.sh.
**Impact:** We just went through this with `write-documentation` and had to fix things after the fact.
**Fix:** The `writing-skills` meta-skill should include a "post-creation checklist" that covers all these files, or `sync-skill-count.sh` should be extended to handle more than just the count.
