# SDD Parallel Batch Mode with Per-Task Worktree Isolation

**Date:** 2026-05-02
**Status:** Approved
**Beads:** bd-8e6 (P0, fix subagent worktree isolation), bd-0rd (P1, parallel batch mode)
**ADR:** [ADR-0002](../../decisions/ADR-0002-sdd-parallel-worktree-architecture.md)

## Problem

Subagent-Driven Development creates a single `bd worktree` for the entire epic and runs all implementer subagents sequentially in that shared worktree. Three problems:

1. **No per-task rollback.** Failed task commits are mixed with successful ones on the same branch.
2. **No parallel execution.** Independent tasks run sequentially even though they could run concurrently in isolated worktrees.
3. **Competing worktree systems.** Claude Code's `isolation: "worktree"` parameter uses `EnterWorktree` (Claude-native), bypassing `bd worktree` and losing beads DB sharing.

## Design

### Dual-Mode Execution

SDD gains two execution modes, selected automatically based on the number of unblocked tasks returned by `bd ready --parent <epic-id>`.

**Sequential Mode** (existing behavior, for dependent tasks or single-task batches):

```
Orchestrator creates epic worktree (bd worktree create <epic-name>)
  → Task runs in epic worktree
  → Two-stage review (spec + quality)
  → Next task (same worktree)
  → Repeat until bd ready --parent returns empty
```

Used when `bd ready --parent` returns exactly 1 task, or when the remaining tasks form a dependency chain.

**Parallel Batch Mode** (new, for independent tasks):

```
1. Orchestrator creates epic worktree
     bd worktree create <epic-name>
     cd <epic-worktree-path>

2. Get unblocked tasks
     bd ready --parent <epic-id>
     → Returns N tasks with no unresolved dependencies

3. If N > 1: parallel batch (cap at 5 per batch)
   For each task in batch (up to 5):
     a. Create task worktree (from repo root, not from inside epic worktree)
        bd worktree create <task-name> --branch feature/<epic>/<task>
        Note: all worktrees branch from the same HEAD commit since they are
        created before any subagent commits. This is correct — task branches
        and the epic branch share the same starting point.
     b. Note the worktree path for dispatch

4. Dispatch all subagents in parallel
   One Agent tool call per task, ALL in the same message:
     Agent({
       description: "Implement Task N: <name>",
       prompt: "<implementer-prompt with 'Work from: <task-worktree-path>'>",
       subagent_type: "implementer"
     })

5. Two-stage review per task (can also run in parallel)
   Spec compliance review → Code quality review

6. For each task that passes review:
     cd <epic-worktree-path>
     git merge feature/<epic>/<task>
     bd worktree remove <task-name>

7. Run full test suite on epic worktree (integration check)
   If fail → invoke systematic-debugging → fix before next batch

8. Next batch: re-run bd ready --parent <epic-id>
   Repeat from step 2 until no tasks remain

9. If N == 1: sequential mode (existing behavior)
   Run in epic worktree directly, no per-task worktree needed
```

**Parallel cap:** Maximum 5 subagents per batch. If `bd ready --parent` returns >5 unblocked tasks, split into batches of 5.

### Failed Task Handling in Parallel Mode

When a parallel task fails review:

1. **Do not merge** its task branch into the epic branch.
2. **Option A — Re-dispatch:** Keep the task worktree. Re-dispatch a fix subagent with reviewer feedback. Re-review.
3. **Option B — Discard:** `bd worktree remove <task-name>` discards the branch. Task bead stays open for the next batch.
4. Other parallel tasks that passed review are still merged independently — one failure does not block the batch.

### Mode Selection Logic

```
tasks = bd ready --parent <epic-id>

if len(tasks) == 0:
    All done → finishing-a-development-branch
elif len(tasks) == 1:
    Sequential mode (run in epic worktree)
elif len(tasks) <= 5:
    Parallel batch (one worktree per task)
else:
    Split into batches of 5, execute first batch as parallel
```

