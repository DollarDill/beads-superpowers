---
description: "Should not fire: the user explicitly skips brainstorming (using-superpowers user-override rule). The agent builds it."
tags: [brainstorming, grant-write]
model: sonnet
runs: 3
max_turns: 20
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

Add the dark-mode toggle to the settings page. Skip brainstorming and any design discussion, just build it.
