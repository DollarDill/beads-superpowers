# Superpowers Design Patterns & Principles

> What makes this system effective — the design patterns, persuasion techniques, anti-rationalization strategies, and architectural decisions that give Superpowers its reliability

## Pattern 1: Mandatory Invocation (Anti-Opt-Out Design)

Skills are not suggestions. The system uses aggressive language to prevent agents from rationalizing their way out of using skills:

```
IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
This is not negotiable. This is not optional. You cannot rationalize your way out of this.
```

**Why this works:** AI agents have a strong tendency to "just do the task" rather than follow process. Every skill is preceded by a moment where the agent thinks "I could probably just..." — this pattern catches that moment and redirects.

**How it's enforced:**
- The SessionStart hook wraps the bootstrap in `<EXTREMELY_IMPORTANT>` tags
- Every Red Flags table preemptively counters specific rationalisations
- The `using-superpowers` skill has 12 entries in its Red Flags table, each targeting a specific evasion pattern

## Pattern 2: TDD-for-Everything (Recursive Discipline)

TDD is not just a coding practice — it's applied recursively to every level of the system:

| Level | What's Tested | How |
|-------|--------------|-----|
| **Code** | Production code | `test-driven-development` — RED-GREEN-REFACTOR cycle |
| **Debugging** | Root cause hypothesis | `systematic-debugging` — Phase 4 requires creating a failing test case |
| **Skills themselves** | Skill compliance | `writing-skills` — RED: agent violates without skill, GREEN: agent complies with skill |

**Key insight from `writing-skills`:**

> Writing skills IS Test-Driven Development applied to process documentation.

The TDD mapping:
- **Test case** = Pressure scenario with subagent
- **Production code** = Skill document (SKILL.md)
- **Test fails (RED)** = Agent violates rule without skill (baseline)
- **Test passes (GREEN)** = Agent complies with skill present
- **Refactor** = Close loopholes while maintaining compliance

This means every rule in every skill has been empirically verified through adversarial testing — it's not theoretical best practice, it's observed behaviour correction.

## Pattern 3: Anti-Rationalization Tables

Every discipline-enforcing skill includes a two-column table of excuses paired with reality checks. These are not hypothetical — they're empirically derived from pressure testing with subagents.

**Example from `test-driven-development`:**

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |

**Example from `using-superpowers`:**

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "This feels productive" | Undisciplined action wastes time. |

**Prevalence:** 8 out of 14 skills contain Red Flags or Common Rationalizations tables.

**Why this works:** Instead of saying "always follow the process," the system anticipates the specific moment of failure and provides a pre-loaded counter-argument. This is more effective because it catches the agent at the exact decision point where compliance breaks down.

## Pattern 4: Bright-Line Rules (No Wiggle Room)

Rules use absolute language rather than hedged guidance:

- "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
- "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"
- "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"
- "Write code before the test? Delete it. Start over."
- "Delete means delete."

**Research basis (from `persuasion-principles.md`):**

Based on Meincke et al. 2025, compliance with AI agent instructions doubled from 33% to 72% when instructions used:
- Bright-line rules (absolute, no exceptions)
- Explicit enforcement language
- Pre-emptive rationalization counters

The system deliberately avoids:
- "Consider following TDD" → "NO PRODUCTION CODE WITHOUT A FAILING TEST"
- "Try to verify before claiming done" → "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"
- "It's generally a good idea to..." → "You MUST..."

## Pattern 5: Two-Stage Review Separation

`subagent-driven-development` separates code review into two distinct stages:

1. **Spec Compliance Review** — Does the implementation match the specification?
2. **Code Quality Review** — Is the implementation clean, maintainable, and well-structured?

**Critical rule:** Spec compliance MUST pass before code quality review begins.

**Why this works:** When reviewers conflate "is it right?" with "is it clean?", they tend to focus on cosmetic issues and miss functional gaps. By separating the concerns:
- The spec reviewer only checks "does this do what the spec says?"
- The code quality reviewer only checks "is this well-written?"
- Neither reviewer is distracted by the other's concerns

