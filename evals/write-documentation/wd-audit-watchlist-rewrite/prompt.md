---
description: "Behaviour: revising a ~330-word README section fires write-documentation, the agent reads the moved references/audit-watchlist.md, and the revision cuts the watchlist fallback diction the draft repeats across paragraphs to at most one use each, without a new repeated stock phrase, keeping every fact and inventing none."
tags: [write-documentation, wd-core, core-behaviour]
model: sonnet
runs: 3
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

`DRAFT.md` is the "Why queuekit" section I've drafted for our README. Revise it so it's ready to publish, and reply inline with the full revised section; don't create files.
