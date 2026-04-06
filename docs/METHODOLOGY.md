# Methodology: Why beads-superpowers Exists

> The design philosophy, research basis, and rationale behind merging Superpowers skills with Beads issue tracking into a single Claude Code plugin.

## The Problem: Two Halves of a Whole

AI coding agents in 2025-2026 face two fundamental problems that, until now, have been solved by two separate systems:

### Problem 1: No Process Discipline

Without explicit workflow enforcement, AI agents consistently:
- Skip to coding before understanding the problem
- Write implementation before tests
- Claim work is "done" without running verification
- Accept review feedback without questioning it (sycophancy)
- Attempt fix after fix without investigating root causes
- Rationalise skipping every process step with plausible-sounding excuses

**Superpowers** (by Jesse Vincent) solved this with 14 composable skills that use bright-line rules, anti-rationalization tables, and pressure-tested enforcement language. Compliance doubled from 33% to 72% when using absolute rules over hedged guidance (Meincke et al. 2025).

### Problem 2: No Persistent Memory

When an AI coding session ends:
- Todo lists created with `TodoWrite` vanish entirely
- Task dependencies are forgotten
- Work-in-progress has no audit trail
- The next session starts completely blind
- Learned conventions and preferences are lost

**Beads** (by Steve Yegge) solved this with a Dolt-backed issue tracker that provides:
- Hash-based IDs that work without central coordination
- Cell-level merge for conflict-free multi-agent operation
- `bd prime` context injection at every session start
- `bd remember` for persistent cross-session learnings
- Full audit trail via the events table

### The Gap

Superpowers had process discipline but ephemeral tracking (TodoWrite). Beads had persistent tracking but no process discipline (just raw issue CRUD). Neither was complete alone.

**beads-superpowers bridges the gap:** every process step in every skill now creates, updates, or closes a persistent bead. The agent doesn't just follow the right process — it leaves a permanent record of having done so.

## The Merge Strategy

### What Changed

Every reference to `TodoWrite` across all 14 Superpowers skills was replaced with beads (`bd`) commands:

| Before (TodoWrite) | After (Beads) |
|-------------------|---------------|
| `TodoWrite("Task 1: Implement login")` | `bd create "Task 1: Implement login" -t task --parent <epic-id>` |
| Mark task as in_progress | `bd update <task-id> --claim` |
| Mark task as completed | `bd close <task-id> --reason "Implemented login"` |
| "More tasks remain?" | `bd ready --parent <epic-id>` |
| Create todo per checklist item | `bd create "Step: title" -t chore --parent <session-id>` |

### What Was Added

1. **Beads Issue Tracking section** in `using-superpowers` — every session starts with beads awareness
2. **Land the Plane protocol** in `finishing-a-development-branch` — every session ends with `bd dolt push` + `git push`
3. **Beads Completion section** in `verification-before-completion` — `bd close` without evidence is lying
4. **Epic/child bead pattern** in execution skills — plans become epic beads with task children
5. **Dependency tracking** in execution skills — `bd dep add` for task dependencies
6. **Context forwarding** in `brainstorming` — brainstorming beads link to plan epics via `discovered-from`

### What Was Preserved

- All 14 original Superpowers skills and their complete content
- Every anti-rationalization table, Iron Law, and Red Flags section
- The progressive skill chain (brainstorming → plans → execution → finishing)
- The two-stage review pattern (spec compliance then code quality)
- All subagent prompt templates (implementer, spec-reviewer, code-quality-reviewer) — **unchanged**
- Platform reference files for Gemini, Copilot CLI, and Codex

### What Was NOT Changed

The three subagent prompt files are deliberately not beads-aware. This is the **orchestrator-only** design decision:

- The orchestrating agent creates, claims, and closes beads
- Subagents focus purely on implementation and review
- This prevents concurrent bead write conflicts
- It keeps subagent prompts focused and simple

## The Design Decisions

### 1. Replace at Both Levels

TodoWrite was used at two granularity levels in Superpowers:
- **Task level**: Tracking plan tasks in execution skills
- **Checklist level**: Tracking internal steps within a skill's own checklist

We replaced **both**. Even the brainstorming 9-step checklist and the writing-skills 20-step checklist now create beads. This means every process step, at every level, is persistent and auditable.

**Why both?** If only task-level tracking is persistent but checklist-level tracking is ephemeral, agents learn that "some tracking is optional." The bright-line rule is: **all tracking uses beads, no exceptions.**

### 2. Plugin Subsumes Beads Hooks

