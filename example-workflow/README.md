# Example Workflow

This directory contains a ready-to-use development workflow for projects using [beads-superpowers](https://github.com/DollarDill/beads-superpowers).

## Architecture

| Layer | File | Purpose |
|-------|------|---------|
| Behavioral rules | `CLAUDE.md` | Karpathy's 4 principles + beads integration — loaded for all agents |
| Orchestration | `agents/yegge.md` | Lean router — triages requests and routes to skills; primary session agent |

Subagents (researcher, implementer, code-reviewer) are dispatched via **prompt templates** within their skills — no separate agent files needed; the skills own the prompts, keeping them in sync.

### Naming

- **yegge** (orchestrator) — Named after Steve Yegge, creator of [Beads](https://github.com/gastownhall/beads)

## Quick Setup

The yegge agent is an optional add-on — install it globally with `install.sh --with-yegge` (not installed by default). To add the CLAUDE.md template to your project:

```bash
# Copy the Karpathy + beads CLAUDE.md template
cp example-workflow/CLAUDE.md /path/to/your-project/CLAUDE.md

# Then customize: add your project architecture, conventions, and gotchas
```

## How It Works

The `yegge` agent triages each request and routes it to the skills that own the work — it doesn't hard-code a state machine. For non-trivial work it runs the full flow, one skill per step:

```text
Research    → research-driven-development      (skip if already understood)
Brainstorm  → brainstorming                    (spec + approval gate)
Plan        → writing-plans                    (task plan + approval gate)
Implement   → using-git-worktrees + test-driven-development / subagent-driven-development
Verify      → verification-before-completion   (evidence before "done")
Document    → document-release
Finish      → finishing-a-development-branch   (owns Land-the-Plane)
```

Trivial edits skip the heavyweight ceremony (worktree / doc audit / PR) but still require verification; quick questions are answered directly. See `agents/yegge.md` for the triage table and full skill index.

The `CLAUDE.md` provides behavioral guardrails (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) plus beads integration context. `bd prime` injects dynamic beads state at session start.

## Customization

- **Add project context** — Edit CLAUDE.md to add your architecture overview, conventions, and gotchas after the behavioral guidelines
- **Adjust models** — yegge uses `model: inherit` (your session model). The researcher prompt template dispatches a `general-purpose` subagent, not the built-in `researcher` type, whose own system prompt would override the template.
- **Add project rules** — The Karpathy section explicitly says "Merge with project-specific instructions as needed"

## Learn More

- [Example Workflow docs](https://dollardill.github.io/beads-superpowers/workflow.html) — Full walkthrough with diagrams
- [Skills Reference](https://dollardill.github.io/beads-superpowers/skills.html) — All skills explained
- [Methodology](https://dollardill.github.io/beads-superpowers/methodology.html) — Why this workflow exists
