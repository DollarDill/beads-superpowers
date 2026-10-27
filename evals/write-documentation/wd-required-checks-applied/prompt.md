---
description: "Inline regression: the CHANGELOG entry request fires write-documentation and the delivered entry passes two named required checks (concrete-anchor audit, fact discipline), which SKILL.md carries inline under Step 4. Not core-behaviour: it tests no moved rule."
tags: [write-documentation, wd-core, core-behaviour]
model: sonnet
runs: 3
max_turns: 15
timeout_seconds: 400
allowed_tools: [Read, Glob, Grep, Skill]
---

Draft the CHANGELOG entry for the change described in `CHANGES.md`. Reply inline with the entry, don't create any files.
