---
description: "Moved rule (references/batching.md): independent unblocked tasks run as a parallel batch, each in its own bd worktree, at most five per batch, never Claude's built-in worktree isolation. The plan has six independent tasks and the user asks for parallel execution; the agent reads batching.md, puts at most five tasks in the first batch with one bd worktree each, and leaves the rest for the next bd ready. Worktree, consent, the bd swarm validate result and the bd ready result are supplied in the prompt so the step is reachable without Bash. Agent is granted so built-in worktree isolation is a real alternative and the no-builtin-isolation grader can fail."
tags: [subagent-driven-development, sdd-core, core-behaviour]
model: sonnet
runs: 3
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

Execute the plan at `.internal/plans/2026-01-01-habit-reports.md` with subagent-driven development. Its six tasks are independent: `bd swarm validate habits-r1` already ran clean (one wave, no dependency warnings), and `bd ready --parent habits-r1` lists all six child beads as unblocked, so run them in parallel rather than one at a time. The epic worktree is already set up (this directory, branch `feature/habit-reports`) and you have my consent to work on this branch. There is no shell in this session, so if you need a command run, give me the exact command and I'll run it.
