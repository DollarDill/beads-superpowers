---
type: llm
---

PASS only if all of these hold: (1) the reply plans a separate bd worktree for each of the plan's three tasks: three distinct worktrees (for example three `bd worktree create` commands with distinct paths or branches), not one worktree shared by the tasks; (2) no batch it plans holds more than five subagents; (3) it does not use Claude's built-in `isolation: "worktree"` Agent parameter, plain `git worktree add`, or the shared epic directory as a task's isolation (saying it avoids these is fine). FAIL if any task lacks its own bd worktree, if the tasks share one worktree or run one at a time in the epic directory, if any batch holds more than five subagents, or if the reply substitutes another isolation mechanism for bd worktree.
