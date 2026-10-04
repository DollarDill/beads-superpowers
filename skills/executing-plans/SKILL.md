---
name: executing-plans
description: Use when executing an implementation plan inline in this session as the implementer yourself — your human partner chose inline execution at the writing-plans handoff, or no subagent tool is available
---

# Executing Plans

Execute the plan yourself, task by task, in this session: no implementer subagent per task, no reviewer per task. One fresh-context review of the whole branch at the end.

**Announce at start:** "I'm using the executing-plans skill to implement this plan inline."

**Why inline:** beads-superpowers:subagent-driven-development pays for a fresh implementer and a fresh reviewer on every task, each re-reading the codebase from zero. Inline execution pays for one context (yours) plus one reviewer at the end. What it gives up — a fresh context per task and a second pair of eyes per task — this skill recovers by other means: the brief is the spec, beads are your memory, TDD is the per-task gate, and the final reviewer is the second pair of eyes. A fully specified plan runs well on the standard capability tier; the final review is where the most capable tier earns its cost. Tell your human partner so when they choose inline.

**Core principle:** The plan already did the thinking. Execute it exactly, prove each step with a test you watched fail and then pass, and leave a record in beads that survives your own forgetting.

**Narration:** between tool calls, narrate at most one short line — beads and the tool results carry the record.

**Continuous execution:** Do not pause to check in between tasks. Your human partner chose inline to spend less, not to answer "should I continue?" after every task. Execute all tasks from the plan without stopping; only the stops below stop you.

## Rulings and Escalation

**You MAY rule when the spec unambiguously settles it. Everything else escalates.** Ruling from the
spec is *reading the binding authority*, not descoping; deciding a requirement is not worth meeting
stays your human partner's call. Enumerated may-rule / must-stop lists:
[../subagent-driven-development/references/rulings-and-escalation.md](../subagent-driven-development/references/rulings-and-escalation.md) — read it the first time
a conflict surfaces. **Precedence: must-stop wins** where both could apply, and **a security finding
is NEVER rulable and never parkable**, whatever the plan or spec says (`../subagent-driven-development/references/breaker-trip.md`).

**Every ruling cites its authority** — `Ruling: <what you decided> — settled by <spec §/heading> —
<what it costs if wrong>`. No citable spec location means it is **by definition not spec-settled**:
escalate. Fill-or-fail, not a judgment call.

**Ruling budget:** the third ruling in one run stops you — surface every ruling so far with its cost-if-wrong and continue only on approval. A plan that needs a fourth is "every path forward is a guess". The budget counts task-loop rulings only: `Final:` rulings from the final review do not count toward it, every one is still listed under "Rulings I made", and a `Final:` item with no citable spec § still escalates.

**The stops.** Irreversible or destructive operations; security-sensitive actions; side effects outside this worktree (a merge, a push to a shared branch, a publish); a plan so broken every path forward is a guess; the ruling budget. Stopping is beads-native — the blocker table under "When to Stop" says how.

## When to Use

- You have a plan from beads-superpowers:writing-plans and your human partner chose inline execution at the handoff.
- Your harness has no subagent tool (see `../using-superpowers/references/`). Never fabricate a dispatch; run the plan here.
- Tasks are mostly independent — the same precondition as beads-superpowers:subagent-driven-development.

Prefer subagent-driven development when the plan has more than about eight tasks, when a task's brief plus its expected test output would not fit one uncompacted stretch, or when the plan touches auth, secrets, permissions, input validation or data deletion. Inline over a long plan still works — beads make it recoverable — but the last tasks get the least of you.

## Setup

