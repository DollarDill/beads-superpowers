---
name: stress-test
description: Use when a design, plan, or decision needs adversarial scrutiny before proceeding. Interrogates every branch of the decision tree, providing recommended answers and forcing explicit agreement or pushback. Triggers on "grill me", "stress test this", "poke holes", "challenge this design", or when brainstorming/writing-plans suggests review.
---

# Stress Test: Adversarial Design Interrogation

> **Source:** Inspired by [mattpocock/skills grill-me](https://github.com/mattpocock/skills/blob/main/grill-me/SKILL.md)

**Announce at start:** "I'm using the stress-test skill to interrogate this design."

## Purpose

Stress-test a design, plan, or decision by walking down every branch of the decision tree. For each question, provide your **own recommended answer** — don't just ask, propose. This forces the user to either agree explicitly or articulate why their approach is better.

This is NOT brainstorming (which creates designs) or verification (which checks implementations). This is the gap between them: **"Is this design actually solid before we commit to building it?"**

## When to Invoke

| Trigger | Context |
|---------|---------|
| After brainstorming | Stress-test the design spec before writing a plan |
| After writing-plans | Stress-test the plan before execution begins |
| User says "grill me" | On-demand for any document, decision, or approach |
| Before a major architectural decision | Ensure alternatives were genuinely considered |

## The Process

```bash
# Create a stress-test bead
bd create "Stress-test: <topic>" -t chore -p 2 \
  --description="Adversarial review of <artifact>. Branches to interrogate: <count>"
bd update <id> --claim
```

### Phase 1: Understand the Target

Read the design, plan, or decision document thoroughly. If no document exists, ask the user to describe the approach. Explore the codebase for context — answer your own questions from code when possible rather than asking the user.

**Restore point (Mode A only):** If the target artifact has uncommitted changes, commit or stash them before starting — this preserves a clean restore point before inline edits begin. In the normal flow (brainstorming → stress-test), the artifact is already committed.

### Phase 2: Map the Decision Tree

Identify every decision branch in the target:
- Architecture choices (why X over Y?)
- Assumptions (what breaks if this is wrong?)
- Dependencies (what happens if this changes?)
- Edge cases (what about when Z happens?)
- Scale (does this work at 10x? 100x?)
- Failure modes (what's the worst case?)
- Alternatives not considered (what about approach W?)

### Phase 3: Interrogate One Branch at a Time

For each branch, present your question and recommendation as text, then use the `AskUserQuestion` tool for structured response.

**Per-branch flow:**

1. Present the **question + recommendation** as text in the message body (reasoning needs room to breathe)
2. Immediately follow with `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "<1-sentence summary of the branch being interrogated>",
    "header": "Stress test",
    "options": [
      {"label": "Agree", "description": "Accept the recommendation and move to the next branch"},
      {"label": "Disagree", "description": "I have a different view — let me explain"},
      {"label": "Discuss further", "description": "I want to explore this branch more before deciding"}
    ],
    "multiSelect": false
  }]
}
```

**Response handling:**

- **Agree** — Mark branch resolved, emit status line, advance to next branch
- **Disagree** — Ask "What's your alternative?" as text (open-ended — disagreements need space). Iterate until the branch resolves, then re-ask the same 3-option `AskUserQuestion` on the revised position.
- **Discuss further** — Explore deeper (code, docs, implications), present updated analysis, then re-ask the same `AskUserQuestion`

**Branch tracking:** After each branch resolves, emit a status line:

```
✓ Resolved: 3/7 branches (2 agreed, 1 modified)
Remaining: Error handling, Scale, Rollback, Testing strategy
```

**Rules:**
- One branch at a time — never batch
- Always state your recommendation in the message body BEFORE the `AskUserQuestion` — the recommendation is the substance; the click is just the gate
- If you can answer by exploring the codebase, do that instead of asking
- When the user agrees, move on. When they push back, explore deeper.

### Phase 4: Document Findings

After all branches are resolved, write the findings. The output mode depends on context.

**Mode detection:**

- **Mode A** applies when: the stress-test was invoked by brainstorming or writing-plans (caller passes the artifact path), OR the user explicitly points at a `.internal/specs/` or `.internal/plans/` file.
- **Mode B** applies for everything else: user-initiated "grill me" with no artifact, stress-testing a conversation or decision, or targeting documents that shouldn't be edited inline (README, CLAUDE.md, etc.).
- **When ambiguous:** Use `AskUserQuestion` to ask:

```json
{
  "questions": [{
    "question": "I see `<file>`. Should I edit it inline with findings, or produce a separate stress-test report?",
    "header": "Output mode",
    "options": [
      {"label": "Edit inline (Mode A)", "description": "Apply changes directly to the source document and append a results summary"},
      {"label": "Separate report (Mode B)", "description": "Write findings to .internal/stress-tests/ without modifying the source"}
    ],
    "multiSelect": false
  }]
}
```

**Mode A — Existing artifact** (spec, plan, design doc in `.internal/`):

- Edit the source artifact directly when a branch changes the design.
- At the end, append a `## Stress Test Results` section at the bottom of the source document:

```markdown
## Stress Test Results: <topic>

### Resolved Decisions
- [Decision 1]: [Resolution and rationale]
- [Decision 2]: [Resolution and rationale]

### Changes Made
- [Any modifications to the original design/plan]

### Deferred / Parking Lot
- [Items explicitly deferred for later]

### Confidence Assessment
- Overall: High/Medium/Low
- Areas of concern: [Any remaining worries]
```

Alternatively, record as a `bd note` on the parent bead if the source doc shouldn't be modified further.

**Mode B — Standalone stress test** (no existing artifact):

- Create `.internal/stress-tests/YYYY-MM-DD-<topic>.md` with the full findings template above.
- Open in user's editor for review:

**User's preferred editor:** !`echo ${VISUAL:-${EDITOR:-not-configured}}`

```bash
# Open in user's preferred editor, with platform fallbacks
if [ -n "$VISUAL" ]; then
  "$VISUAL" "<findings-file-path>"
elif [ -n "$EDITOR" ]; then
  "$EDITOR" "<findings-file-path>"
elif command -v open >/dev/null 2>&1; then
  open "<findings-file-path>"
else
  xdg-open "<findings-file-path>" 2>/dev/null
fi
# If none available: just report the path
```

### Phase 4.5: Reflexion Self-Review

After documenting findings, run a single self-critique pass. This is internal reasoning — not shown to the user. Only the consequences (new or re-opened branches) are visible.

**Self-critique questions:**

1. **Coverage:** Compare branches mapped in Phase 2 against branches actually interrogated. List any that were skipped or merged, with justification.
2. **Depth:** Did I challenge the design, or just confirm what was already there? Were my recommendations genuinely independent, or did I echo the existing approach? Did I accept any "it's fine" answers without specific reasoning?
3. **Missed angles:** What failure modes, alternatives, or assumptions did I NOT explore?

**Resolution:**

- Coverage gaps (branches mapped but not interrogated) → go back and interrogate them
- Depth issues (sycophantic agreement, rubber-stamping) → re-interrogate the weakest branches with harder questions
- Missed angles (genuinely new branches) → add to the map and interrogate them

**Visible consequence:** If reflexion adds or re-opens branches, emit an update via the branch tracking status line:

```
✓ Resolved: 7/7 branches (5 agreed, 2 modified)
[Reflexion added 2 new branches]
✓ Resolved: 9/9 branches (7 agreed, 2 modified)
```

**Termination rule:** Reflexion runs exactly once. One self-critique pass, address what it finds, then proceed to Phase 5. No recursive reflexion.

### Phase 5: Close

**⚠️ Run the open command as a standalone Bash call** — never chain it after `bd` commands in the same invocation (e.g., `bd close <id> && open file.md`). The combination hangs.

```bash
bd close <id> --reason "Stress-test complete: N branches resolved, M changes made, confidence: <level>"
```

If you discovered something reusable, capture it before closing:

```bash
# Only if worth preserving for future sessions:
bd remember "design: <gap or insight revealed by stress testing>"
```

## Anti-Rationalization

| Shortcut | Reality |
|----------|---------|
| "I asked 3 questions, that's enough" | Cover ALL major branches — count the decision tree, not the questions |
| "The user seems confident" | Confidence ≠ correctness — interrogate anyway |
| "This is a simple project" | Simple projects have the most unexamined assumptions |
| "We already brainstormed this" | Brainstorming proposes; stress-testing challenges |
| "I don't want to slow things down" | Catching a flaw now saves 10x the time later |
| "They clicked Agree fast, so this is going well" | Speed ≠ depth — fast agreement might mean they're not reading your recommendation carefully. Don't reduce rigor. |
| "I can shorten my recommendation since they just need to click" | The recommendation IS the value. AskUserQuestion replaces how the user responds, not how thoroughly you interrogate. |

## Red Flags

**Never:**
- Skip branches because they seem obvious
- Accept "it's fine" without specific reasoning
- Ask multiple questions in one message
- Forget to provide your own recommended answer
- End without a findings summary
- Present the `AskUserQuestion` without a substantive recommendation preceding it in the message body

**Always:**
- Provide a recommended answer for every question
- Explore the codebase before asking the user
- Track resolved vs unresolved branches
- Produce a written findings summary
- Create and close a bead with evidence

## Integration

**Called by:**
- **brainstorming** — offered at the spec-review gate every time; runs between design approval and writing-plans
- **writing-plans** — offered at the plan-review gate every time; runs between plan approval and execution
- Any workflow where a decision needs adversarial scrutiny

**Pairs with:**
- **brainstorming** — stress-test validates what brainstorming produced
- **writing-plans** — stress-test validates what the plan proposes
- **verification-before-completion** — stress-test for designs, verification for implementations
