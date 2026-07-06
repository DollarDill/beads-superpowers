# Pi Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Pi these resolve to the tools below.

| Action skills request | Pi equivalent |
| --- | --- |
| Dispatch a subagent (`Subagent (general-purpose):` template) | Use an installed subagent tool such as `subagent` from `pi-subagents` if available |
| Task tracking ("create a todo", "mark complete") | task tracking uses the `bd` (beads) CLI via the shell — Do NOT use TodoWrite |

## Subagents

Pi core does not ship a standard subagent tool. The `pi-subagents` package is a strong optional companion and provides a `subagent` tool with single-agent, chain, parallel, async, forked-context, and resume/status workflows. If no subagent tool is available, do not fabricate `Task` calls; execute sequentially in the current session or explain that the optional subagent capability is not installed.

This plugin tracks ALL tasks with the `bd` (beads) CLI run via the shell — Do NOT use TodoWrite. Use `bd create`, `bd update`, and `bd close` commands via `bash`. Run `bd prime` at the start of each session to load persistent project memory.

- Structured questions: pi has **no built-in question tool** (unless a question extension is installed) — always present numbered plain-text options + STOP for the user's reply.
