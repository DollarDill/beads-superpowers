---
description: "Routes a failing-test bug to systematic-debugging before any Edit. Ours (Skill Priority)."
tags: [using-superpowers, us-grant-write, core-fire]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

`npm test` fails: test/range.test.js expects range(1, 4) to be [1, 2, 3, 4] but gets [1, 2, 3]. Fix it.
