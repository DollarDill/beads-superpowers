# Example Workflow

Read this when you want a worked end-to-end transcript of an inline run: setup, a task, a plan conflict ruled from the spec, the final review and the closing lists.

```
You: I'm using the executing-plans skill to implement this plan inline.

[Setup: feature branch verified; workspace .internal/sdd/feature-plan/ resolved — sibling plan directories left alone]
[No open epic anchored "Plan: .internal/plans/feature-plan.md" — fresh: epic created, 5 tasks imported, ordering wired]
[Read plan once; spec read; test-driven-development loaded]
[Pre-flight scan: 2 shared-interface rows, clean; appended to the epic's notes]

Task 1: Hook installation script

[bd ready --parent <epic-id> --claim → Task 1; brief read; BASE a1b2c3d]
[Step 1: write failing test — written]
[Step 2: run it — FAIL: install_hook not defined. Matches Expected.]
[Step 3: implement — written]
[Step 4: run it — PASS 1/1. Matches Expected.]
[Step 5: commit — d4e5f6a]
[Contract: tests ran, output read, no deviations]
[npm test -- hooks → task-1-tests.log, 1/1 pass; bd close: complete (commits a1b2c3d..d4e5f6a, tests: npm test -- hooks → 1/1 pass; rulings: 0)]

Task 2: Recovery modes

[Claimed; heartbeat on regaining control; brief read; BASE d4e5f6a]
[Step 2: run failing test — FAIL, but on an import error: Task 1 exported
 installHook, the brief consumes install_hook]
[Task 2: Ruling: use installHook — settled by spec §Hook API, which names installHook — cost if wrong: one rename; appended to the epic's notes]
[Steps 2-5 as planned; commit b7c8d9e]
[npm test -- recovery → task-2-tests.log, 8/8 pass; bd close: complete (commits d4e5f6a..b7c8d9e, tests: npm test -- recovery → 8/8 pass; rulings: 1)]

...

[No open children under the epic: review-package plan MERGE_BASE HEAD, completion lines appended; dispatch code-reviewer on the most capable tier]
Reviewer: One Important finding — progress reporting interval hardcoded. Two Minor.
[Re-grade by effect: Important stands; minors → epic notes as deferred]
[Fix pass: test_progress_interval_configurable RED → extract PROGRESS_INTERVAL → GREEN; suite 12/12; commit]
[Epic notes: Final: fixed hardcoded interval — test_progress_interval_configurable RED→GREEN, suite 12/12]

Rulings I made:
- Task 2: install_hook → installHook — settled by spec §Hook API — cost if wrong: one rename

Deferred minors:
- README lacks a usage example
- recovery.js could split verify/repair into two files

Fixes applied:
- hardcoded interval — test_progress_interval_configurable RED→GREEN, suite 12/12

[Delete this plan's workspace — git and beads are the record now; sibling plan directories untouched]

Using beads-superpowers:finishing-a-development-branch.
```
