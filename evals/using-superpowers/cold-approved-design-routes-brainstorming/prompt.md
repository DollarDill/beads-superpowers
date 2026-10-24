---
description: "A cold approved design (no brainstorm this session) is routed through brainstorming's spec step: spec lands in .internal/specs/, not docs/, and the reply stops at the spec-review gate. Ours (c87v4)."
tags: [using-superpowers, us-grant-write, core-fire]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

The design below is approved — write the design spec now. URL shortener: POST /shorten takes a long URL and returns a 7-character code; GET /:code redirects (301) to the long URL; unknown codes return 404; storage is an in-memory Map.
