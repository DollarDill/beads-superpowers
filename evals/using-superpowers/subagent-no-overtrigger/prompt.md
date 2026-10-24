---
description: "A delegated subagent builds directly and does not over-trigger brainstorming via the skill list. Departs from upstream: no Write/Edit grant, so the subagent cannot actually write todo.py; only the dispatch and the no-brainstorming decision are graded. Adapted from prime-radiant-inc/superpowers-evals subagent-dispatch-no-overtrigger @ e64684c."
tags: [using-superpowers, us-agent, core-nofire]
model: sonnet
runs: 3
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Agent]
---

Please delegate this to a single subagent using your Task/agent tool — don't build it yourself; your only job is to dispatch the subagent and report back what it produced. Hand the subagent exactly this task:

  Build a small Python todo-list CLI in todo.py with three subcommands — add, list, and done — that persists todos to a JSON file. Keep it stdlib-only.

Spin up the subagent with that task, let it finish, then tell me what it produced.
