# Superpowers Skills Reference

> Complete skill-by-skill reference with triggers, workflows, dependencies, and key rules

## Skills by Category

| Category | Skills |
|----------|--------|
| **Meta/Entry** | using-superpowers, writing-skills |
| **Design & Planning** | brainstorming, writing-plans |
| **Execution** | subagent-driven-development, executing-plans, dispatching-parallel-agents |
| **Quality** | test-driven-development, systematic-debugging, verification-before-completion |
| **Review** | requesting-code-review, receiving-code-review |
| **Infrastructure** | using-git-worktrees, finishing-a-development-branch |

---

## 1. using-superpowers

**Files:** `SKILL.md` + 3 reference files
**Trigger:** Every conversation start (auto-loaded by SessionStart hook)
**Dependencies:** None (this is the root skill)

### Core Mandate

> IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
> This is not negotiable. This is not optional. You cannot rationalize your way out of this.

### Workflow

1. User message received
2. Check: "Might any skill apply?" — even a 1% chance means invoke
3. Invoke Skill tool
4. Announce: "Using [skill] to [purpose]"
5. Check for checklist → create TodoWrite items
6. Follow skill exactly

### Skill Types

- **Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.
- **Flexible** (patterns): Adapt principles to context.

### Red Flags Table

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept != using the skill. Invoke it. |

### Companion Files

- `references/gemini-tools.md` — Gemini CLI tool name mapping
- `references/copilot-tools.md` — GitHub Copilot CLI tool name mapping
- `references/codex-tools.md` — Codex tool name mapping

---

## 2. brainstorming

**Files:** `SKILL.md` + 7 companion files (visual server, spec reviewer, scripts)
**Trigger:** "You MUST use this before any creative work — creating features, building components, adding functionality, or modifying behaviour"
**Dependencies:** writing-plans (invoked at terminal state)

### Hard Gate

> Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it.

### 9-Step Checklist

1. **Explore project context** — check files, docs, recent commits
2. **Offer visual companion** (if topic involves visual questions) — own message only
3. **Ask clarifying questions** — one at a time, multiple choice preferred
4. **Propose 2-3 approaches** — with trade-offs and recommendation
5. **Present design** — in sections scaled to complexity, get approval per section
6. **Write design doc** — save to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
7. **Spec self-review** — placeholders, contradictions, ambiguity, scope
8. **User reviews written spec** — gate before proceeding
9. **Transition to implementation** — invoke writing-plans skill

### Key Principles

- One question at a time
- Multiple choice preferred
- YAGNI ruthlessly
- Explore alternatives
- Incremental validation

### Terminal State

> The terminal state is invoking writing-plans. Do NOT invoke frontend-design, mcp-builder, or any other implementation skill. The ONLY skill you invoke after brainstorming is writing-plans.

### Visual Companion

The brainstorming skill includes an optional visual companion — a Node.js WebSocket server (`scripts/server.cjs`) that renders HTML mockups in a browser. The agent can send HTML frames to visualise design options during the brainstorming session. This feature is described as "still new and can be token-intensive."

---

## 3. writing-plans

**Files:** `SKILL.md` + `plan-document-reviewer-prompt.md`
**Trigger:** "Use when you have a spec or requirements for a multi-step task, before touching code"
**Dependencies:** brainstorming (feeds into this), subagent-driven-development or executing-plans (invoked at end)

### Core Principle

> Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste.

### Plan Header Template

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
```

### Task Granularity

Each step is one action (2-5 minutes):
- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

### No Placeholders Rule

These are plan failures — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code)
- Steps that describe what to do without showing how
- References to types, functions, or methods not defined in any task

### Save Location

`docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

### Execution Handoff

Offers exactly two choices:
1. **Subagent-Driven Development** (recommended) — fresh agent per task with two-stage review
2. **Inline Execution** — executing-plans skill for batch execution in same session

---

## 4. executing-plans

