# Example Workflow — beads-superpowers Development Lifecycle

> **This is an example CLAUDE.md** demonstrating how beads-superpowers skills orchestrate a complete professional development workflow. Copy this into your project's `CLAUDE.md` and adapt the paths and conventions to your codebase.
>
> **Requires:** [beads-superpowers](https://github.com/DollarDill/beads-superpowers) plugin installed + `bd` CLI initialized in your project.

## Request Triage

Not every request needs the full workflow. Triage incoming requests:

| Request Type | Examples | Path | Beads |
|---|---|---|---|
| **Quick question** | "What does this file do?", "Explain this error" | Answer directly | No bead |
| **Simple task** | "Fix this typo", "Rename this variable" | S1 → S7 → S8 → S9 → S10 → S11 | Quick bead: create → claim → do → close |
| **Non-trivial task** | "Add a new feature", "Refactor this module" | S1 → S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9 → S10 → S11 | Epic + child beads with dependencies |
| **Research query** | "What is X?", "How does Y work?" | S1 → S2 → S3 → S11 | Single bead |

**Routing principle:** Every task that changes code gets the quality pipeline (S7-S11: worktree → TDD → verify → docs → finish → push). Complexity scales the *research and planning* depth (S2-S6), not the quality gates.

**Every task that changes files gets a bead**, regardless of size.

## Development Lifecycle — 11-State Finite State Machine

Each state has a mandatory skill invocation, a guard condition that must pass before transitioning, and an explicit failure path. **No state can be skipped.**

| State | Action | Guard (Exit Criterion) | On Failure |
|-------|--------|----------------------|------------|
| **S1: SETUP** | `bd create` → `bd update --claim` | Bead exists and claimed | Retry bd commands |
| **S2: RESEARCH** | Dispatch `@researcher` (web + KB) + `@explore` (codebase) in parallel | Both agents return structured findings | Proceed with one if the other fails |
| **S3: KNOWLEDGE CAPTURE** | Synthesize research → write findings to knowledge base → commit | Document written | Present findings inline and continue |
| **S4: BRAINSTORM** | Invoke `Skill(beads-superpowers:brainstorming)` | Design doc written; user approved | Loop — revise until user approves |
| **S5: DECISION CAPTURE** | Write Architecture Decision Record | ADR written | Non-blocking — warn and continue |
| **S6: PLAN** | Invoke `Skill(beads-superpowers:writing-plans)` | Plan exists; beads created; user approved | Loop — revise until user approves |
| **S7: IMPLEMENT** | Invoke `Skill(beads-superpowers:using-git-worktrees)` then `Skill(beads-superpowers:test-driven-development)` or `Skill(beads-superpowers:subagent-driven-development)` | All task beads closed, tests pass | Sub-agent fails → review gate → fix or re-delegate |
| **S8: VERIFY** | Invoke `Skill(beads-superpowers:verification-before-completion)` | Fresh test run passes, evidence in output | → S7 (re-implement) or escalate |
| **S9: DOCUMENT** | Invoke `Skill(document-release)` | Docs audited and updated | Non-blocking — warn if update fails |
| **S10: CLOSE BRANCH** | Invoke `Skill(beads-superpowers:finishing-a-development-branch)` | Branch merged/PR created | Retry merge; keep worktree if conflicts |
| **S11: LAND THE PLANE** | `bd close` → `bd dolt push` → `git push` → `git status` | Git status shows "up to date with origin" | Retry push; NEVER stop before pushed |

### Path Summary

```
Non-trivial:  S1 → S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9 → S10 → S11
Simple task:  S1 → S7 → S8 → S9 → S10 → S11
Research:     S1 → S2 → S3 → S11
Question:     Answer directly (no FSM)
```

## Interrupt States

These can fire at ANY point, interrupting the current state and returning to it after resolution:

| Interrupt | Trigger | Skill | Behaviour |
|-----------|---------|-------|-----------|
| **DEBUG** | Bug, test failure, unexpected behaviour | `Skill(beads-superpowers:systematic-debugging)` | 4-phase root cause investigation → return to interrupted state |
| **CODE REVIEW** | Review feedback received | `Skill(beads-superpowers:receiving-code-review)` | Technical verification → implement or push back → return |

## Sub-Agent Review Gate (S7)

When S7 delegates to `@implementer`:

1. **Isolate in a worktree** — `Skill(beads-superpowers:using-git-worktrees)` BEFORE delegating
2. **Review before accepting** — After sub-agent reports completion:
   - Run the full test suite independently — do NOT trust the sub-agent's test run
   - Check the diff for unrelated changes, debug artifacts, or scope creep
   - Invoke `Skill(beads-superpowers:requesting-code-review)` for spec compliance
   - Verify acceptance criteria from the plan are actually met
3. **Reject if quality gates fail** — DO NOT merge
4. **Merge only after ALL gates pass**

## Research Workflow (S2-S3)

When handling research queries or the research phase of non-trivial tasks:

1. **Create a bead** — `bd create "Research: <topic>" -t task`
2. **Check existing knowledge first** — Search `bd memories <keyword>` and your knowledge base
3. **Dispatch researcher agent** — `@researcher` runs web searches, fetches primary sources, cross-references findings
4. **Dispatch explore agent** — `@explore` searches the codebase for relevant patterns, implementations, prior art
5. **Synthesize findings** — Combine both agents' output into a structured document
6. **Write to knowledge base** — Save to your project's research directory (e.g., `docs/research/`)
7. **Close the bead** — `bd close <id> --reason "Research complete: <summary>"`

Research documents should follow this structure:

```markdown
# Research: [Topic]

## Summary
[2-3 sentence overview]

## Key Findings
### [Finding 1]
[Details with specific facts, commands, numbers]

## Open Questions
[Anything unresolved]

## Sources
- [Source](URL) — [What was extracted]
```

## Planning Principles

1. **Be skeptical of your own plan** — Actively look for gaps and wrong assumptions
2. **Each phase must be independently testable** — Never combine unrelated changes
3. **Smallest viable phases** — Prefer more small phases over fewer large ones
4. **Include rollback** — Note how to undo each phase if something goes wrong
5. **Concrete over abstract** — Specify exact file paths, commands, and config values
6. **No placeholders** — Forbidden: "TBD", "TODO", generic instructions, vague references

## Critical Rules

1. **NEVER skip an FSM state** — Every guard must pass before transitioning
2. **NEVER skip Research (S2-S3)** — Even if you think you know the answer, verify it
3. **NEVER skip Planning (S4-S6)** — Brainstorm and plan before coding
4. **NEVER implement without user plan approval** — Wait for confirmation
5. **NEVER deviate from the plan without escalating** — Explain why and propose revision
6. **NEVER make unrelated changes** — Stay focused on the task
7. **NEVER skip verification (S8)** — Evidence before claims, always

## Session Protocol

### Session Start
1. beads-superpowers plugin injects `bd prime` context automatically
2. `bd ready` — find unblocked work
3. Claim: `bd update <id> --claim`

### Session End
Work is NOT complete until `git push` succeeds:

```bash
bd close <completed-ids> --reason "description"
bd dolt push                    # Sync beads to remote
git pull --rebase && git push   # Sync code to remote
git status                      # Verify clean state
```

## Beads Commands Quick Reference

| Action | Command |
|--------|---------|
| Create epic | `bd create "Epic: name" -t epic -p 2` |
| Create task | `bd create "Task: title" -t task --parent <epic-id>` |
| Quick capture | `bd q "title"` |
| Claim work | `bd update <id> --claim` |
| Complete work | `bd close <id> --reason "description"` |
| Check remaining | `bd ready --parent <epic-id>` |
| Show blocked | `bd blocked` |
| Add dependency | `bd dep add <child> <depends-on>` |
| Store learning | `bd remember "insight"` |
| Sync beads | `bd dolt push` |

## Agent Configuration

This workflow uses two companion agents. Place these in your project's `.claude/agents/` directory:

- **`researcher.md`** — Deep research specialist (Opus model, read-only). Searches web + knowledge base, cross-references sources, produces structured findings.
- **`implementer.md`** — Disciplined implementation specialist (Sonnet model). Executes plans phase-by-phase with TDD, verifies each phase, escalates deviations.

See the `example-workflow/agents/` directory for ready-to-use agent configurations.
