---
description: "Should fire: write the plan for an approved spec to a named path. The plan has the required sections, no placeholders, covers every requirement, and cites the spec instead of restating it. Folds in prime-radiant-inc/superpowers-evals cost-spec-plan-duplication @ e64684c."
tags: [writing-plans, wp-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

The spec in .internal/specs/2026-01-01-habit-export-design.md is approved. Write the implementation plan and save it to .internal/plans/habit-export.md.
