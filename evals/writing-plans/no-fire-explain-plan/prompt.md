---
description: "Should not fire: a read-only question about an existing plan."
tags: [writing-plans, wp-no-grant]
model: sonnet
runs: 3
max_turns: 6
timeout_seconds: 120
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion]
---

What does Task 2 of the plan in .internal/plans/ do? Just explain it.
