---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write implementation plans for an engineer who has not seen this codebase or this spec. Assume they write idiomatic code in the project's language once they know the exact interface and the exact test, and that they will make a reasonable choice wherever the plan leaves one open. What they cannot know is what you decided: which files, which names and signatures, which values from the spec, which tests prove each task. Document those. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Production-Grade Doctrine:** every spec requirement MUST map to a task — a deliberate cut is surfaced as a tracked decision, never a silent omission. Never weaken, bypass, or remove a security control — a security regression is never acceptable.

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `.internal/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Knowledge Check

Before writing tasks, query the knowledge store: `bd list --label <topic> --status all` + `bd search "<keywords>" --status all` + `bd memories <keyword>` (the memory half — lessons, patterns, root-causes; knowledge-beads alone miss it entirely). Then read — hits are pointers, not knowledge: `bd show <id1> <id2> ...` / `bd recall <key>` for every hit that plausibly bears on this plan. Emit `KB check: N bead hits, M memory hits, K read` plus a one-line disposition per read hit — folded into a task (which one) or ruled out (why).

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

In beads terms, a right-sized task is one bead (`bd create -t task --parent <epic-id>`): claimable, verifiable, and closeable on its own.

## Step Granularity

**Each step is one action with a checkable result:**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use beads-superpowers:subagent-driven-development (recommended) or beads-superpowers:executing-plans to implement this plan task-by-task. Each Task becomes a bead (`bd create -t task --parent <epic-id>`). Steps within tasks use checkbox (`- [ ]`) syntax for human readability.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Spec:** [path to the spec/design doc this plan implements — the plan
argues from the spec, so the spec travels with it; executors read both]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

## Review Focus

[The five input classes or failure modes the spec implies but no task's
tests exercise that are most likely to bite a person using this software
— one line each, naming the input or condition and the behavior a
reasonable person would expect, most likely first. The spec is a vision
document: it says what the software must do, not everything it will
meet, and its silence on an input is not permission for that input to
break the program. Write the list here, once, with the spec in front of
you. Then, for each line, add the test that pins it to the task that
owns the code, in that task's own step style.]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

**Acceptance Criteria:**
- [Observable, testable outcomes — copied verbatim into the task bead's
  `## Acceptance Criteria` section at creation]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Implement `function(input: InputType) -> ResultType` in `exact/path/to/file.py`**

One line on the approach when the signature and the test leave a choice
(which library call, which data structure); a code block only for an
algorithm they do not determine.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

**Beads integration:** When executing this plan, the executing skill creates an epic bead for the plan and a child task bead for each Task N. The `- [ ]` checkboxes remain in the markdown for human readability, but task-level tracking uses beads (`bd create`, `bd update --claim`, `bd close --reason`). Dependencies between tasks should be declared with `bd dep add`.

**Atomic creation:** the executing skill creates the epic + tasks via `bd import` (JSONL) — `bd create` the epic, then `bd import -` the tasks (each with a `parent-child` dep to the epic and rich fields), then `bd batch` any inter-task `blocks` ordering. Not a sequential create-loop. The exact kernel lives in the executing skill (subagent-driven-development / executing-plans).

**Required bead-body sections:** `bd lint` (Self-Review step 0) requires `## Success Criteria` in the epic bead's description and `## Acceptance Criteria` in each task bead's description. Include them at creation time — embed them in each bead's `description` in the import JSONL (or use the `acceptance_criteria` field). The epic's Success Criteria derive from the plan's **Goal**; each task's copy from its **Acceptance Criteria** block.

## What a Step Contains

A step is done when the implementer can write exactly one reasonable thing
from it. That is the whole requirement: unambiguous, not complete. Each kind
of step carries what makes it unambiguous and nothing more:

- **A test step:** the test's name and its assertions, as code, with the
  spec's exact values in them.
- **A code step:** the exact signature (name, parameters, return type), the
  file it lives in, and the specific values the spec pins. The implementer
  writes the body. A body appears only for an algorithm the signature and
  tests do not determine, or for exact copy the spec fixes.
