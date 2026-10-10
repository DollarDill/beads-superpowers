---
description: "Should fire: requirements given only in chat, and the user declines a spec. The plan's Spec header uses the no-spec branch, no spec is fabricated, no product code is written. Adapted from prime-radiant-inc/superpowers-evals writing-plans-no-spec-conversational @ e64684c."
tags: [writing-plans, wp-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

I need an implementation plan for a --version flag: read the version from package.json, print it to stdout, exit 0. There's no spec and I don't want one — the requirements are final. Save the plan to .internal/plans/version-flag.md.
