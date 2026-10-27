---
description: "Should fire: a request for release notes from a scaffolded change list. write-documentation fires because release notes are human-facing prose."
tags: [write-documentation, wd-core, core-fire]
model: sonnet
runs: 3
max_turns: 10
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

Write the release notes for the next datekit release. The changes are listed in CHANGES.md. Reply inline, don't create any files.
