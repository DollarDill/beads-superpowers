---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Production-Grade Doctrine:** every spec requirement MUST map to a task — a deliberate cut is surfaced as a tracked decision, never a silent omission. Never weaken, bypass, or remove a security control — a security regression is never acceptable.

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `.internal/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

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

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
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

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

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

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

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

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**0. Deterministic checks:** Run these commands and fix anything they flag before proceeding to the judgment checks below:

```bash
bd lint <epic-id>                                                    # required-section check on the epic
bd list --parent <epic-id> --json | jq -r '.[].id' | xargs -n1 bd lint   # same check on each child task
bd ready --parent <epic-id> --explain                                # confirm dependency ordering
```

**1. Spec coverage:** Skim each requirement in the spec. Every one MUST map to a task — point to it. A requirement with no task is either added as a task or surfaced to the user as an explicit, acknowledged cut. Silent omission is a plan failure.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

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

After the work is settled, present the Capture gate — mandatory every time; Skip is the default (most work clears nothing durable):

```json
{
  "questions": [{
    "question": "Did this clear the capture bar?",
    "header": "Capture",
    "options": [
      {"label": "Skip", "description": "No durable output beyond the artifact (the usual outcome)"},
      {"label": "ADR + memory", "description": "Clears all 3 ADR marks (hard-to-reverse + surprising-without-context + genuine trade-off) and a durable lesson"},
      {"label": "ADR only", "description": "Clears all 3 ADR marks (hard-to-reverse + surprising-without-context + genuine trade-off)"},
      {"label": "Memory only", "description": "A durable, evidence-backed lesson beyond the artifact itself"}
    ],
    "multiSelect": false
  }]
}
```

Route: **ADR / ADR+memory** → write the ADR per the 3-mark gate (`docs/decisions/ADR-NNNN-<kebab>.md`, sections Context/Decision/Rationale/Consequences, update `docs/decisions/INDEX.md`), then file a `type=decision` knowledge-bead so the decision stays retrievable: `printf '%s' "<distilled 0.5-2.5KB decision summary — context, decision, consequences>" | bd create "<one-line summary>" -t decision -l kb,adr-process,<topic> --defer 2099-01-01 --metadata "$(jq -nc --arg d "<ADR-path>" '{doc:$d}')" --body-file - --silent` (run the secret/PII scan on the summary first — flag for removal, never write a secret into a bead). **Memory / ADR+memory** → `bd remember "<kind>: <durable, evidence-backed insight>"`. **Skip** → nothing.

## Execution Handoff

After the plan is approved, **use your structured question tool** to offer the execution choice:

```json
{
  "questions": [{
    "question": "Plan complete and saved. How would you like to execute it?",
    "header": "Execution",
    "options": [
      {
        "label": "Subagent-Driven (Recommended)",
        "description": "Fresh subagent per task with a single task review between tasks — fast iteration, high quality"
      },
      {
        "label": "Inline Execution",
        "description": "Execute tasks in this session using executing-plans — batch execution with checkpoints"
      }
    ],
    "multiSelect": false
  }]
}
```

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use beads-superpowers:subagent-driven-development
- Fresh subagent per task + single task review (spec + quality verdicts)

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use beads-superpowers:executing-plans
- Batch execution with checkpoints for review

## Integration

**Called by:** **brainstorming** — this is brainstorming's terminal state. After design approval, brainstorming invokes writing-plans.

**Invokes:**
- **subagent-driven-development** — execution handoff (user choice).
- **executing-plans** — execution handoff (user choice).

**Pairs with:** **stress-test** — offered at the plan-review gate every time (the "Approved + stress-test" option), before execution.
