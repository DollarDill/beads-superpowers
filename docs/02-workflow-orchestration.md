# Superpowers Workflow Orchestration

> How skills chain together, the happy path pipeline, dependency graph, and cross-reference patterns

## The Happy Path Pipeline

The canonical workflow is a strict linear pipeline with one branch point:

```
Session Start
  │
  ▼
using-superpowers ──→ (auto-loaded by SessionStart hook)
  │                    Decision flowchart: "Might any skill apply?"
  │                    If yes (even 1% chance) → invoke skill
  ▼
brainstorming ──────→ Socratic design exploration
  │                    Writes spec to docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
  │                    HARD GATE: User must approve design before proceeding
  ▼
using-git-worktrees → Creates isolated workspace
  │
  ▼
writing-plans ──────→ Breaks spec into 2-5 minute tasks
  │                    Writes plan to docs/superpowers/plans/YYYY-MM-DD-<feature>.md
  │
  ├──[Subagents available?]──────────────┐
  │                                      │
  ▼                                      ▼
subagent-driven-development         executing-plans
  │  (RECOMMENDED)                    │  (fallback: same session)
  │  Fresh agent per task             │  Batch execution
  │  Two-stage review per task        │  Human checkpoints
  │  Spec compliance → Code quality   │
  │                                   │
  ├───────────────────────────────────┘
  ▼
finishing-a-development-branch ──→ 4 options:
                                    1. Merge locally
                                    2. Push + Create PR
                                    3. Keep as-is
                                    4. Discard (requires typed "discard" confirmation)
```

**Throughout the implementation phase**, these skills are invoked by subagents as needed:
- `test-driven-development` — by each implementer subagent for every task
- `requesting-code-review` / `code-reviewer` agent — between each task
- `verification-before-completion` — before any completion claim
- `systematic-debugging` — when bugs are encountered

## Full Dependency Graph

```
                     [SessionStart Hook]
                            │
                            ▼
                   using-superpowers ────→ (decision flowchart)
                            │
                            ▼
                      brainstorming
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
       using-git-worktrees        writing-plans
                ▲                  │         │
                │          ┌──────┘         └────────┐
                │          │                         │
                │          ▼                         ▼
                ├── subagent-driven-dev        executing-plans
                │     │  │  │  │  │                │
                │     │  │  │  │  └→ requesting-code-review → [code-reviewer agent]
                │     │  │  │  └──→ test-driven-development
                │     │  │  └─────→ executing-plans (alt path)
                │     │  └────────→ writing-plans (upstream ref)
                │     │
                │     ▼
                └── finishing-a-development-branch
                            │
                            ▼
                       [worktree cleanup]


     [Separate debugging path]
     systematic-debugging ──→ test-driven-development (Phase 4)
                          ──→ verification-before-completion

     [Meta path]
     writing-skills ──→ test-driven-development (REQUIRED BACKGROUND)
```

## Skill Connectivity Analysis

### Hub Skills by Reference Count

| Skill | Inbound Refs | Outbound Refs | Total Edges | Role |
|-------|-------------|--------------|-------------|------|
| **subagent-driven-development** | 3 | 7 | **10** | **Highest-connectivity hub** |
| **test-driven-development** | 4 | 0 | 4 | Most-referenced leaf node |
| **finishing-a-development-branch** | 3 | 1 | 4 | Terminal node |
| **using-git-worktrees** | 3 | 1 | 4 | Infrastructure prerequisite |
| **writing-plans** | 3 | 2 | 5 | Pipeline center |
| **executing-plans** | 3 | 4 | 7 | Alternative hub |
| **brainstorming** | 1 | 1 | 2 | Entry point |
| **using-superpowers** | 0 | 1 | 1 | Bootstrap root (hook-loaded) |
| **requesting-code-review** | 1 | 1 | 2 | Review dispatch |
| **systematic-debugging** | 0 | 2 | 2 | Debugging entry |
| **verification-before-completion** | 1 | 0 | 1 | Standalone leaf |
| **receiving-code-review** | 0 | 0 | 0 | Standalone |
| **dispatching-parallel-agents** | 0 | 0 | 0 | Standalone |
| **writing-skills** | 0 | 1 | 1 | Meta-skill |

**Key insight:** `subagent-driven-development` is the most interconnected skill (10 edges), acting as the orchestration hub that coordinates worktrees, plans, TDD, code review, and branch finishing.

## Cross-Reference Patterns

The system uses three distinct reference types:

### 1. REQUIRED SUB-SKILL — Mandatory Chaining

