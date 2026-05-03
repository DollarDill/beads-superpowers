# Skills Reference

beads-superpowers ships {{ skill_count }} composable skills loaded on demand via the `Skill` tool. The bootstrap skill `using-superpowers` loads at every session start and routes to the right skill for the current task. Skills are mandatory — when one applies, the agent must invoke it.

## Trigger map

The UserPromptSubmit hook reminds the agent on every message which skill applies to which task:

| Task | Skill |
|---|---|
| Bug or test failure | `systematic-debugging` |
| Writing code | `test-driven-development` |
| New feature or design | `brainstorming` |
| Stress-test a design | `stress-test` |
| Writing a plan | `writing-plans` |
| Executing a plan | `subagent-driven-development` / `executing-plans` |
| Research question | `research-driven-development` |
| Complex task (6+ files) | `using-git-worktrees` |
| About to claim done | `verification-before-completion` |
| Code review needed | `requesting-code-review` |
| Received review feedback | `receiving-code-review` |
| Writing human-facing prose | `write-documentation` |
| Branch complete | `finishing-a-development-branch` |

Also available: `document-release`, `getting-up-to-speed`, `dispatching-parallel-agents`, `project-init`, `setup`, `writing-skills`, `auditing-upstream-drift`

## By category

| Category | Skills |
|---|---|
| **Meta** | [using-superpowers](#using-superpowers), [writing-skills](#writing-skills) |
| **Design** | [brainstorming](#brainstorming), [writing-plans](#writing-plans), [stress-test](#stress-test) |
| **Execution** | [subagent-driven-development](#subagent-driven-development), [executing-plans](#executing-plans), [dispatching-parallel-agents](#dispatching-parallel-agents) |
| **Quality** | [test-driven-development](#test-driven-development), [systematic-debugging](#systematic-debugging), [verification-before-completion](#verification-before-completion) |
| **Review** | [requesting-code-review](#requesting-code-review), [receiving-code-review](#receiving-code-review) |
| **Infrastructure** | [using-git-worktrees](#using-git-worktrees), [finishing-a-development-branch](#finishing-a-development-branch) |
| **Lifecycle** | [document-release](#document-release), [getting-up-to-speed](#getting-up-to-speed), [auditing-upstream-drift](#auditing-upstream-drift) |
| **Setup** | [setup](#setup), [project-init](#project-init) |
| **Research** | [research-driven-development](#research-driven-development) |
| **Writing** | [write-documentation](#write-documentation) |

```mermaid
---
config:
  flowchart:
    nodeSpacing: 70
    rankSpacing: 70
---
graph TD
  subgraph Meta
    US["using-superpowers"]
    WS["writing-skills"]
  end
  subgraph Design
    BR["brainstorming"]
    STR["stress-test"]
    WP["writing-plans"]
  end
  subgraph Execution
    SDD["subagent-driven-dev"]
    EP["executing-plans"]
    DPA["dispatching-parallel"]
  end
  subgraph Quality
    TDD["test-driven-dev"]
    SD["systematic-debugging"]
    VBC["verification"]
  end
  subgraph Review
    RCR["requesting-review"]
    REC["receiving-review"]
  end
  subgraph Infra ["Infrastructure"]
    WT["using-git-worktrees"]
    FAB["finishing-branch"]
  end
  subgraph Lifecycle
    DR["document-release"]
    GUS["getting-up-to-speed"]
    AUD["auditing-drift"]
  end
  subgraph Setup
    SET["setup"]
    PI["project-init"]
  end
  subgraph Research
    RDD["research-driven-dev"]
  end
  subgraph Writing
    WD["write-documentation"]
  end

  Meta --> Design
  Design --> Execution
  Execution --> Quality
  Quality --> Review
  Review --> Infra

  style Meta fill:#6366f1,color:#fff
  style Design fill:#818cf8,color:#fff
  style Execution fill:#22c55e,color:#000
  style Quality fill:#f59e0b,color:#000
  style Review fill:#06b6d4,color:#000
  style Infra fill:#14b8a6,color:#000
  style Lifecycle fill:#64748b,color:#fff
  style Setup fill:#64748b,color:#fff
  style Research fill:#8b5cf6,color:#fff
  style Writing fill:#ec4899,color:#fff
```

## All skills

### using-superpowers

Bootstrap skill injected at every session start. Routes the agent to the correct skill for the current task. All other skills depend on this one having loaded first.

### writing-skills

Meta-skill for creating and modifying skills. Enforces TDD-for-process-docs: new skills need a failing test before the SKILL.md is written. Frontmatter descriptions must be trigger conditions, not workflow summaries (see CSO in [Methodology](methodology.md)).

### brainstorming

**Trigger:** Before any creative work — features, components, or behavior changes.

Socratic design exploration. Asks structured questions to surface requirements, constraints, and design alternatives. Produces a committed design spec. Ends by invoking `writing-plans`, not by jumping to code.

### writing-plans

**Trigger:** When you have a spec or requirements for a multi-step task.

Breaks a design into bite-sized tasks (2–5 minutes each) with exact file paths, code, and verification steps. Every task becomes a bead with dependency ordering.

### stress-test

**Trigger:** When a design or plan needs adversarial scrutiny. Also triggers on "grill me", "poke holes", "challenge this design".

Interrogates every branch of the decision tree with recommended answers, forcing explicit agreement or rejection of each critique. Typically runs between brainstorming and writing-plans.

### subagent-driven-development

**Trigger:** When executing a plan with independent tasks.

Dispatches a fresh subagent per task with two-stage code review between tasks. The orchestrator tracks beads; subagents don't touch them. When multiple tasks are unblocked, **parallel batch mode** runs up to 5 concurrently, each in its own worktree.

### executing-plans

**Trigger:** When executing a plan in a single session with review checkpoints.

Runs a multi-phase plan sequentially: claim, implement, verify against acceptance criteria, close, next phase. Designed to complement `writing-plans` output directly.

### dispatching-parallel-agents

**Trigger:** When facing 2+ independent tasks without shared state.

Coordinates concurrent subagents for independent work — plan tasks, subsystem changes, anything without shared mutable state. Used by SDD's parallel batch mode for the dispatch pattern.

### test-driven-development

**Trigger:** Before writing any implementation code.

Iron Law: no production code without a failing test first. Requires explicit evidence of the failing test output before any implementation is touched. RED-GREEN-REFACTOR, no shortcuts.

### systematic-debugging

**Trigger:** Any bug, test failure, or unexpected behavior — before proposing fixes.

Four-phase root cause analysis: observe, hypothesize, isolate, fix. Requires a confirmed root cause before any code change. Blocks "just try this and see."

### verification-before-completion

**Trigger:** Before claiming work is done, fixed, or passing.

The agent must run verification commands and show actual output — not assert from memory — before closing a bead or creating a PR. Evidence before assertions, always.

### requesting-code-review

**Trigger:** After completing tasks, major features, or before merging.

Dispatches a code reviewer subagent that runs two stages: spec compliance first, then code quality. The reviewer gets the original requirements alongside the diff.

### receiving-code-review

**Trigger:** When review feedback arrives, especially if unclear or questionable.

Anti-sycophancy protocol. Requires technical evaluation of each suggestion rather than blind acceptance. Escalates disagreements explicitly.

### using-git-worktrees

**Trigger:** Feature work needing isolation, or before executing plans.

Creates and manages isolated git worktrees via `bd worktree`. Supports multiple concurrent worktrees for parallel subagent work — one per task, max 5.

### finishing-a-development-branch

**Trigger:** Implementation complete, tests pass, ready to integrate.

Decision tree: merge locally, create PR, keep branch, or discard. Ends with the mandatory Land the Plane sequence: `bd close` → `bd dolt push` → `git push`.

### document-release

**Trigger:** After code changes are committed, before PR merge.

Walks through README, CHANGELOG, CLAUDE.md, CONTRIBUTING, and other docs to find and fix drift against shipped code.

### getting-up-to-speed

**Trigger:** Session start, after compaction, or "catch me up" / "where are we".

Runs `bd prime`, deep-dives the codebase (adaptive to repo size), and produces a structured current-state summary.

### auditing-upstream-drift

**Trigger:** Before a plugin release, or when checking for staleness.

Audits against [obra/superpowers](https://github.com/obra/superpowers) and [gastownhall/beads](https://github.com/gastownhall/beads) for new skills, changed commands, and documentation improvements to port.

### setup

**Trigger:** After npx install, or when skills aren't activating.

Registers the SessionStart hook in `.claude/settings.json` so skills activate automatically. Detects and removes duplicate hooks from `bd setup claude`.

### project-init

**Trigger:** When `bd` commands fail, setting up beads in a new project, or recovering from diverged Dolt history.

Three paths: fresh init, bootstrap from remote, or recovery when Dolt history has diverged.

### research-driven-development

**Trigger:** Research questions, "what is X", "how does Y work", "compare A vs B".

Dispatches a researcher subagent and `@explore` in parallel, synthesizes findings into a persistent document. Iron Law: no research without a document — verbal answers without persistent artifacts are prohibited.

### write-documentation

**Trigger:** Writing or rewriting human-facing prose — docs, guides, emails, PR descriptions, release notes.

14-rule writing system adapted from [WRITING.md](https://github.com/Anbeeld/WRITING.md). Context-first drafting, required checks as revision pass, targets the patterns that make LLM prose recognizable (regularity, catalog prose, false crispness). Pairs with `document-release` (which handles *when* to update, not *how* to write).

## Beads commands

Skills use `bd` commands to track work. Only the orchestrating agent manages beads — subagents don't touch them.

| Action | Command | Used in |
|---|---|---|
| Create epic | `bd create "Epic: name" -t epic` | SDD, executing-plans |
| Create task | `bd create "Task: name" -t task --parent <epic>` | SDD, executing-plans |
| Quick capture | `bd q "title"` | any skill |
| Claim work | `bd update <id> --claim` | executing-plans |
| Complete work | `bd close <id> --reason "why"` | all execution skills |
| Check remaining | `bd ready --parent <epic>` | SDD, executing-plans |
| Add dependency | `bd dep add <child> <parent>` | SDD, writing-plans |
| Store learning | `bd remember "insight"` | 17 of {{ skill_count }} skills prompt for this |
| Attach evidence | `bd note <id> "context"` | verification |
| Sync to remote | `bd dolt push` | finishing-a-development-branch |

## How skills chain

```mermaid
---
config:
  flowchart:
    nodeSpacing: 70
    rankSpacing: 70
---
graph TD
  US["using-superpowers<br/>(bootstrap)"] --> B["brainstorming"]
  US --> TDD["test-driven-development"]
  US --> SD["systematic-debugging"]
  US --> RDD["research-driven-development"]
  US --> WD["write-documentation"]
  B -.-> ST["stress-test"]
  B --> WP["writing-plans"]
  WP --> SDD["subagent-driven-development"]
  WP --> EP["executing-plans"]
  SDD --> GW["using-git-worktrees"]
  SDD --> RCR["requesting-code-review"]
  SDD --> SD
  SDD --> FAB["finishing-a-development-branch"]
  EP --> FAB

  style US fill:#6366f1,color:#fff
  style FAB fill:#f59e0b,color:#000
  style TDD fill:#22c55e,color:#000
  style SD fill:#ef4444,color:#fff
```

Edges show direct skill-to-skill invocations only — transitions managed by the orchestrator (e.g., verification → document-release → finishing) are omitted. Dashed edges are optional. Skills like `systematic-debugging`, `verification-before-completion`, and `receiving-code-review` fire whenever their trigger is met, regardless of workflow position.
