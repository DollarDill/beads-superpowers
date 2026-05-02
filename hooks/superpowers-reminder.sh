#!/usr/bin/env bash
# superpowers-reminder.sh — UserPromptSubmit hook for Claude Code
# Injects a reminder to check superpowers skills on every user prompt.
# Matcher: "" (fires on every prompt submission)
set -euo pipefail

cat << 'REMINDER'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "SUPERPOWERS REMINDER: Before responding, check if any beads-superpowers skill applies to this task. Key triggers:\n- Bug/test failure → beads-superpowers:systematic-debugging\n- Writing code → beads-superpowers:test-driven-development\n- New feature/design → beads-superpowers:brainstorming\n- Challenge/stress-test design → beads-superpowers:stress-test\n- Writing a plan → beads-superpowers:writing-plans\n- Executing a plan → beads-superpowers:subagent-driven-development or beads-superpowers:executing-plans\n- Research question → beads-superpowers:research-driven-development\n- Complex task (6+ files) → beads-superpowers:using-git-worktrees\n- About to claim done → beads-superpowers:verification-before-completion\n- Code review needed → beads-superpowers:requesting-code-review\n- Received review feedback → beads-superpowers:receiving-code-review\n- Writing human-facing prose → beads-superpowers:write-documentation\n- Branch complete → beads-superpowers:finishing-a-development-branch\nAlso available: document-release, getting-up-to-speed, dispatching-parallel-agents, project-init, setup, writing-skills, auditing-upstream-drift\nIf even 1% chance a skill applies, you MUST invoke it via the Skill tool."
  }
}
REMINDER

exit 0
