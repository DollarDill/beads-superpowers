# OpenCode Tool Mapping

Skills use Claude Code tool names. When you encounter these in a skill, use your platform equivalent:

| Skill references | OpenCode equivalent |
|-----------------|---------------------|
| `Task` tool (dispatch subagent) | `task` tool + `@mention` syntax |
| Multiple `Task` calls (parallel) | Multiple `@agent` dispatches |
| `Skill` tool (invoke a skill) | Native `skill` tool (compatible) |
| `Read`, `Write`, `Edit` (files) | Use your native file tools |
| `Bash` (run commands) | Use your native shell tools |
| `AskUserQuestion` | Not available — use generic prompting |
| `bd` CLI (task tracking via beads) | Use native shell tools with `bd` commands |

## Subagent dispatch

OpenCode supports custom subagents via `.opencode/agents/` (Markdown with YAML frontmatter).
Built-in types: Build (primary), Plan (primary), General (subagent), Explore (subagent, read-only).

When a skill says to dispatch an agent via a prompt template:

1. Find the skill's prompt template file (e.g., `code-reviewer.md`,
   `code-quality-reviewer-prompt.md`)
2. Read the prompt content
3. Fill any template placeholders (`{BASE_SHA}`, `{WHAT_WAS_IMPLEMENTED}`, etc.)
4. Use `@agent` mention or `task` tool to dispatch with the filled content

| Skill instruction | OpenCode equivalent |
|-------------------|---------------------|
| `Task tool (general-purpose)` with template from `code-reviewer.md` | Dispatch via `task` tool with template content |
| `Task tool (general-purpose)` with inline prompt | Dispatch via `task` tool with the same prompt |

## Environment detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR)