- **A verification step:** the command to run and the output that means it
  passed.
- **A reference to another task:** that task's Interfaces block says what
  to use; the plan does not repeat that task's code.

For a prose or Markdown edit, the decisions are the target file and anchor, the exact text of any rule, bright line or pinned phrase, and the contract-test assertion that pins it; connecting prose is left to the implementer.

A plan is the set of decisions the implementer cannot make alone. A plan
longer than the code it describes has written the code instead. Lines that
decide nothing ("TBD", "TODO", "implement later", "fill in details",
"handle edge cases", "add appropriate error handling", "add validation",
"add appropriate validation", "write tests for the above", "Similar to Task N" with no Interfaces block to point at, a type or
function no task defines) are the opposite failure, and the self-review
catches both.

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**0. Deterministic checks:** Run these commands and fix anything they flag before proceeding to the judgment checks below:

```bash
bd lint <epic-id>                                                    # required-section check on the epic
bd list --parent <epic-id> --json | jq -r '.[].id' | xargs -n1 bd lint   # same check on each child task
bd ready --parent <epic-id> --explain                                # confirm dependency ordering
```

**1. Spec coverage:** Skim each requirement in the spec. Every one MUST map to a task — point to it. A requirement with no task is either added as a task or surfaced to the user as an explicit, acknowledged cut. Silent omission is a plan failure.

**2. Step scan:** Every step must let the implementer write exactly one reasonable thing, and no step may carry more than that: a line that decides nothing is a gap, a function body the signature and tests already determine is a transcript. Fix both.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**4. Review Focus:** For each input class or failure mode the spec implies, is there a task whose tests exercise it? The five uncovered ones most likely to bite a person go in the Review Focus section, and each line there gets its test added to the owning task. An empty section means you checked and found none, not that you skipped the check.

**5. Proportion:** Compare the plan's length to the spec's. A plan several times longer than the spec it implements is a transcript of the program, not a plan. If code blocks are most of the document, replace bodies with signatures, test names and assertions, and check that each step is still unambiguous.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## User Review Gate

After self-review passes, **open the plan file in the user's editor** so they can review it, then gate progression with your structured question tool (content below; shape shown in Claude Code schema — adapt to your tool):

**User's preferred editor:** !`echo ${VISUAL:-${EDITOR:-not-configured}}`

**⚠️ Run the open command as a standalone Bash call** — never chain it after `bd` commands in the same invocation (e.g., `bd close <id> && open file.md`). The combination hangs.

```bash
# Open in user's preferred editor, with platform fallbacks
if [ -n "$VISUAL" ]; then
  "$VISUAL" "<plan-file-path>"
elif [ -n "$EDITOR" ]; then
  "$EDITOR" "<plan-file-path>"
elif command -v open >/dev/null 2>&1; then
  open "<plan-file-path>"
else
  xdg-open "<plan-file-path>" 2>/dev/null
fi
# If none available: just report the path
```

Then immediately ask via your structured question tool (content below; shape shown in Claude Code schema — adapt to your tool):

<!-- Canonical 3-option stress-test gate — keep identical to brainstorming/SKILL.md -->

```json
{
  "questions": [{
    "question": "Plan opened in your editor at `<path>`. Review it and let me know how to proceed.",
    "header": "Plan review",
    "options": [
      {"label": "Approved + stress-test (Recommended)", "description": "Plan looks good — run an adversarial stress-test before execution"},
      {"label": "Approved", "description": "Plan looks good — skip stress-test and proceed to choose execution method"},
      {"label": "Needs changes", "description": "I want to revise the plan before proceeding"}
    ],
    "multiSelect": false
  }]
}
```

Route on the answer:
- **Approved + stress-test** → invoke the `stress-test` skill with the plan path (`.internal/plans/YYYY-MM-DD-<feature-name>.md`) as the Mode-A artifact; when it completes, proceed to **Execution Handoff**.
- **Approved** → proceed to **Execution Handoff** directly.
- **Needs changes** → make the requested changes and re-run the self-review. Only proceed once approved.

