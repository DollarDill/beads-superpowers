---
description: "Behaviour: tightening a README paragraph fires write-documentation, the agent reads the moved references/audit-watchlist.md, and the rewrite cuts the opener repeated in four sentences while keeping the one right-word use of a watchlisted term (test harness) and every fact."
tags: [write-documentation, wd-core, core-behaviour]
model: sonnet
runs: 3
max_turns: 15
timeout_seconds: 400
allowed_tools: [Read, Glob, Grep, Skill]
---

Tighten the paragraph in `NOTES.md` for our README. Reply inline with the rewrite; don't create files.
