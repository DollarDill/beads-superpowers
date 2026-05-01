# Example Workflow

This directory contains a ready-to-use development workflow configuration for projects using [beads-superpowers](https://github.com/DollarDill/beads-superpowers).

## What's Inside

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Complete development lifecycle instructions — 11-state FSM, request triage, planning principles, critical rules, session protocol |
| `agents/researcher.md` | Deep research specialist agent — searches web + knowledge base, cross-references sources, produces structured findings |
| `agents/implementer.md` | Disciplined implementation agent — executes plans phase-by-phase with TDD, verifies each phase, escalates deviations |

## Quick Setup

```bash
# 1. Copy the CLAUDE.md into your project (or merge with your existing one)
cp example-workflow/CLAUDE.md /path/to/your-project/CLAUDE.md

# 2. Copy the agent configs
mkdir -p /path/to/your-project/.claude/agents
cp example-workflow/agents/*.md /path/to/your-project/.claude/agents/

# 3. Verify
ls /path/to/your-project/.claude/agents/
# Should show: researcher.md  implementer.md
```

## How It Works

The CLAUDE.md defines an 11-state finite state machine that orchestrates beads-superpowers skills into a complete professional development lifecycle:

```
S1:  SETUP         → Create and claim a bead
S2:  RESEARCH      → @researcher + @explore in parallel
S3:  KNOWLEDGE     → Synthesize findings → write to knowledge base
S4:  BRAINSTORM    → Skill(brainstorming) → design doc + user approval
S5:  DECIDE        → Write Architecture Decision Record
S6:  PLAN          → Skill(writing-plans) → plan doc + user approval
S7:  IMPLEMENT     → Skill(using-git-worktrees) + Skill(subagent-driven-development)
S8:  VERIFY        → Skill(verification-before-completion) → fresh evidence
S9:  DOCUMENT      → Skill(document-release) → audit docs
S10: CLOSE BRANCH  → Skill(finishing-a-development-branch) → merge/PR
S11: LAND THE PLANE → bd close + bd dolt push + git push

Simple task shortcut:  S1 → S7 → S8 → S9 → S10 → S11
Research query:        S1 → S2 → S3 → S11
```

The two companion agents (`@researcher` and `@implementer`) are dispatched by the orchestrator at specific FSM states — you never invoke them directly.

## Customization

- **Adapt paths** — The CLAUDE.md references `docs/research/` for knowledge base output. Change this to match your project's structure.
- **Adjust models** — The researcher uses Opus (highest quality) and the implementer uses Sonnet (fastest). Change in the YAML frontmatter if needed.
- **Add project rules** — Merge the FSM instructions with your existing CLAUDE.md project-specific rules.

## Learn More

- [Example Workflow documentation](https://dollardill.github.io/beads-superpowers/workflow.html) — Full walkthrough with diagrams
- [Skills Reference](https://dollardill.github.io/beads-superpowers/skills.html) — All 21 skills explained
- [Methodology](https://dollardill.github.io/beads-superpowers/methodology.html) — Why this workflow exists
