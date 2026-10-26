---
description: "Should fire: the user asks to execute an existing plan task by task with a fresh subagent per task, with the worktree set up and consent given. subagent-driven-development fires."
tags: [subagent-driven-development, sdd-core, core-fire]
model: sonnet
runs: 3
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Execute the plan at `.internal/plans/2026-01-01-habit-export.md` task by task with a fresh subagent per task. The worktree is set up and you have my consent to work on this branch.