The current skill MUST invoke the referenced skill as the next step. Found in `writing-plans` and `executing-plans`:

```markdown
> **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task.
```

### 2. REQUIRED BACKGROUND — Prerequisite Knowledge

The agent must understand the referenced skill before using the current one. Found in `writing-skills`:

```markdown
**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development
before you can write or modify skills.
```

### 3. Integration Section — Explicit "Called by" / "Pairs with"

Structured documentation of how skills connect. Found in `subagent-driven-development`, `executing-plans`, `finishing-a-development-branch`, `using-git-worktrees`:

```markdown
## Integration
**Required workflow skills:**
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace
**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
**Pairs with:**
- **using-git-worktrees** - Cleans up worktree created by that skill
```

### 4. Escalation/Fallback — Conditional Handoff

Conditional upgrade to a more capable skill. Found in `executing-plans`:

```markdown
If subagents are available, use superpowers:subagent-driven-development
instead of this skill.
```

## Subagent Dispatch Model

`subagent-driven-development` is the most sophisticated orchestration skill. Its dispatch model:

### Per-Task Cycle

```
For each task in plan:
  1. Dispatch implementer subagent (with full task text + context)
     │  ├─ DONE → proceed to review
     │  ├─ DONE_WITH_CONCERNS → review concerns, decide
     │  ├─ NEEDS_CONTEXT → provide context, re-dispatch
     │  └─ BLOCKED → escalate to user
     ▼
  2. Dispatch spec reviewer subagent
     │  ├─ PASS → proceed to code quality review
     │  └─ FAIL → fix issues, re-review (loop)
     ▼
  3. Dispatch code quality reviewer subagent
     │  ├─ PASS → mark task complete
     │  └─ FAIL → fix issues, re-review (loop)
     ▼
  4. Mark task complete in TodoWrite
```

### After All Tasks

```
5. Dispatch final code reviewer for entire implementation
6. Invoke finishing-a-development-branch
```

### Model Selection Guidance

```
Mechanical tasks (isolated functions, 1-2 files)     → fast, cheap model
Integration tasks (multi-file coordination, debugging) → standard model
Architecture, design, review tasks                     → most capable model
```

### Critical Rules

- **NEVER** dispatch multiple implementation subagents in parallel (conflict risk)
- **NEVER** skip either review stage (spec compliance MUST pass before code quality begins)
- **NEVER** make subagent read the plan file (provide full task text in prompt)
- **ALWAYS** include scene-setting context for each subagent

## Terminal States

Each pipeline branch has a clear terminal state:

| Skill | Terminal Action |
|-------|----------------|
| `brainstorming` | Invoke `writing-plans` — "The ONLY skill you invoke after brainstorming" |
| `writing-plans` | Invoke `subagent-driven-development` or `executing-plans` |
| `subagent-driven-development` | Invoke `finishing-a-development-branch` |
| `executing-plans` | Invoke `finishing-a-development-branch` |
| `finishing-a-development-branch` | Worktree cleanup — end of pipeline |

## Hard Gates (Points Where Workflow Must Stop)

| Gate | Skill | What Stops |
|------|-------|-----------|
| Design approval | `brainstorming` | No implementation until user approves design |
| Plan approval | `writing-plans` | No execution until plan is reviewed |
| Tests pass | `finishing-a-development-branch` | No merge/PR if tests failing |
| Verification evidence | `verification-before-completion` | No completion claims without fresh test output |
| Root cause found | `systematic-debugging` | No fix attempts without investigation |
| Spec review passes | `subagent-driven-development` | No code quality review until spec compliance confirmed |

## Observations and Gaps

### Under-Connected Skills

1. **`verification-before-completion`** is referenced only by `systematic-debugging` but not by `finishing-a-development-branch` or `subagent-driven-development`. One would expect completion verification to be mandatory at those points too. This may be intentional (the skill is meant to be internalized behaviour) or a gap.

2. **`receiving-code-review`** is orphaned — no other skill explicitly chains to it. It's invoked only when the agent receives external feedback.

### No Plan Update Skill

There is no skill for updating a plan mid-execution when implementation reveals design issues. The current guidance is to "stop and ask."

### No Machine-Readable Dependencies

All orchestration is through prose instructions. The agent must parse natural language to determine which skill to invoke next. This is by design but means orchestration reliability depends on agent reading comprehension.

---

**Next:** [03-skills-reference.md](./03-skills-reference.md) — Complete skill-by-skill reference with full details
