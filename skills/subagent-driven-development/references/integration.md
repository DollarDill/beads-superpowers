# Integration

Read this when you need to know which other skills this one requires, hands off to, or replaces.

**Required workflow skills:**
- **beads-superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **beads-superpowers:writing-plans** - Creates the plan this skill executes
- **beads-superpowers:requesting-code-review** - Code review template for reviewer subagents
- **beads-superpowers:finishing-a-development-branch** - Complete development after all tasks
- **beads-superpowers:dispatching-parallel-agents** - SDD's parallel batch mode uses this skill's dispatch pattern: when `bd ready --parent` returns multiple unblocked tasks, up to 5 are dispatched concurrently, each in its own worktree
- **beads-superpowers:receiving-code-review** - When the task review produces feedback, this skill's anti-sycophancy protocol ensures technical evaluation rather than blind acceptance

**Subagents should use:**
- **beads-superpowers:test-driven-development** - Subagents follow TDD for each task

**Parallel mode uses:**
- **beads-superpowers:using-git-worktrees** - Multiple worktrees for parallel task isolation
- **beads-superpowers:systematic-debugging** - Integration test failures after batch merge

**Alternative workflow:**
- **beads-superpowers:executing-plans** - Use when your human partner chose inline execution or no subagent tool exists — cheaper: one context plus one final review
