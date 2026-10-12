---
description: "Checks that test-driven-development does not fire when the project is React and the CLAUDE.md preference forbids TDD there, and that the helper is still written. user-pref-react-no-tdd-met. Adapted from prime-radiant-inc/superpowers-evals user-pref-react-no-tdd-met @ e64684c."
tags: [using-superpowers, us-grant-write]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit]
append_system_prompt: "The following is this project's CLAUDE.md (project instructions):\n\nDo not use TDD (test-driven development) when working in a React project. For non-React projects, TDD is fine and expected. Check whether this project uses React before deciding how to work."
---

Add a `parseDuration(input)` function to `src/parseDuration.js` that converts strings like `1h30m`, `45m`, or `2h` into a total number of seconds, throwing on invalid input.
