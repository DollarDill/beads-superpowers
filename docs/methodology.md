---
description: Bright-line rules and anti-rationalization tables enforce agent discipline. Dolt-backed beads track every task across sessions through a 10-state lifecycle.
---

# Methodology

## The problem

Ask an AI coding agent to build a feature and watch what happens. It skips straight to code, writes implementation before tests, claims the work is "done" without running verification, and if you point out a problem it agrees instantly rather than pushing back. Start a new session the next day and every task it was tracking has vanished.

Two projects attacked each half of this.

### Process discipline

[Superpowers](https://github.com/obra/superpowers) (Jesse Vincent) shipped 14 skills that force agents to brainstorm before coding, write tests before implementation, investigate root causes before proposing fixes, and verify before claiming completion. The skills use bright-line rules — "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" — rather than hedged guidance like "consider writing tests", because compliance doubles from 33% to 72% when instructions are absolute rather than suggested (Meincke et al. 2025). Each skill includes an anti-rationalization table that preempts the excuses agents use to skip steps.

### Persistent memory

Superpowers tracked tasks with `TodoWrite`, which vanishes when a session ends. [Beads](https://github.com/gastownhall/beads) (Steve Yegge) replaced that with a Dolt-backed issue tracker where every task is a bead with a hash-based ID that survives session boundaries. Beads handles dependency tracking, cell-level merges for conflict-free multi-agent work, a full audit trail via the events table, and `bd remember` for persistent learnings. At every session start, the plugin's hook injects a composed beads context — a task-state pointer plus curated memories — so the agent picks up where it left off.

!!! info "Go deeper — upstream Beads docs"
    - [Core concepts](https://gastownhall.github.io/beads/core-concepts) — issues, dependencies, hash IDs, and the memory model
    - [Architecture](https://gastownhall.github.io/beads/architecture) — the Dolt engine and events table under the hood

### The gap

Superpowers enforced good process but forgot everything between sessions. Beads remembered everything but imposed no process on how work should be done. beads-superpowers connects the two: every process step in every skill creates, updates, or closes a persistent bead, so following the right process and maintaining persistent memory are the same action.

## How it works

The plugin installs {{ skill_count }} composable skills and a Dolt-backed task database. A `using-superpowers` bootstrap skill loads at session start and routes the agent to whichever skill fits the current task.

```mermaid
---
config:
  flowchart:
    nodeSpacing: 70
    rankSpacing: 70
---
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

The first change was mechanical: every `TodoWrite` call across the original 14 Superpowers skills was replaced with the equivalent `bd` command.

| Before (TodoWrite) | After (Beads) |
|--------------------|---------------|
| `TodoWrite("Task 1: Implement login")` | `bd create "Task 1: Implement login" -t task --parent <epic-id>` |
| Mark task as in_progress | `bd update <task-id> --claim` |
| Mark task as completed | `bd close <task-id> --reason "Implemented login"` |
| "More tasks remain?" | `bd ready --parent <epic-id>` |

The replacement works at two levels. Execution skills track plan tasks as beads. Checklist-heavy skills like brainstorming (9 steps) create a bead for each internal step. Both levels persist, because if checklist tracking is ephemeral while task tracking is persistent, agents learn that some tracking is optional.

Subsequent changes went further:

**Production-grade doctrine.** Every session now carries a standing instruction to treat the work as production-facing with real users, no matter how small the task looks — the rationalization that ships the worst defects is "it's just a script." On its own initiative the agent does not take shortcuts, quietly drop a requirement, or accept a consequential trade-off, and it never weakens or removes a security control. A warranted exception is surfaced for the user to decide; a security regression is refused outright. The rule lives once in `using-superpowers`, which the session-start hook injects in full every session, and the gate skills — brainstorming, stress-test, code review, and the completion check — reference it where those decisions actually get made.

**Prompt template pattern.** Subagent definitions moved from standalone agent files into prompt templates owned by the skills that dispatch them (`implementer-prompt.md`, `researcher-prompt.md`). One source of truth per subagent role — no drift between the skill's expectations and the subagent's instructions.

**Parallel batch mode.** When `bd ready --parent` returns multiple unblocked tasks, `subagent-driven-development` executes them concurrently (max 5 per batch), each in its own `bd worktree`.

**Orchestrator-only design.** Only the orchestrating agent creates, claims, and closes beads. Subagents focus on their job. The one exception is `implementer-prompt.md`, which is beads-aware by design — it includes bead lifecycle commands, mandatory skill invocations, and LSP-first code navigation.

## The lifecycle

A non-trivial feature request moves through up to 10 states. Simple tasks skip research and planning (S2–S6) but still pass through the quality pipeline (S7–S10). S11 (Session Close) fires only on non-branch paths like research queries.

```mermaid
---
config:
  flowchart:
    nodeSpacing: 70
    rankSpacing: 70
---
graph TD
  Step1["1. Setup<br/>Bead + claim + sync"] --> Step2["2. Research<br/>Parallel agents investigate"]
  Step2 --> Step3["3. Knowledge<br/>Write findings"]
  Step3 --> Step4["4. Brainstorm<br/>Design before code"]
  Step4 --> Step5["5. Decide<br/>Write ADR"]
  Step5 --> Step6["6. Plan<br/>Bite-sized tasks"]
  Step6 --> Step7["7. Implement<br/>TDD in worktree"]
  Step7 --> Step8["8. Verify<br/>Fresh evidence"]
  Step8 --> Step9["9. Document<br/>Audit + prose rewrite"]
  Step9 --> Step10["10. Close Branch<br/>Merge / PR + Land the Plane"]
  Step3 -.-> Step11["11. Session Close<br/>Non-branch paths only"]

  style Step1 fill:#6366f1,color:#fff
  style Step7 fill:#22c55e,color:#000
  style Step10 fill:#f59e0b,color:#000
  style Step11 fill:#64748b,color:#fff
```

**Step 1 — Setup.** Every task begins with a bead. Before any research or code, the work is captured (`bd create`), claimed (`bd update --claim`), and synced. If the session dies, the bead record shows an in-progress item that can be recovered.

**Step 2 — Research.** The `research-driven-development` skill decomposes the topic into sub-questions and dispatches one researcher per sub-question in parallel — plus an `@explore` agent that maps the affected code when the topic touches the codebase. Running them concurrently cuts research time sharply, and each agent returns a verbatim quote for every load-bearing claim, which a separate blinded verifier then double-checks by independently re-fetching the source, so findings are grounded in what the sources actually say rather than taken on trust.

**Step 3 — Knowledge capture.** Findings are written to a persistent document; key learnings go into `bd remember` so they surface in future sessions.

**Step 4 — Brainstorming.** The `brainstorming` skill walks through context, clarifying questions, 2–3 approaches with trade-offs, and a design spec committed to git. It ends by invoking `writing-plans` — not by jumping to code. The spec-review gate offers a `stress-test` every time, to interrogate the design adversarially before planning.

**Step 5 — Decision capture.** When a choice is hard to reverse, surprising without its context, and the result of a real trade-off, the agent offers to record it as an Architecture Decision Record in `docs/decisions/` — a timestamped note of the context, decision, rationale, and consequences. These are recognition marks, not a checklist to slip past: when a decision plausibly fits, the agent leans toward offering rather than skipping, and only routine clarifications and scope calls stay out. The rule lives once in `using-superpowers` and is echoed where decisions actually get made: brainstorming, planning, stress-testing, and the pivot in a debugging session.

**Step 6 — Planning.** `writing-plans` breaks the design into bite-sized tasks (2–5 minutes each) with exact file paths, code, and verification steps. Every task becomes a bead.

**Step 7 — Implementation.** Code runs in an isolated git worktree under TDD. The orchestrator creates an epic with task children and dependency chains, then dispatches implementer subagents. When multiple tasks are unblocked, parallel batch mode runs up to 5 concurrently, each in its own worktree. After each task, one read-only reviewer returns a spec-compliance verdict and a code-quality verdict in a single pass; the bead closes only after that review passes. Task briefs, implementer reports, and review diffs move between stages as files under a per-worktree `.internal/sdd/` directory, keeping the orchestrator's context lean.

**Step 8 — Verification.** The full test suite runs fresh — not relying on the last run during development. "Tests pass" means a test command was just executed and its output is attached.

**Step 9 — Documentation.** `document-release` scans the diff against existing docs for stale references, missing entries, and outdated examples. When the audit flags sections needing major prose rewrites, `write-documentation` fires for those sections.

**Step 10 — Close branch.** `finishing-a-development-branch` detects the current environment — normal repository, named-branch worktree, or detached HEAD — and presents context-aware options: 4 choices for normal and worktree contexts, 3 for detached HEAD where merge is unavailable. Provenance-based cleanup only removes worktrees inside `.worktrees/`, leaving externally created worktrees alone. The skill ends with the Land the Plane protocol: if the session produced several new memories, offer a `memory-curator` pass before `bd dolt push`; then `bd close` → `bd dolt push` → `git push` → `git status`. Branch paths terminate here — work is not done until both task state and code reach the remote.

**Step 11 — Session close.** Fires only on non-branch paths (research queries, quick tasks that didn't create a branch). Runs the same close ritual as Step 10's Land the Plane: close beads, offer a `memory-curator` pass if the session produced several new memories, push to remotes, verify clean state. The next session's start-hook injection restores the full picture.

## Agent memory

Because beads tracks every process step, the memory types agents need are populated as a side effect of following the workflow. Most of the {{ skill_count }} skills now prompt for `bd remember` at their natural completion points — root causes after debugging, design decisions after brainstorming, review insights after code review — so memory capture happens within the skill workflow, not as a separate step.

| Memory Type | Beads Feature | What it answers |
|-------------|---------------|-----------------|
| Working | `bd show --current` | What am I doing right now? |
| Short-term | `bd list --status=in_progress` | What's active? |
| Long-term | `bd remember` + curated injection + `bd memories` | What did I learn last week? |
| Procedural | Skill checklists + `bd ready` | How do I do this kind of task? |
| Episodic | `events` table | What happened and when? |
| Semantic | `bd search`, `bd query` | Where's the related work? |
| Prospective | `bd ready` | What should I do next? |

The `memory-curator` skill consolidates, deduplicates, and prunes the memory store that `bd remember` builds up — offered at session-close when several new memories were captured, or on-demand anytime.

Not every memory belongs in the injected set. The curator classifies each note by `@type`, and the type *is* the routing decision: actionable rules you want surfaced unprompted (`lesson`, `pattern`, `root-cause`, `correction`) stay injected memories, while reference-class notes that merely point at a doc or ADR (`research`, `design`, `decision`) route to a **`bsp.kb.` key-value knowledge base** — persisted and Dolt-synced, but never auto-injected. Retrieve those on demand with `bd kv list | grep '^ *bsp.kb'` (or the structured `bd kv list --json | jq` form). The injected context stays small and high-signal while nothing is lost.

## Research basis

### Cialdini (2021) — Influence principles

Three principles from *Influence: The Psychology of Persuasion* shape how skills are written. Authority: Iron Laws use absolute phrasing because agents treat authoritative instructions as harder to override. Consistency: once an agent begins a skill's process, consistency pressure keeps it on track through the remaining steps. Scarcity: phrasing like "you cannot rationalize your way out of this" removes the sense that alternatives exist.

### Meincke et al. (2025) — Absolute vs hedged instructions

Compliance doubled from 33% to 72% when AI agents received absolute rules instead of hedged guidance. Pre-emptive rationalization counters outperformed reactive correction. Specific examples of non-compliance were more effective than generic warnings. These findings explain the structure of every discipline-enforcing skill: an Iron Law (absolute, no exceptions), a Red Flags table (anticipated rationalizations with counter-arguments), and bright-line rules (MUST/NEVER rather than "consider" or "prefer").

### TDD applied recursively

Upstream superpowers' writing-skills meta-skill (not shipped in this fork) revealed that TDD principles apply to process documentation itself:

| TDD Concept | Skill Creation Equivalent |
|-------------|--------------------------|
| Test case | Pressure scenario with subagent |
| Production code | Skill document (SKILL.md) |
| RED | Agent violates rule without skill (baseline) |
| GREEN | Agent complies with skill present |
| Refactor | Close loopholes while maintaining compliance |

Every rule in every skill has been verified through adversarial pressure testing, not designed from theory alone.

### Skill Discovery Optimization (SDO)

An empirical finding: when a skill's YAML `description` field summarized the workflow ("code review between tasks"), the agent followed the description instead of reading the full skill content and skipped steps the full skill specified. As a result, every skill's `description` is a trigger condition ("when to use this"), not a workflow summary ("what this does"), which forces the full content to be read.

## Design decisions

**Plugin subsumes beads hooks.** Beads' `bd setup claude` installs hooks that run `bd prime`. The plugin also needs to inject skill context. Rather than fire both and waste tokens on redundant context, the plugin's hook does both jobs — composing a salience-curated beads context under a hard 8 KB ceiling instead of injecting the full `bd prime` dump (measured −91.6% on a 218-memory store) — and yields its beads section, with a warning, if the standalone hooks are still installed.

**Land the Plane in the branch skill.** The session close protocol lives in `finishing-a-development-branch` (Step 6) rather than a separate skill. Branch paths terminate at S10, which includes the full push ritual. Non-branch paths (research queries) use S11 (SESSION_CLOSE) for the same ritual without the branch decision tree.

**Template-only agent dispatch.** Code review was the last subagent dispatched via a standalone agent file (`agents/code-reviewer.md`). In v0.6.0 the file was removed and the reviewer dispatches through its skill's prompt template, matching the implementer and researcher. All subagent definitions now live inside the skills that use them.

**Skills are Markdown, not code.** Following Superpowers' zero-dependency philosophy, all skills are plain Markdown with YAML frontmatter. No build step. The only runtime dependency is `bd`, which is optional — skills still work without it, they just lose persistence.

## Sources

- [obra/superpowers](https://github.com/obra/superpowers) v6.1.1 — composable skills for AI agents (MIT)
- [gastownhall/beads](https://github.com/gastownhall/beads) v1.1.0 — Persistent issue tracker for AI agents (MIT)
- Cialdini, R. B. (2021). *Influence: The Psychology of Persuasion* (New and Expanded Edition). Harper Business.
- Meincke, L., et al. (2025). AI agent compliance with explicit vs hedged instructions. Referenced in upstream superpowers' writing-skills/persuasion-principles.md.