1. Isolated workspace first — use beads-superpowers:using-git-worktrees. Never start on a main/master branch without your human partner's explicit consent.
2. Plan workspace: `bash ../subagent-driven-development/scripts/sdd-workspace PLAN_FILE` prints this plan's git-ignored directory under `.internal/sdd/` — briefs, review packages and test logs live there. Shared with subagent-driven development, so a plan can change executors mid-flight.
3. Find or create the ledger. Locate an existing epic by its `Plan:` anchor, which lives in the description (`bd search` matches titles only): `bd list -t epic --status open --desc-contains "Plan: <plan file path>"`. **Resuming:** first `bd list --parent <epic-id> --status in_progress` — a task interrupted mid-flight is still claimed, and `bd ready` excludes it. Check its commits against `git log` before redoing anything, then finish it through the Task Loop from step 2. Then `bd ready --parent <epic-id>` is the remaining work; a closed child's completion line names its commit range — check it against `git log` before touching anything, and trust bd and git over your recollection. **Fresh:** create the epic, then import the tasks:

   ```bash
   # 1. Create the epic (→ note its id). Plan: and Spec: are the resume anchors.
   bd create "Epic: <plan-name>" -t epic -p 2 -d "<goal>
Plan: <plan file path>
Spec: <spec file path or 'none reachable'>

## Success Criteria
- <measurable outcome from the plan's Goal>"

   # 2. Author the tasks as JSONL — one issue per line, id OMITTED (auto-assigned;
   #    a supplied colliding id would overwrite that bead and reset its omitted fields).
   #    Parent each to the epic; embed the bd lint-required '## Acceptance Criteria' in
   #    'description'. Read `bd import --help` on first use; `bd export | jq -c 'select(.id=="<id>")'` round-trips
   #    a real bead as a schema template.
   cat <<'EOF' | bd import -
{"title":"Task 1: <title>","issue_type":"task","priority":2,"description":"<summary>\n\n## Acceptance Criteria\n- <outcome>","dependencies":[{"depends_on_id":"<epic-id>","type":"parent-child"}]}
{"title":"Task 2: <title>","issue_type":"task","priority":2,"description":"<summary>\n\n## Acceptance Criteria\n- <outcome>","dependencies":[{"depends_on_id":"<epic-id>","type":"parent-child"}]}
EOF
   ```

   Confirm the import output shows no `Skipped dependency`. `bd lint` requires `## Success Criteria` in the epic and `## Acceptance Criteria` in each task.

   > **Wire task ordering (`blocks`) after the import.** `parent-child` rides the import, but inter-task `blocks` deps do not. Capture the ids **scoped to the parent**, then wire ordering atomically:
   > ```bash
   > bd ready --parent <epic-id> --json   # → the child task ids
   > printf 'dep add <task-2-id> <task-1-id> blocks\n' | bd batch
   > ```
   > Note: `bd batch create` does not support `--description`/`--parent`/`--acceptance` — that is why task *creation* uses `bd import`, not `bd batch`.

4. Read the plan once — its context and Global Constraints — and the Spec it names: the spec is the authority the plan argues from, and conflicts inside the plan resolve against it. No reachable spec → `bd update <epic-id> --append-notes "No spec reachable — rulings are provisional"`.
5. **REQUIRED SUB-SKILL:** load beads-superpowers:test-driven-development now, before Task 1. It governs every step of every task below.
6. Pre-flight scan: for every task that consumes what an earlier task produces, one row — the two tasks, what one produces against what the other consumes, what you found — appended with `bd update <epic-id> --append-notes "Pre-flight: <row>"`. Tasks that share nothing get no row; a plan whose tasks share nothing gets the single line `Pre-flight: no shared interfaces`. Rule on each conflict the spec settles; escalate the rest. Record each ruling beside its row.

## The Task Loop

Everything you print, and every tool result, stays resident in your context. Redirect long test output to a file in the workspace and read its tail; read a brief, not the whole plan.

### 1. Take the task

- `bd ready --parent <epic-id> --claim` claims the next task in one call (`bd ready --explain` if the ordering is unclear). Then `bash ../subagent-driven-development/scripts/task-brief PLAN_FILE N` prints the brief path; `BASE=$(git rev-parse HEAD)` is the commit the task's range is cut from. Read the brief for every task, including ones you remember from setup: what you remember is a summary, the brief has the exact values.
- **Check description quality** before implementing: a bare title with no actionable steps means STOP — the task is now claimed, so flag it (`bd label add <task-id> human`, per the blocker table) and surface what the description is missing.

> **`--claim` consent boundary.** This skill's autonomous take-next flow is the one place `bd ready --claim` is legitimate. That autonomous `--claim` is FORBIDDEN wherever the user picks the work (orientation, brainstorming, session close) — the consent gate binds even when this skill is not loaded.

> **Leases (bd v1.3.1).** A claim carries a lease (default 5 minutes) that expires unless heartbeated. As the plan's bead owner, run `bd heartbeat <id>` on every in-flight bead each time you regain control: after each subagent return, or at each task boundary when executing inline. If the heartbeat fails, the claim was reclaimed: stop and check `bd show <id>` before you commit, close or re-claim anything. **Never** `bd reclaim`, `bd unclaim --force`, or `bd update --force` another actor's claim without your human partner's consent.

Every tool call is a turn that re-reads your whole context. Bookkeeping rides along with work — a ledger append in the same call as the commit, never in a call of its own.

### 2. Work the steps