This also means functional correctness is never traded off for style — if the code works but is ugly, it still passes spec review and can be cleaned up in code quality review.

## Pattern 6: Progressive Skill Chain (Explicit Terminal States)

Each skill in the pipeline explicitly names the next skill to invoke, preventing the agent from improvising:

```
brainstorming          → "The ONLY skill you invoke after brainstorming is writing-plans"
writing-plans          → "REQUIRED SUB-SKILL: Use subagent-driven-development or executing-plans"
subagent-driven-dev    → Invoke finishing-a-development-branch
executing-plans        → "REQUIRED SUB-SKILL: finishing-a-development-branch"
finishing-a-dev-branch → [Terminal — worktree cleanup, end of pipeline]
```

**Why this works:** Without explicit terminal states, agents tend to either:
1. Skip ahead (jumping from brainstorming directly to coding)
2. Get stuck (not knowing what comes next)
3. Improvise (inventing their own workflow)

By making each skill's terminal state explicit and singular, the agent always knows exactly where to go next and cannot take shortcuts.

## Pattern 7: Context Isolation for Subagents

When dispatching subagents, the orchestrating agent:
- Provides the **full task text** (never "go read the plan file")
- Includes **scene-setting context** (project structure, tech stack, conventions)
- Defines **explicit status codes** (DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED)
- Gives **explicit permission to escalate** ("this is too hard for me" is a valid response)

**Why this works:** Subagents have no session memory. If you tell them to "read the plan," they lose time on file navigation and may misinterpret the plan. By providing everything inline, you ensure:
- Zero wasted context on file navigation
- Consistent interpretation across subagents
- Clear escalation paths when tasks are beyond scope

## Pattern 8: "Human Partner" Terminology

The project deliberately uses "your human partner" instead of "the user":

> This is intentional language design. The CLAUDE.md explicitly warns against changing it.

**Why this works:** "User" implies a service relationship (agent serves user). "Human partner" implies a collaborative relationship (agent works with human). This subtle language shift:
- Encourages the agent to push back when it disagrees
- Reduces sycophantic compliance with questionable requests
- Establishes that the human's judgment matters but isn't infallible
- Pairs with `receiving-code-review`'s anti-sycophancy rules

## Pattern 9: Hard Gates (Forced Stopping Points)

The system defines specific points where the workflow MUST stop for human input:

| Gate | Skill | What Stops |
|------|-------|-----------|
| Design approval | brainstorming | No implementation until user approves design |
| Plan review | writing-plans | No execution until plan is reviewed |
| Tests pass | finishing-a-development-branch | No merge/PR if tests failing |
| Fresh evidence | verification-before-completion | No "done" claims without test output |
| Root cause found | systematic-debugging | No fixes without investigation |
| Spec review passes | subagent-driven-development | No code quality review until spec confirmed |

**Why this works:** Without hard gates, agents tend to barrel through workflows without pausing for verification. Each gate represents a moment where:
1. The agent must produce evidence (not just assert readiness)
2. A human must explicitly approve (not just not-object)
3. The next phase cannot begin without the gate passing

## Pattern 10: Iron Laws (Unforgettable Anchors)

Three skills define "Iron Laws" — memorable, absolute rules that serve as quick-reference anchors:

1. **TDD:** "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
2. **Debugging:** "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"
3. **Verification:** "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"

All three follow the pattern: `NO [premature action] WITHOUT [required prerequisite] FIRST`

**Why this works:** Iron Laws are:
- Short enough to memorise
- Absolute (no exceptions)
- Action-oriented (they tell you what NOT to do)
- Self-explanatory (no context needed)

They function as "trip wires" — even if the agent skips the full skill, the Iron Law is memorable enough to trigger a pause.

## Pattern 11: Escalation Paths (Preventing Infinite Loops)

Skills define explicit escape hatches when things go wrong:

