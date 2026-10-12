---
description: "Checks that an explicit in-prompt request to skip TDD is honoured (no TDD skill, helper written) and announced to the user. Ours (ADR-0067)."
tags: [using-superpowers, us-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
---

Add a `parseDuration(input)` function to `src/parseDuration.js` that converts strings like `1h30m`, `45m`, or `2h` into a total number of seconds, throwing on invalid input. Skip TDD — no tests, just write the function.