Beads' `bd setup claude` command installs SessionStart hooks that run `bd prime`. Our plugin's SessionStart hook also needs to inject the `using-superpowers` skill content. Having both fire would inject ~3-4k tokens of partially redundant context.

**Solution:** The plugin's `hooks/session-start` script does both:
1. Injects the `using-superpowers` skill (skill routing + beads awareness)
2. Runs `bd prime` itself (beads CLI context + persistent memories)

It also detects if the `bd setup claude` hooks are still installed and warns the user to remove them with `bd setup claude --remove`.

### 3. Land the Plane in the Terminal Skill

The "Land the Plane" session close protocol could live in:
- A separate skill (`session-close`)
- The user's CLAUDE.md
- The terminal skill (`finishing-a-development-branch`)

We chose the terminal skill because **every pipeline path already ends there**:
```
subagent-driven-development → finishing-a-development-branch
executing-plans             → finishing-a-development-branch
```

Putting Land the Plane in Step 6 of the finishing skill means it's impossible to reach the end of any workflow without encountering the mandatory push ritual. No separate skill needed. No CLAUDE.md dependency.

### 4. Orchestrator-Only Beads Management

When `subagent-driven-development` dispatches a fresh agent per task, that subagent could theoretically also manage beads. We chose not to, for three reasons:

1. **Concurrent write conflicts**: Multiple subagents writing to beads simultaneously risks Dolt merge issues
2. **Prompt complexity**: Adding beads instructions to subagent prompts increases token cost and cognitive load
3. **Separation of concerns**: Subagents implement code. The orchestrator manages workflow state.

The pattern: orchestrator creates bead → dispatches subagent → subagent implements → orchestrator closes bead.

### 5. Skills Are Markdown, Not Code

Following Superpowers' zero-dependency philosophy, all skills are plain Markdown files with YAML frontmatter. No build step. No runtime dependencies. No code changes needed.

This means:
- The plugin works on any platform with a file system
- Skills can be read, understood, and modified by humans
- No version compatibility issues with runtimes
- The only runtime dependency is `bd` (beads CLI), which is optional — skills still work without it, they just lose persistence

## The Research Basis

### Persuasion and Compliance Research

The skill enforcement language is grounded in two research streams:

**Cialdini (2021) — Influence Principles Applied to AI:**
- **Authority**: Iron Laws and bright-line rules ("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST")
- **Consistency**: Once an agent starts following a skill, consistency pressure maintains compliance
- **Scarcity**: "You cannot rationalize your way out of this" removes alternatives

**Meincke et al. (2025) — AI Agent Compliance:**
- Compliance **doubled from 33% to 72%** when using absolute rules over hedged guidance
- Pre-emptive rationalization counters outperform reactive correction
- Specific examples of non-compliance are more effective than generic warnings

This is why every discipline-enforcing skill includes:
- An **Iron Law** (absolute, memorable, no exceptions)
- A **Red Flags table** (anticipated rationalizations with pre-loaded counter-arguments)
- **Bright-line rules** (MUST/NEVER/NO EXCEPTIONS instead of "consider"/"prefer"/"try to")

### TDD Applied Recursively

The `writing-skills` meta-skill revealed that TDD principles apply to process documentation itself:

| TDD Concept | Skill Creation Equivalent |
|-------------|--------------------------|
| Test case | Pressure scenario with subagent |
| Production code | Skill document (SKILL.md) |
| Test fails (RED) | Agent violates rule without skill (baseline) |
| Test passes (GREEN) | Agent complies with skill present |
| Refactor | Close loopholes while maintaining compliance |

Every rule in every skill has been empirically verified through adversarial pressure testing — not theoretically designed.

### Claude Search Optimization (CSO)

A critical finding from `writing-skills`:

> When a skill's `description` field summarizes the workflow, Claude may follow the description instead of reading the full skill content. A description saying "code review between tasks" caused Claude to do ONE review, even though the skill clearly showed TWO reviews.

**Rule:** Skill descriptions must answer "When should I use this?" not "What does this do?" This is why every skill's YAML frontmatter `description` field is a trigger condition, not a workflow summary.

### The Seven Types of Agent Memory

Beads provides all seven types of memory that AI agents need:

| Memory Type | Beads Feature | Purpose |
|-------------|--------------|---------|
| **Working** | `bd show --current` | What am I doing right now? |
| **Short-term** | `bd list --status=in_progress` | What's active? |
| **Long-term** | `bd remember` + `bd prime` | Persistent learnings across sessions |
| **Procedural** | `bd formula` | Reusable workflow templates |
| **Episodic** | `events` table | Complete audit trail of what happened |
| **Semantic** | `bd search`, `bd query` | Find related work by meaning |
| **Prospective** | `bd ready` | What should I do next? |

