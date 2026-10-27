---
description: "Should not fire: a read-only question about one task of an existing plan. subagent-driven-development stays silent and the reply answers the question."
tags: [subagent-driven-development, sdd-core, core-nofire]
model: sonnet
runs: 3
max_turns: 6
timeout_seconds: 120
allowed_tools: [Read, Glob, Grep, Skill]
---

What does Task 2 in `.internal/plans/2026-01-01-habit-export.md` change?
