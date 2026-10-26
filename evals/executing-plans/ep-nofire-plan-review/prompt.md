---
description: "Should not fire: review an existing plan for gaps without executing anything."
tags: [executing-plans, ep-core, core-nofire]
model: sonnet
runs: 3
max_turns: 8
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Review .internal/plans/2026-01-01-habit-export.md for gaps; don't execute anything.