> When filing a bead for discovered/follow-up work, stamp it per **Agent-Filed Bead Discipline** (`verification-before-completion`).

After the work is settled, present the Capture gate — mandatory every time; Skip is the default (most work leaves nothing worth keeping):

```json
{
  "questions": [{
    "question": "Worth keeping anything from this?",
    "header": "Capture",
    "options": [
      {"label": "Skip", "description": "Nothing here outlasts the work itself (usually the case)"},
      {"label": "Record the decision", "description": "Pick this if the choice is hard to undo, non-obvious in hindsight, and had real trade-offs — so future-you knows why"},
      {"label": "Remember the lesson", "description": "A specific, evidence-backed lesson worth reusing in later sessions"},
      {"label": "Both", "description": "A lasting decision and a lesson worth reusing"}
    ],
    "multiSelect": false
  }]
}
```

Route on the answer. **Record the decision / Both** → this writes an ADR, so first confirm it clears the bar (hard-to-reverse AND surprising-without-context AND genuine trade-off); if it doesn't, say so and capture it as a memory instead (the lighter record) — unless the user confirms they want the full ADR. Write the ADR (`docs/decisions/ADR-NNNN-<kebab>.md`, sections Context/Decision/Rationale/Consequences, update `docs/decisions/INDEX.md`), then file a `type=decision` knowledge-bead so the decision stays retrievable: `printf '%s' "<distilled 0.5-2.5KB decision summary — context, decision, consequences>" | bd create "<one-line summary>" -t decision -l kb,adr-process,<topic> --defer 2099-01-01 --metadata "$(jq -nc --arg d "<ADR-path>" '{doc:$d}')" --body-file - --silent` (run the secret/PII scan on the summary first — flag for removal, never write a secret into a bead). **Remember the lesson / Both** → `bd remember "<kind>: <durable, evidence-backed insight>"`. **Skip** → nothing.

## Execution Handoff

After the plan is approved, recommend a method from the plan itself, then **use your structured question tool** to offer the choice. State the recommendation as two heuristics your human partner overrides at the gate:

- **Length** — more than about eight tasks, or any task whose brief plus expected test output would not fit one uncompacted stretch → Subagent-Driven.
- **Sensitivity** — the plan touches auth, secrets, permissions, input validation or data deletion → Subagent-Driven (a fresh reviewer per task is worth its cost there).
- Otherwise → Inline Execution.

**"For this plan I recommend <method>, because <one sentence from the plan: task count, interface coupling, sensitivity>."**

If the plan header or your human partner already names an execution method, present it as the default and ask only for review confirmation.

```json
{
  "questions": [{
    "question": "Plan complete and saved. How would you like to execute it?",
    "header": "Execution",
    "options": [
      {
        "label": "Subagent-Driven (Recommended)",
        "description": "A fresh implementer and a fresh reviewer per task, then a whole-branch review — most thorough; costs a fresh context per task and per review"
      },
      {
        "label": "Inline Execution",
        "description": "This session implements every task itself, continuously, with beads as the ledger and one final whole-branch review on the most capable tier — cheaper; one context plus one reviewer"
      }
    ],
    "multiSelect": false
  }]
}
```

Put the recommended option first and mark it "(Recommended)" — swap the labels when the heuristics point at inline.

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use beads-superpowers:subagent-driven-development
- Fresh implementer and reviewer per task, single task review between tasks (spec + quality verdicts)

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use beads-superpowers:executing-plans
- Continuous inline execution on the beads ledger; one final whole-branch review

## Integration

**Called by:** **brainstorming** — this is brainstorming's terminal state. After design approval, brainstorming invokes writing-plans.

**Invokes:**
- **subagent-driven-development** — execution handoff (user choice).
- **executing-plans** — execution handoff (user choice).

**Pairs with:** **stress-test** — offered at the plan-review gate every time (the "Approved + stress-test" option), before execution.
