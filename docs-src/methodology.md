# Methodology

Why beads-superpowers exists, how it works, and what research shaped the design.

## The Problem

Ask an AI coding agent to build a feature and watch what happens. It skips straight to code, writes implementation before tests, claims the work is "done" without running verification, and if you point out a problem it agrees instantly rather than pushing back. When you start a new session the next day, every task it was tracking has vanished. Two separate projects attacked each half of this problem.

### Process Discipline

[Superpowers](https://github.com/obra/superpowers) (Jesse Vincent) shipped 14 composable skills that force agents to brainstorm before coding, write tests before implementation, investigate root causes before proposing fixes, and verify before claiming completion. The skills use bright-line rules ("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST") rather than hedged guidance ("consider writing tests"), because compliance doubles from 33% to 72% when instructions are absolute rather than suggested (Meincke et al. 2025). Each skill includes an anti-rationalization table that preempts the excuses agents use to skip process steps.

### Persistent Memory

Superpowers tracked tasks with `TodoWrite`, which vanishes when a session ends. [Beads](https://github.com/gastownhall/beads) (Steve Yegge) replaced that with a Dolt-backed issue tracker where every task is a bead with a hash-based ID that survives session boundaries. Beads handles dependency tracking, cell-level merges for conflict-free multi-agent work, a full audit trail via the events table, and `bd remember` for persistent learnings. At every session start, `bd prime` injects the current task state so the agent picks up where it left off.

### The Gap

Superpowers enforced good process but forgot everything between sessions. Beads remembered everything but imposed no process on how work should be done. beads-superpowers connects the two: every process step in every skill now creates, updates, or closes a persistent bead, so following the right process and maintaining persistent memory are the same action.

## How It Works

The plugin installs {{ skill_count }} composable skills and a Dolt-backed task database. A `using-superpowers` bootstrap skill loads at session start and routes the agent to whichever skill fits the current task. The Dolt database stores every bead (task) with hash-based IDs, dependency chains, and an events table that records what happened and when.

```mermaid
graph TB
  subgraph Superpowers ["Superpowers (Process Discipline)"]
    S1["{{ skill_count }} Composable Skills"]
    S2["Bright-line Rules"]
    S3["Anti-rationalization"]
    S4["Pressure-tested Enforcement"]
  end
  subgraph Beads ["Beads (Persistent Memory)"]
    B1["Dolt-backed DB"]
    B2["Cross-session State"]
    B3["Dependency Tracking"]
    B4["Persistent Memories"]
  end
  Superpowers --> Merge["beads-superpowers"]
  Beads --> Merge
  Merge --> Result["Skills + Persistent Ledger"]

  style Merge fill:#6366f1,color:#fff
  style Result fill:#22c55e,color:#000
```

## The Integration

The core change was mechanical: every `TodoWrite` call across the original 14 Superpowers skills was replaced with the equivalent `bd` command. The result is that following process discipline and populating persistent memory are the same action.

| Before (TodoWrite) | After (Beads) |
|--------------------|---------------|
| `TodoWrite("Task 1: Implement login")` | `bd create "Task 1: Implement login" -t task --parent <epic-id>` |
| Mark task as in_progress | `bd update <task-id> --claim` |
| Mark task as completed | `bd close <task-id> --reason "Implemented login"` |
| "More tasks remain?" | `bd ready --parent <epic-id>` |
| Create todo per checklist item | `bd create "Step: title" -t chore --parent <session-id>` |

The replacement operates at two levels. At the task level, execution skills track plan tasks as beads. At the checklist level, skills like brainstorming (9 steps) and writing-skills (20 steps) create a bead for each internal step. Both levels are persistent and auditable, because if checklist-level tracking is ephemeral while task-level tracking is persistent, agents learn that some tracking is optional.

### Orchestrator-Only Design

Subagent prompts (implementer, spec-reviewer, code-quality-reviewer) are deliberately not beads-aware. Only the orchestrating agent creates, claims, and closes beads. Subagents focus on their specific job. This prevents concurrent write conflicts and keeps subagent prompts simple: orchestrator creates bead, dispatches subagent, subagent does the work, orchestrator closes bead.

### What Was Added

Beyond the `TodoWrite` replacement, the integration added several structural pieces. The `using-superpowers` skill gained a Beads Issue Tracking section so every session starts with beads awareness. The `finishing-a-development-branch` skill gained the Land the Plane protocol (`bd dolt push` + `git push`) so every session ends with both task state and code synced to remote. The `verification-before-completion` skill requires evidence in `bd close` because closing a bead without evidence is treated the same as not verifying. Execution skills use an epic/child bead pattern with `bd dep add` for dependency tracking, and brainstorming beads link forward to plan epics via `discovered-from` so the design trail is connected to the implementation trail.

## What Was Preserved

The integration was additive. All 14 original Superpowers skills kept their complete content: every anti-rationalization table, Iron Law, Red Flags section, the progressive skill chain (brainstorming, plans, execution, finishing), the two-stage review pattern (spec compliance then code quality), all three subagent prompt templates, and the platform reference files for Gemini, Copilot CLI, and Codex.

Since the fork, the project has grown from 14 to {{ skill_count }} skills. The eight additions are `auditing-upstream-drift`, `document-release`, `getting-up-to-speed`, `project-init`, `setup`, `stress-test`, `write-documentation`, and `research-driven-development`.

## Design Decisions

### Plugin Subsumes Beads Hooks

Beads' `bd setup claude` command installs SessionStart hooks that run `bd prime`. The plugin's SessionStart hook also needs to inject the `using-superpowers` skill content. Having both fire would inject 3-4k tokens of partially redundant context, so the plugin's `hooks/session-start` script does both: it injects `using-superpowers` and runs `bd prime` itself. It also detects if the `bd setup claude` hooks are still installed and warns the user to remove them.

### Land the Plane in the Terminal Skill

The session close protocol lives in `finishing-a-development-branch` (Step 6) rather than a separate `session-close` skill or the user's CLAUDE.md. Both `subagent-driven-development` and `executing-plans` already end by invoking this skill, so every pipeline path passes through the mandatory push ritual without needing a separate dependency.

### Skills Are Markdown, Not Code

Following Superpowers' zero-dependency philosophy, all skills are plain Markdown files with YAML frontmatter. No build step, no runtime dependencies. The plugin works on any platform with a file system, skills can be read and modified by humans, and the only runtime dependency is `bd` (beads CLI), which is optional — skills still work without it, they just lose persistence.

## Agent Memory Types

Because beads tracks every process step, the seven memory types agents need are populated as a side effect of following the workflow rather than requiring separate bookkeeping.

| Memory Type | Beads Feature | Purpose |
|-------------|---------------|---------|
| **Working** | `bd show --current` | What am I doing right now? |
| **Short-term** | `bd list --status=in_progress` | What's active? |
| **Long-term** | `bd remember` + `bd prime` | Persistent learnings across sessions |
| **Procedural** | `bd formula` | Reusable workflow templates |
| **Episodic** | `events` table | Complete audit trail of what happened |
| **Semantic** | `bd search`, `bd query` | Find related work by meaning |
| **Prospective** | `bd ready` | What should I do next? |

## Research Basis

The enforcement language in skills draws on two lines of research, plus one empirical finding from the project itself.

### Cialdini (2021) — Influence Principles

Three principles from *Influence: The Psychology of Persuasion* (New and Expanded Edition) shape how skills are written. Authority: Iron Laws use absolute phrasing ("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST") because agents treat authoritative instructions as harder to override. Consistency: once an agent begins following a skill's process, consistency pressure keeps it on track through the remaining steps. Scarcity: phrasing like "you cannot rationalize your way out of this" removes the sense that alternatives exist.

### Meincke et al. (2025) — Compliance with Absolute vs. Hedged Instructions

This study found that compliance doubled from 33% to 72% when AI agents received absolute rules instead of hedged guidance, that pre-emptive rationalization counters outperformed reactive correction, and that specific examples of non-compliance were more effective than generic warnings. These findings explain the structure of every discipline-enforcing skill: an Iron Law (absolute, memorable, no exceptions), a Red Flags table (anticipated rationalizations with pre-loaded counter-arguments), and bright-line rules (MUST/NEVER rather than "consider" or "prefer").

### TDD Applied Recursively

The `writing-skills` meta-skill revealed that TDD principles apply to process documentation itself:

| TDD Concept | Skill Creation Equivalent |
|-------------|--------------------------|
| Test case | Pressure scenario with subagent |
| Production code | Skill document (SKILL.md) |
| Test fails (RED) | Agent violates rule without skill (baseline) |
| Test passes (GREEN) | Agent complies with skill present |
| Refactor | Close loopholes while maintaining compliance |

Every rule in every skill has been verified through adversarial pressure testing, not designed from theory alone.

### Claude Search Optimization (CSO)

An empirical finding from the `writing-skills` meta-skill: when a skill's YAML `description` field summarized the workflow ("code review between tasks"), Claude followed the description instead of reading the full skill content and did one review instead of the two the skill specified. As a result, every skill's `description` field is now a trigger condition ("when to use this") rather than a workflow summary ("what this does"), which forces the full skill content to be read.

## End-to-End Workflow

Here is a feature request moving through the full pipeline, from session start to the next session picking up where the first left off.

```mermaid
graph TD
  Step1["1. Session Start<br/>Hook loads skills + bd prime"] --> Step2["2. Brainstorming<br/>Design before code"]
  Step2 --> Step3["3. Writing Plans<br/>Bite-sized tasks with beads"]
  Step3 --> Step4["4. Subagent-Driven Dev<br/>TDD + two-stage review per task"]
  Step4 --> Step5["5. Finishing Branch<br/>Merge / PR / cleanup"]
  Step5 --> Step6["6. Land the Plane<br/>bd close + git push"]
  Step6 --> Step7["7. Next Session<br/>bd prime restores state"]

  style Step1 fill:#6366f1,color:#fff
  style Step4 fill:#22c55e,color:#000
  style Step6 fill:#f59e0b,color:#000
```

### Step 1 — Session Start

The SessionStart hook loads `using-superpowers` (beads-aware skill routing) and runs `bd prime`, which injects the current task state and any persistent memories from previous sessions. If the last session ended mid-feature, the agent sees exactly what was finished and what remains.

### Step 2 — Brainstorming

For any creative work, the `brainstorming` skill fires first. It creates a session bead (`bd create "Brainstorming: auth system" -t task`) and child beads for each checklist step, then walks through project context, clarifying questions, 2-3 approaches with trade-offs, and a design spec that gets committed to git. The terminal state is invoking `writing-plans`, not jumping to code.

### Step 3 — Writing Plans

`writing-plans` breaks the approved design into bite-sized tasks (2-5 minutes each) with exact file paths, code snippets, and verification steps. The plan is saved to `docs/` and handed to `subagent-driven-development`.

### Step 4 — Subagent-Driven Development

The orchestrator creates an epic bead with task children and dependency chains:

```bash
bd create "Epic: Auth System" -t epic
bd create "Task 1-5" -t task --parent <epic-id>
bd dep add <child> <depends-on>
```

For each task, the orchestrator claims it, dispatches an implementer subagent that works under TDD (red-green-refactor), then dispatches a spec reviewer and a code quality reviewer in sequence. Only after both reviewers pass does the orchestrator close the bead. After all tasks complete, a final code review runs and `finishing-a-development-branch` takes over.

### Step 5 — Finishing the Branch

`finishing-a-development-branch` verifies that all tests pass (hard gate, no exceptions), determines the base branch, presents four options (merge locally, create PR, keep the branch, or discard), executes the chosen option, and cleans up the worktree.

### Step 6 — Land the Plane

```bash
bd close <epic-id> --reason "All tasks complete"
bd dolt push
git pull --rebase && git push
git status
```

Work is not done until both `bd dolt push` (task state) and `git push` (code) succeed. `git status` must show "up to date with origin" before the agent stops.

### Step 7 — Next Session

`bd prime` restores the full picture: completed beads, remaining work, learned memories. The next agent picks up where this one left off, with no manual handoff needed.

## What This Enables

**For individual developers:** Cross-session continuity via `bd prime`, process discipline without needing to remind the agent, and a full audit trail of every task, review, and close reason in the beads ledger.

**For teams:** Shared project state via `bd dolt push/pull`, concurrent multi-agent work via hash-based IDs and cell-level merge, and convention persistence via `bd remember` (injected into every future session for every agent).

**For the ecosystem:** A reference implementation that fully merges workflow skills with persistent issue tracking. MIT licensed, extensible, and the pattern is documented.

## Sources

### Systems

- [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 — 14 composable skills for AI agents (MIT)
- [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.2 — Persistent issue tracker for AI agents (MIT)

### Research

- Cialdini, R. B. (2021). *Influence: The Psychology of Persuasion* (New and Expanded Edition). Harper Business.
- Meincke, L., et al. (2025). Research on AI agent compliance with explicit vs hedged instructions. Referenced in `skills/writing-skills/persuasion-principles.md`.
- Anthropic best practices for skill authoring. Referenced in `skills/writing-skills/anthropic-best-practices.md`.

### Analysis Documentation

The complete research that informed this integration is available in `docs/`:

- `01-system-architecture.md` through `05-comparison-and-insights.md` — Superpowers deep dive
- `06-beads-system-architecture.md` through `09-beads-design-patterns.md` — Beads deep dive
