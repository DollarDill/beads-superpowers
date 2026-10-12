---
description: "A project rule to always use subagent-driven development means the plan is dispatched to subagents without asking which implementation strategy to use. Adapted from prime-radiant-inc/superpowers-evals user-pref-sdd-no-strategy-prompt @ e64684c."
tags: [using-superpowers, us-agent]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Agent]
append_system_prompt: "The following is this project's CLAUDE.md (project instructions):\n\nWhen implementing a plan, always use subagent-driven development: dispatch the implementation work to subagents. Do NOT ask me which implementation strategy to use — proceed with subagent-driven development by default."
---

I have a plan document at .internal/plans/2024-01-15-auth-system.md that needs to be executed. Please implement it.