**Debugging escalation:**
```
If < 3 failed fixes: Return to Phase 1, re-analyze
If >= 3 failed fixes: STOP and question the architecture
DON'T attempt Fix #4 without architectural discussion
```

**Subagent status codes:**
```
DONE             → proceed to review
DONE_WITH_CONCERNS → review concerns, decide
NEEDS_CONTEXT    → provide context, re-dispatch
BLOCKED          → escalate to user
```

**Executing-plans stop conditions:**
```
STOP immediately when:
- Hit a blocker
- Plan has critical gaps
- You don't understand an instruction
- Verification fails repeatedly
```

**Why this works:** Without escalation paths, agents get stuck in retry loops — attempting the same fix repeatedly, or re-running failed tests hoping for a different result. Explicit escalation paths:
- Limit the number of retry attempts
- Define what "stuck" looks like
- Provide a clear action when stuck (usually: stop and involve the human)

## Pattern 12: Claude Search Optimization (CSO)

A critical discovery documented in `writing-skills`:

> CRITICAL: Description = When to Use, NOT What the Skill Does
>
> Testing revealed that when a description summarizes the skill's workflow, Claude may follow the description instead of reading the full skill content. A description saying "code review between tasks" caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews.

**Implication:** The YAML frontmatter `description` field functions as a trigger condition, not a summary. If you put workflow information in the description, the agent may use it as a shortcut instead of reading the full skill.

**Rule:** Description should answer "When should I use this?" not "What does this do?"

## Persuasion Research Integration

The `writing-skills` companion file `persuasion-principles.md` documents the research basis for the system's design:

### From Cialdini (2021) — Influence Principles Applied to AI

- **Authority:** Skills speak with authority ("Iron Law", "MUST", "NO EXCEPTIONS")
- **Consistency:** Once an agent starts following a skill, consistency pressure keeps it following
- **Social Proof:** "Your human partner" implies others use these skills too
- **Scarcity:** "You cannot rationalize your way out of this" — removes alternatives

### From Meincke et al. (2025) — AI Compliance Research

Key finding: **Compliance doubled from 33% to 72%** when using:
- Bright-line rules (absolute, no exceptions)
- Explicit enforcement language
- Pre-emptive rationalization counters
- Specific examples of non-compliance

This research directly informs:
- The anti-rationalization tables (pre-emptive counter-arguments)
- The absolute language ("MUST", "NEVER", "NO EXCEPTIONS")
- The specific examples in Red Flags tables (showing exactly what non-compliance looks like)

## What Makes This System Uniquely Effective

### 1. Empirically Derived, Not Theoretically Designed

Every rule in the system has been tested through adversarial pressure scenarios (documented in `writing-skills/testing-skills-with-subagents.md`). The system uses RED-GREEN-REFACTOR on its own skills:
1. Create a pressure scenario (e.g., "urgent production fix, no time for tests")
2. Run without the skill → observe the agent cutting corners (RED baseline)
3. Run with the skill → verify the agent follows the process (GREEN)
4. Find loopholes → refine the skill → re-test (REFACTOR)

### 2. Anticipatory, Not Reactive

The anti-rationalization tables don't wait for the agent to fail — they pre-load counter-arguments for every known failure mode. This is why the tables are so specific: each entry corresponds to an observed agent behaviour during pressure testing.

### 3. Composable, Not Monolithic

Skills can be used independently or chained together. The system works whether you use 1 skill or all 14. Each skill is self-contained but explicitly names its connections to other skills.

### 4. Platform-Agnostic with Platform-Specific Hooks

The skills themselves are pure Markdown — no platform-specific code. Platform adaptation happens only in the plugin manifests and hook scripts. This means the same skill corpus works across 6+ agent platforms without modification.

### 5. Zero-Dependency by Design

No npm packages, no build step, no runtime requirements (except Node.js for the optional visual brainstorming companion). Skills are plain Markdown files that work on any system with a file system.

---

**Next:** [05-comparison-and-insights.md](./05-comparison-and-insights.md) — How Superpowers compares to alternatives, and key insights for customisation
