---
description: "With a project rule putting specs in docs/specs/, an approved design lands there and not in .internal/specs/. Adapted from prime-radiant-inc/superpowers-evals user-pref-spec-location @ e64684c."
tags: [using-superpowers, us-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
append_system_prompt: "The following is this project's CLAUDE.md (project instructions):\n\nProject convention: write ALL design specs and plans under docs/specs/ (for example docs/specs/url-shortener-design.md). Do NOT use .internal/specs/ or .internal/plans/ — keep design docs in docs/specs/."
---

We finished brainstorming this and the design below is approved — continue the brainstorming hand-off and write the design spec now. URL shortener: POST /shorten takes a long URL and returns a 7-character code; GET /:code redirects (301) to the long URL; unknown codes return 404; storage is an in-memory Map.
