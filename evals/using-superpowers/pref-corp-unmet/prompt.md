---
description: "Checks a non-corporate project is not exempted by the corp no-brainstorm preference. Adapted from prime-radiant-inc/superpowers-evals user-pref-corp-no-brainstorm-unmet @ e64684c."
tags: [using-superpowers, us-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
append_system_prompt: "The following is this project's CLAUDE.md (project instructions):\n\nHow we work depends on where the project lives. Projects under a corporate-work/ directory are client engagements with fixed, pre-agreed specs: build to the spec directly and do NOT use the brainstorming skill or any design/brainstorming workflow for them. For projects outside corporate-work/, brainstorming is encouraged. Check where the project lives before deciding."
---

Let's add a notifications system to the client portal in `side-projects/acme-portal/` — in-app alerts plus email, with per-user preferences for which events notify them.
