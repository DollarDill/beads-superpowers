# Hermes Agent Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Hermes Agent these resolve to the tools below.

## Tools

| Action skills request | Hermes tool |
|---|---|
| Read a file | `read_file` |
| Create a new file | `write_file` |
| Edit a file (targeted patch) | `patch` |
| Run a shell command | `terminal` |
| Search file contents | `search_files` |
| Find files by name | `terminal` with `find` |
| Fetch a URL / read a webpage | `web_extract(urls=[...])` |
| Search the web | `web_search(query=...)` |
| Dispatch a subagent | `delegate_task(goal=..., context=..., toolsets=[...], role="leaf")` |
| Task tracking ("create a todo", "mark complete") | task tracking uses the `bd` (beads) CLI via the shell — Do NOT use TodoWrite |
| Invoke a skill | `skill_view("skill-name")` |

## Task tracking

This plugin tracks ALL tasks with the `bd` (beads) CLI run via the shell — Do NOT use TodoWrite. When a skill says to create a todo list or track tasks, use `bd create`, `bd update`, and `bd close` via the `terminal` tool. Run `bd prime` at the start of each session to load persistent project memory.

## Instructions file

When a skill mentions "your instructions file," on Hermes Agent this is **`AGENTS.md`** in the project directory, or **`SOUL.md`** globally at `~/.hermes/SOUL.md`. In this repository `AGENTS.md` is a symlink to `CLAUDE.md`.

## Invoking a skill

Hermes Agent has a `skills` toolset with `skill_view` and `skills_list`. This plugin registers every skill with the native loader at load time, so:

```text
skill_view("brainstorming")
skill_view("test-driven-development")
```

If a namespaced lookup returns "not found", retry with the bare name — see the Skill Name Resolution section of `using-superpowers`.

## Subagent dispatch

Use `delegate_task` to spawn isolated subagents for parallel or sequential workstreams:

```text
delegate_task(goal="...", context="...", toolsets=[...], role="leaf")
```

If `delegate_task` is unavailable, do the work inline rather than inventing tool calls.
