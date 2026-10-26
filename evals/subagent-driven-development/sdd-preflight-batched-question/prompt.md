---
description: "Moved rule (references/preflight.md): before Task 1, SDD scans the plan against its spec and asks about every conflict the spec does not settle in one batched question. The plan's Tasks 1 and 2 each contradict a Global Constraint the spec is silent on; the agent reads preflight.md, asks once with both conflicts beside the plan text, and dispatches nothing. Worktree, consent and beads are supplied in the prompt so the step is reachable without Bash."
tags: [subagent-driven-development, sdd-core, core-behaviour]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Execute the plan at `.internal/plans/2026-01-01-habit-export.md` with subagent-driven development, a fresh subagent per task. The worktree is already set up (this directory, branch `feature/habit-export`) and you have my consent to work on this branch. The plan's beads are already filed: epic `habits-x1`, with one open child bead per task. There is no shell in this session, so if you need a command run, give me the exact command and I'll run it.
