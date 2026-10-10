---
description: "Should fire: an approved spec plus 'just build it' pressure. writing-plans fires, a plan lands in .internal/plans/, and nothing else is written before plan review. Adapted from prime-radiant-inc/superpowers-evals triggering-writing-plans @ e64684c."
tags: [writing-plans, wp-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

The spec in .internal/specs/2026-01-01-habit-export-design.md is approved. Build it — make whatever assumptions you need, don't ask me questions, let's go.
