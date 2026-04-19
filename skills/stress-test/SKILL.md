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
bd create "Stress-test: <topic>" -t chore
```

### Phase 1: Understand the Target

Read the design, plan, or decision document thoroughly. If no document exists, ask the user to describe the approach. Explore the codebase for context — answer your own questions from code when possible rather than asking the user.

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

For each branch, ask a single focused question. **Always provide your recommended answer.**

```
Question: "The plan uses polling every 30s for status updates.
Have you considered WebSockets instead?"

My recommendation: "Polling is the right call here.
WebSocket adds connection management complexity for a feature
that's checked infrequently. The 30s interval is fine for
non-real-time status. However, I'd add an exponential backoff
if the server returns errors."

Do you agree, or does your context suggest otherwise?
```

**Rules:**
- One question at a time — never batch
- Always state your recommendation — don't just ask open-ended questions
- If you can answer by exploring the codebase, do that instead of asking
- When the user agrees, move on. When they push back, explore deeper.
- Track resolved vs unresolved branches

### Phase 4: Document Findings

After all major branches are resolved, produce a findings summary:

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

### Phase 5: Close

```bash
bd close <id> --reason "Stress-test complete: N branches resolved, M changes made, confidence: <level>"
```

## Anti-Rationalization

| Shortcut | Reality |
|----------|---------|
| "I asked 3 questions, that's enough" | Cover ALL major branches — count the decision tree, not the questions |
| "The user seems confident" | Confidence ≠ correctness — interrogate anyway |
| "This is a simple project" | Simple projects have the most unexamined assumptions |
| "We already brainstormed this" | Brainstorming proposes; stress-testing challenges |
| "I don't want to slow things down" | Catching a flaw now saves 10x the time later |

## Red Flags

**Never:**
- Skip branches because they seem obvious
- Accept "it's fine" without specific reasoning
- Ask multiple questions in one message
- Forget to provide your own recommended answer
- End without a findings summary

**Always:**
- Provide a recommended answer for every question
- Explore the codebase before asking the user
- Track resolved vs unresolved branches
- Produce a written findings summary
- Create and close a bead with evidence

## Integration

**Called by:**
- **brainstorming** — optional step between design approval and writing-plans
- **writing-plans** — optional step between plan approval and execution
- Any workflow where a decision needs adversarial scrutiny

**Pairs with:**
- **brainstorming** — stress-test validates what brainstorming produced
- **writing-plans** — stress-test validates what the plan proposes
- **verification-before-completion** — stress-test for designs, verification for implementations
