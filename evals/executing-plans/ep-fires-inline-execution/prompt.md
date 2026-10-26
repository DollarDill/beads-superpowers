---
description: "Should fire: an explicit request to execute an existing plan inline, no subagents. executing-plans fires."
tags: [executing-plans, ep-core, core-fire]
model: sonnet
runs: 3
max_turns: 10
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

Execute .internal/plans/2026-01-01-habit-export.md inline in this session — no subagents.
