---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers works much better with access to subagents. The quality of its work will be significantly higher if run on a platform with subagent support (such as Claude Code or Codex). If subagents are available, use superpowers:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create epic bead and child beads for each task, then proceed

   ```bash
   # Create epic — use --acceptance for success criteria
   bd create "Epic: <plan-name>" -t epic --acceptance "All tasks pass, tests green"

   # Create tasks — use --body-file for long descriptions, --acceptance for done criteria
   # Use --silent to capture the ID for dependency wiring
   TASK_ID=$(bd create "Task N: <title>" -t task --parent <epic-id> \
     --body-file <step-details-file> \
     --acceptance "<done criteria>" \
     --silent)
   ```

   > **Tip — rich bead fields:**
   > - `--body-file <file>` — avoids shell escaping issues with multi-line descriptions
   > - `--acceptance "<criteria>"` — stores done criteria separately from description
   > - `--design "<notes>"` or `--design-file <file>` — stores design context
   > - `--notes "<text>"` — stores open questions or supplementary context
   > - `--silent` — returns only the created ID (for scripting and dependency wiring)

   > **Tip — atomic dependency wiring:** After creating task beads, wire dependency chains atomically using `bd batch` to prevent orphaned deps if one operation fails:
   > ```bash
   > printf 'dep add <task-2-id> <task-1-id>\ndep add <task-3-id> <task-2-id>\n' | bd batch
   > ```
   > Note: `bd batch create` does not support `--description`, `--parent`, or `--acceptance` flags. Use regular `bd create` for task creation.

### Step 2: Execute Tasks

For each task:
1. **Check description quality** before claiming: if the task description is a bare title with no actionable steps or context, STOP — do not claim it. Surface the gap to the user or orchestrator.
2. Claim the task: `bd update <task-id> --claim`
3. Follow each step exactly (plan has bite-sized steps)
4. Run verifications as specified
5. Close the task: `bd close <task-id> --reason "description of what was completed"`
6. Check for next task: `bd ready --parent <epic-id>` (use `bd ready --explain` to see dependency reasoning if task ordering is unclear)
7. Check epic progress: `bd epic status <epic-id>` to see overall completion

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- The finishing skill includes the **Land the Plane** session close protocol (`bd close` → `bd dolt push` → `git push` → `git status`)
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Structured blocker handling:** When you hit a blocker, classify it and use the appropriate response:

| Blocker type | Action | Command |
|---|---|---|
| **Time-based** (waiting on deploy, external process) | Defer the task for later | `bd defer <task-id> --until="<date>"` |
| **Missing work** (prerequisite not built yet) | Create the missing task and wire dependency | `bd create "Missing: <title>" -t task --parent <epic-id>` then `bd dep add <blocked-id> <new-id>` |
| **Human decision needed** (architecture choice, ambiguous requirement) | Flag for human input | `bd human <task-id>` |

> **Discovered-work bead stamp:** `bd create "[spec] <title>" -t task --parent <epic-id> --notes "Severity:/Confidence:/Evidence:"` — see `verification-before-completion` → Agent-Filed Bead Discipline.

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent
- **Production-Grade Doctrine (see using-superpowers):** you are shipping to a production system with real users. Never skip a verification, drop a task, or accept a security regression to make progress. `bd defer`/`bd human` are for genuine blockers — never a quiet way to descope required work. Surface a warranted shortcut to the user; a security regression is never acceptable.

If you discovered something reusable, capture it before closing:

```bash
# Only if worth preserving for future sessions:
bd remember "lesson: <what worked or didn't in plan execution>"
```

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:finishing-a-development-branch** - Complete development after all tasks

**Each execution step should use:**
- **superpowers:test-driven-development** - RED-GREEN-REFACTOR for each task's implementation