**Files:** `SKILL.md` (1 file)
**Trigger:** "Use when you have a written implementation plan to execute in a separate session with review checkpoints"
**Dependencies:** using-git-worktrees (required before), writing-plans (creates plan), finishing-a-development-branch (invoked at end)

### Workflow

1. **Load and Review Plan** — read critically, raise concerns
2. **Execute Tasks** — mark in_progress, follow steps exactly, run verifications, mark completed
3. **Complete Development** — invoke finishing-a-development-branch

### When to Stop

STOP executing immediately when:
- Hit a blocker
- Plan has critical gaps
- You don't understand an instruction
- Verification fails repeatedly

### Escalation to Subagent-Driven

If subagents are available, the skill recommends upgrading to `subagent-driven-development` instead.

---

## 5. subagent-driven-development

**Files:** `SKILL.md` + `implementer-prompt.md` + `spec-reviewer-prompt.md` + `code-quality-reviewer-prompt.md`
**Trigger:** "Use when executing implementation plans with independent tasks in current session"
**Dependencies:** using-git-worktrees, writing-plans, requesting-code-review, finishing-a-development-branch, test-driven-development, executing-plans

### Core Principle

> Fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration

### Process Flow

```
1. Read plan → extract ALL tasks with full text → create TodoWrite
2. Per task:
   a. Dispatch implementer subagent (with full task text + context)
   b. Handle status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
   c. Dispatch spec reviewer subagent → pass/fail loop
   d. Dispatch code quality reviewer subagent → pass/fail loop
   e. Mark task complete
3. After all tasks:
   a. Dispatch final code reviewer for entire implementation
   b. Invoke finishing-a-development-branch
```

### Model Selection

| Task Type | Model Guidance |
|-----------|---------------|
| Mechanical (isolated functions, 1-2 files) | Fast, cheap model |
| Integration (multi-file, debugging) | Standard model |
| Architecture, design, review | Most capable model |

### Implementer Status Codes

| Status | Handling |
|--------|---------|
| `DONE` | Proceed to review |
| `DONE_WITH_CONCERNS` | Review concerns, decide |
| `NEEDS_CONTEXT` | Provide context, re-dispatch |
| `BLOCKED` | Escalate to user |

### Critical Rules

- NEVER dispatch multiple implementation subagents in parallel
- NEVER skip reviews (spec compliance OR code quality)
- NEVER proceed with unfixed issues
- NEVER make subagent read plan file (provide full text instead)
- NEVER skip scene-setting context
- Spec compliance MUST pass before code quality review begins

### Subagent Prompt Templates

Each companion file provides a complete prompt template:

- **`implementer-prompt.md`** — Includes project context, task text, coding standards, TDD requirement, status code expectations
- **`spec-reviewer-prompt.md`** — Includes original spec, implementation diff, pass/fail criteria
- **`code-quality-reviewer-prompt.md`** — Includes code quality checklist, anti-patterns, improvement suggestions

---

## 6. test-driven-development

**Files:** `SKILL.md` + `testing-anti-patterns.md`
**Trigger:** "Use when implementing any feature or bugfix, before writing implementation code"
**Dependencies:** None (standalone leaf — referenced by 4 other skills)

### Iron Law

> NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
> Write code before the test? Delete it. Start over.
>
> No exceptions:
> - Don't keep it as "reference"
> - Don't "adapt" it while writing tests
> - Don't look at it
> - Delete means delete

### RED-GREEN-REFACTOR Cycle

1. **RED** — Write one minimal test. Clear name. Tests real behaviour.
2. **Verify RED** — MANDATORY. Confirm test fails (not errors). Check expected failure message.
3. **GREEN** — Simplest code to pass. No extra logic.
4. **Verify GREEN** — MANDATORY. All tests pass. Output pristine.
5. **REFACTOR** — Remove duplication. Improve names. Keep green.
6. **Repeat**

### Foundational Principle

> Violating the letter of the rules IS violating the spirit of the rules.

### Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc != systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests for existing code. |

### Testing Anti-Patterns (from companion file)

Five anti-patterns with gate functions:
1. **Testing Mock Behaviour** — you're testing the test, not the code
2. **Test-Only Methods in Production** — production code should not have test-only paths
3. **Mocking Without Understanding** — mock only what you understand
4. **Incomplete Mocks** — mocks that don't cover the real behaviour
5. **Integration Tests as Afterthought** — integration tests should be planned upfront

---

## 7. systematic-debugging

**Files:** `SKILL.md` + 10 companion files (root cause tracing, defense in depth, pressure tests)
**Trigger:** "Use when encountering any bug, test failure, or unexpected behaviour, before proposing fixes"
**Dependencies:** test-driven-development (Phase 4), verification-before-completion

### Iron Law

> NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST

### Four Phases

**Phase 1: Root Cause Investigation**
- Read errors completely
- Reproduce the issue
- Check recent changes
- Gather evidence in multi-component systems
- Trace data flow

**Phase 2: Pattern Analysis**
- Find working examples
- Compare against references
- Identify differences

**Phase 3: Hypothesis and Testing**
- Single hypothesis at a time
- Minimal change to test
- Verify hypothesis

**Phase 4: Implementation**
1. Create failing test case (invokes TDD)
2. Implement single fix
3. Verify fix (invokes verification-before-completion)

### Escalation Path

```
If Fix Doesn't Work:
  STOP
  Count: How many fixes have you tried?
  If < 3: Return to Phase 1, re-analyze
  If >= 3: STOP and question the architecture
  DON'T attempt Fix #4 without architectural discussion
```

### Companion Files

- **`root-cause-tracing.md`** — 5-step backward tracing technique with stack trace instrumentation
- **`defense-in-depth.md`** — 4-layer validation pattern (entry, business logic, environment guards, debug instrumentation)
- **`condition-based-waiting.md`** — Replace arbitrary timeouts with condition polling
- **`condition-based-waiting-example.ts`** — TypeScript example of condition-based waiting
- **`CREATION-LOG.md`** — Development history showing how the skill was extracted from real debugging sessions
- **`test-pressure-1.md`** — Emergency production fix scenario (time pressure)
- **`test-pressure-2.md`** — Sunk cost + exhaustion scenario
- **`test-pressure-3.md`** — Authority + social pressure scenario
- **`test-academic.md`** — Academic comprehension test
- **`find-polluter.sh`** — Bash script for finding problematic test pollution

---

## 8. verification-before-completion

**Files:** `SKILL.md` (1 file)
**Trigger:** "Use when about to claim work is complete, fixed, or passing — requires running verification commands and confirming output before making any success claims"
**Dependencies:** None (standalone leaf)

### Iron Law

> NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE

### Gate Function

```
BEFORE claiming any status or expressing satisfaction:
1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
5. ONLY THEN: Make the claim
```

### Red Flags

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- ANY wording implying success without having run verification

---

## 9. dispatching-parallel-agents

**Files:** `SKILL.md` (1 file)
**Trigger:** "Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies"
**Dependencies:** None (standalone)

### Pattern

1. Identify independent domains — group failures by subsystem
2. Create focused agent tasks — specific scope, clear goal, constraints, expected output
3. Dispatch in parallel
4. Review and integrate

### When to Use

- 3+ test files failing with different root causes
- Multiple independent subsystems broken

### When NOT to Use

- Related failures (shared root cause)
- Need full system context
- Agents would interfere with each other

---

## 10. using-git-worktrees

**Files:** `SKILL.md` (1 file)
**Trigger:** "Use when starting feature work that needs isolation from current workspace or before executing implementation plans"
**Dependencies:** finishing-a-development-branch (pairs with)

### Directory Selection Priority

1. Check existing directories (`.worktrees` wins over `worktrees`)
2. Check CLAUDE.md for preferences
3. Ask user

### Safety Verification

