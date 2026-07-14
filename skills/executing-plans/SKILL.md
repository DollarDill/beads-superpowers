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

   Create the epic, then import the child tasks as JSONL:

   ```bash
   # 1. Create the epic (→ note its id):
   bd create "Epic: <plan-name>" -t epic -p 2 -d "<goal>

## Success Criteria
- <measurable outcome from the plan's Goal>"

   # 2. Author the tasks as JSONL — one issue per line, id OMITTED (auto-assigned;
   #    a supplied colliding id would overwrite that bead and reset its omitted fields).
   #    Parent each to the epic; embed the bd lint-required '## Acceptance Criteria' in
   #    'description' (or the 'acceptance_criteria' field). Read `bd import --help` on
   #    first use; `bd export <id>` round-trips a real bead as a schema template.
   cat <<'EOF' | bd import -
{"title":"Task 1: <title>","issue_type":"task","priority":2,"description":"<summary>\n\n## Acceptance Criteria\n- <outcome>","dependencies":[{"depends_on_id":"<epic-id>","type":"parent-child"}]}
{"title":"Task 2: <title>","issue_type":"task","priority":2,"description":"<summary>\n\n## Acceptance Criteria\n- <outcome>","dependencies":[{"depends_on_id":"<epic-id>","type":"parent-child"}]}
EOF
   ```

   Confirm the import output shows no `Skipped dependency` (a dep to a missing target is skipped, not rolled back). `bd lint` requires `## Success Criteria` in the epic's description and `## Acceptance Criteria` in each task's — embed them as above.

   > **Wire task ordering (`blocks`) after the import.** `parent-child` rides the import, but inter-task `blocks` deps do not (children's ids are auto-assigned, so siblings can't reference each other in one file). Capture the ids **scoped to the parent** (a title grep collides with old beads), then wire ordering atomically:
   > ```bash
   > bd ready --parent <epic-id> --json   # → the child task ids
   > printf 'dep add <task-2-id> <task-1-id> blocks\n' | bd batch
   > ```
   > Note: `bd batch create` does not support `--description`/`--parent`/`--acceptance` — that is why task *creation* uses `bd import`, not `bd batch`.

### Step 2: Execute Tasks

For each task:
1. Get and claim the next task in one call: `bd ready --parent <epic-id> --claim` (use `bd ready --explain` to see dependency reasoning if task ordering is unclear)
2. **Check description quality** before implementing: if the claimed task's description is a bare title with no actionable steps or context, STOP — do not proceed with implementation. The task is now claimed: flag it for human decision (`bd label add <task-id> human`, per Structured blocker handling below) so it doesn't dangle in-progress, and surface to the user what the description is missing.
3. Follow each step exactly (plan has bite-sized steps)
4. Run verifications as specified
5. Close the task: `bd close <task-id> --reason "description of what was completed"`
6. Check epic progress: `bd epic status <epic-id>` to see overall completion

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several closes/updates/dep-adds = one `bd batch`; an epic + children =
> `bd import`, not a create-loop. Filter big outputs before they hit context
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
| **Human decision needed** (architecture choice, ambiguous requirement) | Flag for human input | `bd label add <task-id> human` |

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
