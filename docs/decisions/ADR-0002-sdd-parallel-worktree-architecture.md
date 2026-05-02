# ADR-0002: SDD Parallel Batch Mode with Per-Task Worktree Isolation

**Date:** 2026-05-02
**Status:** Accepted
**Deciders:** Dillon Frawley

## Context

Subagent-Driven Development (SDD) creates a single `bd worktree` for the entire epic and runs all implementer subagents sequentially in that shared worktree. This design has three problems:

1. **No per-task rollback.** If a task fails review, its commits are mixed with prior successful task commits on the same branch. Undoing a single task requires interactive rebase.
2. **No parallel execution.** Independent tasks (no dependency edges between them) run sequentially even though they could safely run concurrently — each in its own isolated worktree.
3. **Two competing worktree systems.** Claude Code's `Agent` tool has `isolation: "worktree"` which uses `EnterWorktree` (Claude-native), bypassing `bd worktree` entirely. Subagent worktrees created this way don't share the beads database.

A related concern: the SDD Red Flags section explicitly forbids parallel dispatch ("Dispatch multiple implementation subagents in parallel (conflicts)"). That prohibition was correct when all subagents shared a single worktree, but becomes unnecessary when each subagent has its own isolated worktree and branch.

## Decision

1. **Per-task worktree isolation with parallel batch mode.** The orchestrator creates one `bd worktree` per independent task, dispatches subagents in parallel (one per worktree), and merges results back after review.

2. **Epic worktree as integration point.** The orchestrator creates an epic-level `bd worktree` first. Each parallel task gets a child worktree branched from the epic branch. After task review passes, the task branch is merged into the epic branch. Full test suite runs on the epic worktree after each batch merge.

3. **Automatic parallelism detection via `bd dep tree`.** The orchestrator runs `bd dep tree` (or equivalent `bd ready --parent <epic-id>`) to identify tasks with no unresolved dependencies on other open tasks. These form a batch. After a batch completes, re-check for newly unblocked tasks. No plan format changes required.

4. **SDD owns the orchestration; other skills support.** The SDD skill gets a new "Parallel Batch Mode" section owning the full flow (dep tree analysis → worktree creation → parallel dispatch → merge → integration test). `dispatching-parallel-agents` is generalized from bug-fixing to any independent parallel work but SDD doesn't invoke it as a skill — it uses the pattern (multiple `Agent` tool calls in one message). `using-git-worktrees` gets a reference section for multi-worktree patterns.

## Rationale

- Per-task worktrees solve all three problems simultaneously: isolation enables rollback (discard the task branch), parallelism (no shared state), and correct beads integration (`bd worktree create` shares the beads DB).
- The epic worktree as integration point provides a staging area where the orchestrator can run the full test suite after merging a batch — catching integration issues before they reach the source branch.
- Automatic detection via `bd dep tree` leverages dependency data that `writing-plans` already creates (via `bd dep add`). No additional annotation burden on the planner.
- SDD owning the flow keeps one source of truth for the orchestration logic. Having SDD delegate to `dispatching-parallel-agents` as a skill would split the flow across two files and add a dependency hop with no benefit — the parallel dispatch is 2-3 lines of Agent tool calls, not a complex procedure.

## Consequences

- **Positive:** Independent plan tasks execute in parallel, reducing wall-clock time proportional to the number of independent tasks per batch.
- **Positive:** Failed tasks can be cleanly rolled back by discarding their worktree branch. No interactive rebase needed.
- **Positive:** Each subagent gets full filesystem isolation — no file conflicts between concurrent implementers.
- **Positive:** The SDD Red Flag against parallel dispatch can be removed (was a workaround for shared-worktree conflicts, not a fundamental design constraint).
- **Negative:** More `bd worktree create/remove` operations per epic. Each parallel task has worktree creation + cleanup overhead.
- **Negative:** Merge conflicts between parallel task branches are possible when tasks modify nearby (but not identical) files. The post-batch integration test on the epic worktree catches these.
- **Risk:** `bd worktree create` must support creating worktrees branched from a non-default branch (the epic branch). If it doesn't, worktrees will branch from HEAD instead, requiring manual branch management. Need to verify `bd worktree create --branch` behavior.