The plan's steps are already in RED-GREEN order; follow them under beads-superpowers:test-driven-development. A test step's code is written first and run first. Watching it fail is a step, not a formality.

Every step that runs a command has an `Expected:` line. Run it, read the output, compare. Three outcomes:

- **Matches.** Next step.
- **The code is wrong.** Use beads-superpowers:systematic-debugging. Find the cause; never patch the symptom to make the output match.
- **The plan is wrong** — a step contradicts the spec, an interface from an earlier task does not match what this task consumes, a command that cannot work. If the spec settles it, rule on the smallest change that satisfies the spec and ledger it: `bd update <epic-id> --append-notes "Task <N>: Ruling: <what> — settled by <spec §> — <cost if wrong>"`. Otherwise escalate via the blocker table. The ruling is carried, not remembered: later tasks read it from the epic.

Commit as the plan's commit steps say, with the task bead id in the message. A task that spans several commits is fine; BASE is what the review range is cut from, never `HEAD~1`.

### 3. The completion contract

Before a task closes, all of the following are true, with evidence in this session — not inferred from the diff looking right:

- Every test the brief names exists and ran in this task, and you read the output.
- The final test run for the task passed — see step 4; the log is the artifact.
- Every `Expected:` line in the brief was compared against real output.
- Every deviation from the brief has a `Ruling:` line in the epic's notes, or an escalation.

**REQUIRED SUB-SKILL:** beads-superpowers:verification-before-completion governs the claim. If any item is missing, the task is not complete: finish it.

### 4. Complete the task

Run the test command the brief names for the whole task, redirected to the workspace: `<cmd> > <workspace>/task-<N>-tests.log 2>&1; tail -20 <workspace>/task-<N>-tests.log`. Only if it passed:

`bd close <task-id> --reason "complete (commits <base7>..<head7>, tests: <cmd> → <last result line>; rulings: <n>)"`

A red run closes nothing; the task is not complete. Then `bd ready --parent <epic-id>` and take the next task.

## Final Review

Final Review starts only when `bd list --parent <epic-id> --status open,in_progress,blocked,deferred` lists no children. An open, in-progress, deferred or flagged child is a task not yet done: finish it, or stop and surface it — never review around it.