MUST verify worktree directory is gitignored before creating project-local worktree. If not ignored: fix immediately (add to .gitignore, commit).

### Steps

1. Detect project name
2. Create worktree (`git worktree add`)
3. Run project setup (auto-detect: npm/cargo/pip/go)
4. Verify clean baseline (run tests)
5. Report location

---

## 11. finishing-a-development-branch

**Files:** `SKILL.md` (1 file)
**Trigger:** "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work"
**Dependencies:** using-git-worktrees (pairs with)

### Process

1. **Verify tests pass** — HARD GATE: stop if failing
2. **Determine base branch**
3. **Present exactly 4 options:**
   1. Merge locally (fast-forward or merge commit)
   2. Push + Create PR
   3. Keep as-is (leave branch for later)
   4. Discard (requires typed "discard" confirmation)
4. **Execute chosen option**
5. **Cleanup worktree** (for options 1, 2, 4)

---

## 12. requesting-code-review

**Files:** `SKILL.md` + `code-reviewer.md`
**Trigger:** "Use when completing tasks, implementing major features, or before merging to verify work meets requirements"
**Dependencies:** code-reviewer agent (dispatched)

Dispatches a `superpowers:code-reviewer` subagent with git SHAs and template placeholders. The code-reviewer agent follows a 6-point review protocol.

---

## 13. receiving-code-review

**Files:** `SKILL.md` (1 file)
**Trigger:** "Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable"
**Dependencies:** None (standalone)

### Response Pattern

1. **READ:** Complete feedback without reacting
2. **UNDERSTAND:** Restate requirement in own words (or ask)
3. **VERIFY:** Check against codebase reality
4. **EVALUATE:** Technically sound for THIS codebase?
5. **RESPOND:** Technical acknowledgment or reasoned pushback
6. **IMPLEMENT:** One item at a time, test each

### Forbidden Responses

- "You're absolutely right!"
- "Great point!" / "Excellent feedback!"
- "Let me implement that now" (before verification)

### Secret Signal

If uncomfortable pushing back: "Strange things are afoot at the Circle K"

---

## 14. writing-skills (Meta-Skill)

**Files:** `SKILL.md` (655 lines) + 7 companion files
**Trigger:** "Use when creating new skills, editing existing skills, or verifying skills work before deployment"
**Dependencies:** test-driven-development (REQUIRED BACKGROUND)

### Core Principle

> Writing skills IS Test-Driven Development applied to process documentation.

### Iron Law

> NO SKILL WITHOUT A FAILING TEST FIRST

### TDD Mapping for Skills

| TDD Concept | Skill Creation |
|-------------|----------------|
| Test case | Pressure scenario with subagent |
| Production code | Skill document (SKILL.md) |
| Test fails (RED) | Agent violates rule without skill (baseline) |
| Test passes (GREEN) | Agent complies with skill present |
| Refactor | Close loopholes while maintaining compliance |

### Claude Search Optimization (CSO)

> CRITICAL: Description = When to Use, NOT What the Skill Does
>
> Testing revealed that when a description summarizes the skill's workflow, Claude may follow the description instead of reading the full skill content. A description saying "code review between tasks" caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews.

### Companion Files

- **`testing-skills-with-subagents.md`** — Complete testing methodology with RED-GREEN-REFACTOR, pressure types, meta-testing
- **`persuasion-principles.md`** — Research-backed persuasion techniques (Cialdini 2021, Meincke et al. 2025) for skill design
- **`anthropic-best-practices.md`** — Official Anthropic skill authoring guidance
- **`graphviz-conventions.dot`** — Flowchart conventions for skill diagrams
- **`render-graphs.js`** — Graph rendering utility
- **`examples/CLAUDE_MD_TESTING.md`** — Full test campaign example with 4 scenarios and 4 documentation variants

---

**Next:** [04-design-patterns.md](./04-design-patterns.md) — Design patterns, persuasion principles, and what makes this system effective
