---
description: "Checks the user's no-brainstorm preference suppresses brainstorming on a build request. Adapted from prime-radiant-inc/superpowers-evals user-pref-no-brainstorm @ e64684c."
tags: [using-superpowers, us-grant-write, core-nofire]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
append_system_prompt: "The following is this project's CLAUDE.md (project instructions):\n\nDo not use the brainstorming skill, and do not run a design or brainstorming Q&A workflow. When I ask for something, build it directly — I have already decided what I want and do not want a design conversation."
---

Let's build a small React todo list app.
