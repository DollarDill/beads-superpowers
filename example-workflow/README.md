# Example Workflow

This directory contains a ready-to-use development workflow for projects using [beads-superpowers](https://github.com/DollarDill/beads-superpowers).

## Architecture

| Layer | File | Purpose |
|-------|------|---------|
| Behavioral rules | `CLAUDE.md` | Karpathy's 4 principles + beads integration — loaded for all agents |
| Orchestration | `agents/yegge.md` | Complete 11-state FSM development lifecycle — primary session agent |

Subagents (researcher, implementer, code-reviewer) are dispatched via **prompt templates** within their respective skills — no separate agent files needed. The skills own the prompts, keeping them in sync.

### Naming

- **yegge** (orchestrator) — Named after Steve Yegge, creator of [Beads](https://github.com/gastownhall/beads)
- **researcher** prompt — Named after Jesse Vincent, creator of [Superpowers](https://github.com/obra/superpowers)

## Quick Setup

The yegge agent is installed globally by `install.sh`. To add the CLAUDE.md template to your project:

```bash
# Copy the Karpathy + beads CLAUDE.md template
cp example-workflow/CLAUDE.md /path/to/your-project/CLAUDE.md

# Then customize: add your project architecture, conventions, and gotchas
```

## How It Works

The `yegge` agent orchestrates an 11-state finite state machine:

```text
S1:  SETUP         → Create and claim a bead
S2:  RESEARCH      → @researcher + @explore in parallel
S3:  KNOWLEDGE     → Synthesize findings → write to knowledge base
S4:  BRAINSTORM    → Skill(brainstorming) → design doc + user approval
S5:  DECIDE        → Write Architecture Decision Record
S6:  PLAN          → Skill(writing-plans) → plan doc + user approval
S7:  IMPLEMENT     → Skill(using-git-worktrees) + Skill(subagent-driven-development)
S8:  VERIFY        → Skill(verification-before-completion) → fresh evidence
S9:  DOCUMENT      → Skill(write-documentation) + Skill(document-release)
S10: CLOSE BRANCH  → Skill(finishing-a-development-branch) → merge/PR
S11: LAND THE PLANE → bd close + bd dolt push + git push

Simple task shortcut:  S1 → S7 → S8 → S9 → S10 → S11
Research query:        S1 → S2 → S3 → S11
```

The `CLAUDE.md` provides behavioral guardrails (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) plus beads integration context. `bd prime` injects dynamic beads state at session start.

## Customization

- **Add project context** — Edit CLAUDE.md to add your architecture overview, conventions, and gotchas after the behavioral guidelines
- **Adjust models** — yegge uses `model: inherit` (your session model). The researcher prompt template defaults to the `researcher` subagent type.
- **Add project rules** — The Karpathy section explicitly says "Merge with project-specific instructions as needed"

## Learn More

- [Example Workflow docs](https://dollardill.github.io/beads-superpowers/workflow.html) — Full walkthrough with diagrams
- [Skills Reference](https://dollardill.github.io/beads-superpowers/skills.html) — All 22 skills explained
- [Methodology](https://dollardill.github.io/beads-superpowers/methodology.html) — Why this workflow exists