## File Changes

### 1. `skills/subagent-driven-development/SKILL.md`

**New section: "Parallel Batch Mode"** (after "The Process")

Contents:
- Batch execution flow as described above
- Graphviz flowchart showing the batch loop:
  - `bd ready --parent` → batch size check → create per-task worktrees → parallel dispatch → parallel review → merge into epic → integration test → next batch
- Failed task handling (re-dispatch or discard)
- Parallel cap (max 5)
- Mode selection logic

**Rename existing "The Process" section** to include a preamble noting it describes sequential execution, with a cross-reference to Parallel Batch Mode.

**Updated Red Flags:**
- Remove: "Dispatch multiple implementation subagents in parallel (conflicts)"
- Add: "Dispatch parallel subagents WITHOUT per-task worktree isolation (each subagent MUST have its own bd worktree)"
- Add: "Dispatch more than 5 parallel subagents in a single batch (resource exhaustion)"
- Add: "Use Claude's `isolation: 'worktree'` parameter instead of bd worktree (bypasses beads DB sharing)"

**Updated Integration section:**
- Add: `dispatching-parallel-agents` — parallel dispatch pattern reference
- Add: `using-git-worktrees` — multiple worktrees for parallel work
- Add: `receiving-code-review` — review feedback loops in parallel review

### 2. `skills/dispatching-parallel-agents/SKILL.md`

**Updated Overview:** Change "multiple unrelated failures" framing to "multiple independent tasks without shared state." Bug-fixing becomes one use case.

**Updated "When to Use":** Add:
- 2+ independent plan tasks with no dependency edges
- Multiple independent subsystem changes
- Keep existing: 3+ test files failing with different root causes

**New section: "SDD Integration":**
- How SDD uses this skill's pattern (not invoked as a skill)
- SDD detects independent batches via `bd dep tree` / `bd ready --parent`
- Creates one `bd worktree` per task (orchestrator creates, subagent receives path)
- Dispatches all in one message via multiple `Agent` tool calls
- SDD handles merge-back; this skill describes the dispatch pattern

**Updated examples:** Add plan execution example showing per-task worktree pattern alongside existing test-failure example.

**Updated "When NOT to Use":** Add:
- Single task remaining (no parallelism benefit)
- Tasks that modify the same files (merge conflicts likely)

### 3. `skills/using-git-worktrees/SKILL.md`

**New section: "Multiple Worktrees for Parallel Subagents"** (before "Quick Reference"):
- Pattern: orchestrator creates epic worktree, then per-task worktrees branched from it
- Each subagent receives worktree path via "Work from: [directory]"
- After review: merge task branch into epic branch, remove task worktree
- Constraints: max 5 concurrent worktrees, orchestrator manages lifecycle (subagents never create/destroy worktrees)

**Updated Quick Reference table:** Add row:
- Situation: "Parallel subagent work"
- Action: "Create one worktree per task, orchestrator manages lifecycle"

**No changes to Iron Law or existing sections.** `bd worktree` remains mandatory.

## Testing Strategy

1. **Validate `bd worktree create --branch` behavior** — verify worktrees can be branched from a non-default branch (the epic branch).
2. **Validate `git merge` in epic worktree** — verify merging task branches works correctly after parallel work.
3. **Content verification** — `grep` for removed Red Flag text, verify new sections exist, check cross-references resolve.
4. **Existing test suite** — `run-skill-tests.sh` validates skill content structure and beads integration counts.

## Scope Boundaries

**In scope:**
- SDD parallel batch mode and per-task worktree isolation
- Generalizing dispatching-parallel-agents beyond bug-fixing
- Multi-worktree reference section in using-git-worktrees

**Out of scope (separate beads):**
- Resolving implementer prompt vs implementer agent conflict (bd-a4i)
- Per-task rollback via per-task branches without parallel mode (bd-j3s)
- FSM state machine corrections (bd-vtg epic — other child beads)
- Integration section additions to other skills (bd-4pw)
