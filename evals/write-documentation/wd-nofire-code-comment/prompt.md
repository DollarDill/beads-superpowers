---
description: "Should not fire: a one-line docstring is a code comment, which write-documentation excludes (When NOT to Use: code comments and docstrings)."
tags: [write-documentation, wd-core, core-nofire]
model: sonnet
runs: 3
max_turns: 8
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Add a one-line docstring to `src/parse.js`'s `parseDate`. Reply inline with the exact line you'd add; don't edit the file.
