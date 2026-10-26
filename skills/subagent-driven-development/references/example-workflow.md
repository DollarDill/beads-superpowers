# Example Workflow

Read this when you want a worked run of this skill end to end: epic import, dispatch, review, a fix round, close.

```
You: I'm using Subagent-Driven Development to execute this plan.

[Read plan file once: .internal/plans/feature-plan.md]
[Extract all 5 tasks with full text and context]
[Create epic + tasks via bd import (parent-child rides the import; blocks wired after):]
[  bd create "Epic: <name>" -t epic -p 2 -d "<goal>, then 'Plan: <plan path>' and 'Spec: <spec path>' lines, then '## Success Criteria' on its own line"  -> note epic id]
[  Author tasks as JSONL, one per line, id OMITTED, each with a parent-child dep to the epic]
[    and "## Acceptance Criteria" in description; pipe to: bd import -]
[    (schema: bd import --help / bd export | jq -c 'select(.id=="<id>")'; confirm output has no "Skipped dependency")]
[  Wire task ordering (blocks): bd ready --parent <epic-id> --json -> child ids, then]
[  printf 'dep add <t3> <t1> blocks\ndep add <t3> <t2> blocks\n' | bd batch]

Task 1: Hook installation script

[Get Task 1 text and context (already extracted)]
[Dispatch implementation subagent with full task text + context]

Implementer: "Before I begin - should the hook be installed at user or system level?"

You: "User level (~/.config/superpowers/hooks/)"

Implementer: "Got it. Implementing now..."
[Later] Implementer:
  - Implemented install-hook command
  - Added tests, 5/5 passing
  - Self-review: Found I missed --force flag, added it
  - Committed

[Generate review package: bash scripts/review-package PLAN_FILE BASE HEAD]
[Dispatch single task reviewer with the brief, report file, and diff]
Task reviewer:
  Spec Compliance: ✅ Spec compliant - all requirements met, nothing extra
  Strengths: Good test coverage, clean
  Issues: None
  Task quality: Approved

[bd close <task-1-id> --reason "Completed: review clean, commits a1b2c3d..e4f5a6b"]

Task 2: Recovery modes

[Get Task 2 text and context (already extracted)]
[Dispatch implementation subagent with full task text + context]

Implementer: [No questions, proceeds]
Implementer:
  - Added verify/repair modes
  - 8/8 tests passing
  - Self-review: All good
  - Committed

[Generate review package + dispatch single task reviewer]
Task reviewer:
  Spec Compliance: ❌ Issues:
    - Missing: Progress reporting (spec says "report every 100 items")
    - Extra: Added --json flag (not requested)
  Issues (Important): Magic number (100)
  Task quality: Needs fixes

[Fix round 1 of max 5: dispatch a FRESH implementer with the findings — never resume]
Implementer: Removed --json flag, added progress reporting, extracted PROGRESS_INTERVAL constant

[Re-generate review package + dispatch scoped re-reviewer (./re-review-prompt.md)]
Re-reviewer:
  Named findings: all resolved
  Full test suite: green → PASS

[bd close <task-2-id> --reason "Completed: review clean, commits e4f5a6b..c7d8e9f"]

...

[After all tasks]
[Dispatch final code-reviewer]
Final reviewer: All requirements met, ready to merge

Done!
```
