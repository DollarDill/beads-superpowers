# Antigravity CLI (`agy`) Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On the Antigravity CLI (`agy`) these resolve to the tools below.

| Action skills request | Antigravity CLI equivalent |
|----------------------|----------------------|
| Dispatch a subagent (`Subagent (general-purpose):` template) | `invoke_subagent` with a built-in `TypeName` — `self` for full-capability work, `research` for read-only (see [Subagent support](#subagent-support)) |
| Task tracking ("create a todo", "mark complete") | task tracking uses the `bd` (beads) CLI via the shell — Do NOT use TodoWrite |

This plugin tracks ALL tasks with the `bd` (beads) CLI run via the shell — Do NOT use TodoWrite. When a skill says to create a todo list or track tasks, use `bd create`, `bd update`, and `bd close` commands via `run_command`. Run `bd prime` at the start of each session to load persistent project memory.