Run `bash ../subagent-driven-development/scripts/review-package PLAN_FILE MERGE_BASE HEAD` (MERGE_BASE = the commit the branch started from: the branch's integration base, e.g. `git merge-base <target-branch> HEAD`) and append to the file it prints the closed beads' completion lines (`bd list --parent <epic-id> --status closed --long`) and the path of the test logs, so the reviewer can cross-check each claim against its artifact.

**With a subagent tool:** dispatch the reviewer on the most capable available tier — the whole-branch review is a judgment task — using beads-superpowers:requesting-code-review's `code-reviewer.md`, with the package path, the plan and spec paths, the plan's `## Review Focus` section verbatim if it has one, and a pointer to the epic's notes so it can weigh the rulings you made. Name the tier explicitly; an omitted tier inherits the session's. This is the one fresh context the whole run buys. Do not skip it, and do not replace it with your own read of the diff.

**Without a subagent tool:** read `code-reviewer.md` and perform that review yourself as a separate pass after the last close. Ledger `Final review: self-review (no subagent tool)` and say so in your final message: a self-review by the author is weaker than a fresh reviewer, and your human partner decides whether that is enough before merge. A Critical or security fix needs a fresh-context re-review this path cannot provide: it escalates to your human partner before merge.

Sort the findings before you act. The reviewer's severity labels are advice; the gate is yours. Its `### Declined to judge` list is yours too: every line there is a ruling you make and ledger, exactly like a plan conflict — `Final: Ruling: <behavior set aside> — settled by <spec §> — <effect on a reasonable person> — <cost if wrong>`, where the effect is what a reasonable person using this software gets, and why that stands or is now a finding. Where the spec does not settle it — no citable spec § — it is an escalation. Re-grade first, by effect: the spec is a vision document, and a finding's grade is what a reasonable person using this software gets if it ships, not whether the spec names the trigger. **Re-grading never lowers a security finding:** it stays Critical, enters the fix pass, gets the scoped re-review, and is never deferred or ruled. Then:

- **Critical and Important** enter the fix pass.
- **Minor** goes to the ledger as `Final: minor (deferred): <one-liner>` and to your final message under "Deferred minors". Minors never enter the fix pass and never become rulings.

Fix Critical and Important findings yourself in ONE pass, each verified by TDD: write the test that reproduces the finding, watch it fail, make it pass, run the whole suite. Ledger each as `Final: fixed <finding> — <test name> RED→GREEN, suite <N>/<N>`. **A Critical or security finding's fix gets a scoped fresh-context re-review** (`bash ../subagent-driven-development/scripts/review-package PLAN_FILE FIX_BASE HEAD` with `../subagent-driven-development/re-review-prompt.md`); PASS requires the reviewer's verdict AND a green suite. Important findings get no re-review: the covering test answers "addressed", the suite answers "broke nothing". A finding you decide not to fix is a ruling — `Final: Ruling: …` — or an escalation. There is no second fix pass.

## Finish

Before you delete anything, collect from the epic's notes every line containing `Ruling:` into your final message under "Rulings I made" (in order, each with its cost if wrong), every `minor (deferred)` line under "Deferred minors", and every `Final: fixed` line under "Fixes applied" with its test name and suite result. All three lists are exhaustive: your final message is the only place the decisions you took on your human partner's behalf reach them.

When the final review is clean and its fixes are committed, delete this plan's workspace directory — git and beads are the record now. Then:

- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use beads-superpowers:finishing-a-development-branch — it owns the **Land the Plane** session close (`bd close` → `bd dolt push` → `git push` → `git status`).

## When to Stop and Ask for Help

The stops above are the only reasons to stop the run; a blocker on a single task follows the table below. Either way, classify the blocker and use the matching response — this is how continuous execution escalates without guessing:

| Blocker type | Action | Command |
|---|---|---|
| **Time-based** (waiting on deploy, external process) | Defer the task for later | `bd defer <task-id> --until="<date>"` |
| **Missing work** (prerequisite not built yet) | Create the missing task and wire dependency | `bd create "Missing: <title>" -t task --parent <epic-id>` then `bd dep add <blocked-id> <new-id>` |
| **Human decision needed** (not spec-settled, security-sensitive, ruling budget tripped) | Flag for human input | `bd label add <task-id> human` |

> **Discovered-work bead stamp:** `bd create "[spec] <title>" -t task --parent <epic-id> --notes "Severity:/Confidence:/Evidence:"` — see `verification-before-completion` → Agent-Filed Bead Discipline.

**Ask for clarification rather than guessing.**

## Remember
- Follow plan steps exactly; run every verification; read every output
- Rule only where the spec settles it, and ledger it; escalate the rest
- Never start implementation on main/master branch without explicit user consent
- **Production-Grade Doctrine:** never skip a verification or drop a task to make progress — `bd defer`/`bd human` are for genuine blockers, never a quiet way to descope required work. Never weaken, bypass, or remove a security control — a security regression is never acceptable.

## Red Flags

| Excuse | Reality |
|--------|---------|
| "I remember what Task N says" | You remember a summary. The brief has the exact values. Read it. |
| "The plan's code is right, skip watching the test fail" | A test you never saw fail proves nothing. It is one step. Run it. |
| "I'll run the full suite at the end instead of per step" | Per-step runs are how you learn which step broke it. The end-of-task run is the contract, not a substitute. |
| "The plan is wrong here, I'll just do the right thing" | Do the right thing only if the spec settles it, and ledger the ruling. Unledgered deviation is a decision made in secret. |
| "I'll write the ledger lines after a few tasks" | Compaction does not wait for a convenient moment. One line per task, in the same call as the commit. |
| "Let me check in before the next task" | They chose inline to spend less. Progress prompts spend their time instead. Only the stops stop you. |
| "Three rulings already, but this one is small" | The budget is the stop. Surface them; your partner decides whether the plan still holds. |
| "I read my own diff carefully; the final reviewer is redundant" | Same author, same blind spots. The reviewer is the only fresh context this run buys. |
| "Tests should pass, the change was trivial" | "Should" is not evidence. The contract requires the command and its logged output. |
| "Subagents are slow and expensive, I'll skip the final review too" | Inline already removed the per-task reviewers. One review of the whole branch is the floor, not the ceiling. |
| "The reviewer said Minor, so it's Minor" | The label graded the spec's silence. Grade what the person gets. Re-grade, then gate. |
| "The fix is obvious, no need for a failing test first" | The failing test is the only proof the finding was real and is now gone. Without it you have a diff and a hope. |
| "I'll fix the minors too while I'm in there" | Every minor you fix is a test, a fix, and a suite run your partner did not ask for. Ledger them; your partner decides. |
| "It's a security finding but the spec clearly allows it" | A security finding is NEVER rulable. Stop. |

**Capture what you learned.** At close, record durable, evidence-backed insights (still true next month, tied to a file, test, or command). Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```