By integrating beads into every skill, we ensure all seven memory types are populated as a natural byproduct of following the workflow.

## The End-to-End Workflow

### What Happens When an Agent Receives a Feature Request

```
1. SessionStart hook fires
   ├── Loads using-superpowers skill (beads-aware routing)
   └── Runs bd prime (beads context + memories)

2. Agent reads user request
   └── Skill check: "Might brainstorming apply?" → YES (any creative work)

3. brainstorming skill activates
   ├── bd create "Brainstorming: auth system" -t task
   ├── Creates child beads for each checklist step
   ├── Explores project context, asks clarifying questions
   ├── Proposes 2-3 approaches with trade-offs
   ├── Presents design, gets user approval
   ├── Writes design spec, commits to git
   └── Terminal state: invokes writing-plans

4. writing-plans skill activates
   ├── Creates implementation plan with bite-sized tasks (2-5 min each)
   ├── Each task has exact file paths, code, verification steps
   ├── Saves plan to docs/
   └── Hands off to subagent-driven-development

5. subagent-driven-development activates
   ├── bd create "Epic: Auth System" -t epic
   ├── bd create "Task 1-5" -t task --parent <epic-id>
   ├── bd dep add (sets task dependencies)
   │
   ├── Per task:
   │   ├── bd update <task-id> --claim
   │   ├── Dispatch implementer subagent (with full task text)
   │   ├── Implementer implements using TDD (RED-GREEN-REFACTOR)
   │   ├── Dispatch spec reviewer subagent → pass/fail loop
   │   ├── Dispatch code quality reviewer subagent → pass/fail loop
   │   └── bd close <task-id> --reason "Completed: spec + quality passed"
   │
   ├── After all tasks: dispatch final code reviewer
   └── Invoke finishing-a-development-branch

6. finishing-a-development-branch activates
   ├── Step 1: Verify all tests pass (hard gate)
   ├── Step 2: Determine base branch
   ├── Step 3: Present 4 options (merge/PR/keep/discard)
   ├── Step 4: Execute chosen option
   ├── Step 5: Cleanup worktree
   └── Step 6: Land the Plane
       ├── bd close <epic-id> --reason "All tasks complete"
       ├── bd dolt push
       ├── git pull --rebase && git push
       └── git status (verify clean)

7. Next session starts
   └── bd prime injects: completed beads, remaining work, memories
```

Every step is tracked. Every decision is auditable. Every session starts where the last one left off.

## What This Enables

### For Individual Developers

- **Cross-session continuity**: Start a feature in one session, continue in the next. `bd prime` tells the agent exactly where you left off.
- **Process discipline without effort**: The skills enforce TDD, debugging methodology, and verification without you needing to remind the agent.
- **Audit trail**: Every task, every review, every close reason is recorded in the beads ledger.

### For Teams

- **Shared project state**: `bd dolt push/pull` syncs beads across team members. Everyone sees the same task state.
- **Multi-agent coordination**: Hash-based IDs and cell-level merge mean multiple agents can work concurrently without conflicts.
- **Convention persistence**: `bd remember "use functional style"` is injected into every future session for every agent.

### For the Ecosystem

- **A reference implementation**: This is the first plugin that fully merges workflow skills with persistent issue tracking.
- **Extensible**: Add your own skills that are beads-aware. The pattern is documented and consistent.
- **Open source**: MIT licensed. Fork it, adapt it, improve it.

## Sources

### Systems Analysed

- [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 — 14 composable skills for AI agents (MIT)
- [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.0 — Persistent issue tracker for AI agents (MIT)

### Research Citations

- Cialdini, R. B. (2021). *Influence: The Psychology of Persuasion* (New and Expanded Edition). Harper Business.
- Meincke, L., et al. (2025). Research on AI agent compliance with explicit vs hedged instructions. Referenced in `skills/writing-skills/persuasion-principles.md`.
- Anthropic best practices for skill authoring. Referenced in `skills/writing-skills/anthropic-best-practices.md`.

### Analysis Documentation

The complete research that informed this integration is available in `docs/`:
- `01-system-architecture.md` through `05-comparison-and-insights.md` — Superpowers deep dive
- `06-beads-system-architecture.md` through `09-beads-design-patterns.md` — Beads deep dive
