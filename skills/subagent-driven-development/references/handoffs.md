# File Handoffs and Prompt Templates

Read this when you are about to dispatch an implementer or reviewer for the first time in a plan.

## File Handoffs

Hand task text and review diffs to subagents as **files**, not pasted context — this keeps large text out of your own context and gives subagents a single thing to read.

- Before dispatching an implementer, run `bash scripts/task-brief <plan-file> <N>` → writes `.internal/sdd/<plan-basename>/task-<N>-brief.md`.
- The implementer writes its full report to `.internal/sdd/<plan-basename>/task-<N>-report.md` (you name the path via `[REPORT_FILE]`); the reviewer reads it as a file. Fix rounds **append** to it.
- Before dispatching the reviewer, run `bash scripts/review-package <plan-file> <BASE> <HEAD>` → writes `.internal/sdd/<plan-basename>/review-<base7>..<head7>.diff`. `BASE` is the commit recorded before the implementer ran — never `HEAD~1`.
- The reviewer is **read-only**: it must not mutate the working tree, the index, HEAD, or branch state.
- The workspace is resolved **per plan, per working tree** (`bash scripts/sdd-workspace <plan-file>`). Two plans in one tree never share brief filenames, and in Parallel Batch Mode each `bd worktree` gets its own tree.

## Prompt Templates

Dispatch via the `Agent` tool:

1. `Read` the prompt template file
2. Use its content as the `prompt` parameter
3. Use `subagent_type: "general-purpose"` (do NOT use `"implementer"` — that is Claude Code's built-in implementer agent with its own system prompt, which overrides the prompt template)

- `./implementer-prompt.md` - Dispatch implementer subagent
- `./task-reviewer-prompt.md` - Dispatch the single task reviewer subagent (returns spec-compliance + code-quality verdicts in one read-only pass)
- `./re-review-prompt.md` - Scoped re-reviewer for fix rounds (checks the named findings only; PASS also requires a green suite)
