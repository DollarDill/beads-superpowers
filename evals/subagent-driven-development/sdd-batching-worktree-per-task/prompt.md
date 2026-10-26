---
description: "Moved rule (references/batching.md): independent unblocked tasks run as a parallel batch, each in its own bd worktree, at most five per batch, never Claude's built-in worktree isolation. The plan has three independent tasks and the user asks for parallel execution; the agent reads batching.md and plans one bd worktree per task. Worktree, consent and the bd ready result are supplied in the prompt so the step is reachable without Bash."
tags: [subagent-driven-development, sdd-core, core-behaviour]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Execute the plan at `.internal/plans/2026-01-01-habit-reports.md` with subagent-driven development. Its three tasks are independent, and `bd ready --parent habits-r1` lists all three child beads as unblocked, so run them in parallel rather than one at a time. The epic worktree is already set up (this directory, branch `feature/habit-reports`) and you have my consent to work on this branch. There is no shell in this session, so if you need a command run, give me the exact command and I'll run it.
