---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers works much better with access to subagents. The quality of its work will be significantly higher if run on a platform with subagent support (such as Claude Code or Codex). If subagents are available, use beads-superpowers:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create epic bead and child beads for each task, then proceed

   Build a JSON plan file (`plan.json`) with the graph schema:

   ```json
   {
     "nodes": [
       {"key": "epic1", "title": "Epic: <plan-name>", "type": "epic", "priority": 2,
        "description": "<goal>\n\n## Success Criteria\n- <measurable outcome from the plan's Goal>"},
       {"key": "t1", "title": "Task 1: <title>", "type": "task", "priority": 2, "parent_key": "epic1",
        "description": "<summary>\n\n## Acceptance Criteria\n- <outcome from the task's Acceptance Criteria block>"},
       {"key": "t2", "title": "Task 2: <title>", "type": "task", "priority": 2, "parent_key": "epic1",
        "description": "<summary>\n\n## Acceptance Criteria\n- <outcome from the task's Acceptance Criteria block>"}
     ],
     "edges": [
       {"from_key": "t2", "to_key": "t1", "type": "blocks"}
     ]
   }
   ```

   Edge direction: `from_key` = dependent task (needs `to_key` done first). `type` is the dependency kind (`blocks`); it is optional and defaults to a blocking dependency.

   Required sections: `bd lint` requires `## Success Criteria` in the epic's description and `## Acceptance Criteria` in each task's description — embed them in the `description` strings as above (the graph schema has no separate criteria field).

   ```bash
   # Validate structure without writing:
   bd create --graph plan.json --dry-run

   # Create all nodes and edges atomically:
   bd create --graph plan.json
   ```

   > **Fallback** (if `--graph` is unavailable — older bd or schema skew): fall back to the sequential `bd create`/`bd dep add` loop:
   > ```bash
   > bd create "Epic: <plan-name>" -t epic --acceptance "All tasks pass, tests green"
   > bd create "Task 1: <title>" -t task --parent <epic-id> --acceptance "<task's Acceptance Criteria>"
   > bd dep add <task-2-id> <task-1-id>
   > ```

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
1. Get and claim the next task in one call: `bd ready --parent <epic-id> --claim` (use `bd ready --explain` to see dependency reasoning if task ordering is unclear)
2. **Check description quality** before implementing: if the claimed task's description is a bare title with no actionable steps or context, STOP — do not proceed with implementation. Surface the gap to the user.
3. Follow each step exactly (plan has bite-sized steps)
4. Run verifications as specified
5. Close the task: `bd close <task-id> --reason "description of what was completed"`
6. Check epic progress: `bd epic status <epic-id>` to see overall completion

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use beads-superpowers:finishing-a-development-branch
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
- **Production-Grade Doctrine:** never skip a verification or drop a task to make progress — `bd defer`/`bd human` are for genuine blockers, never a quiet way to descope required work. Never weaken, bypass, or remove a security control — a security regression is never acceptable.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## Integration

**Required workflow skills:**
- **beads-superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **beads-superpowers:writing-plans** - Creates the plan this skill executes
- **beads-superpowers:finishing-a-development-branch** - Complete development after all tasks

**Each execution step should use:**
- **beads-superpowers:test-driven-development** - RED-GREEN-REFACTOR for each task's implementation
