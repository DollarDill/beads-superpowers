# Agent Instructions

This project is a **Claude Code plugin** (beads-superpowers). It provides 14 skills for AI coding agents with integrated beads issue tracking.

## For Plugin Development

When modifying skills in this repo:

- Skills are plain Markdown in `skills/<name>/SKILL.md`
- All task tracking uses `bd` commands — never TodoWrite
- Test changes by verifying `grep -r "TodoWrite" skills/` returns only prohibition references
- The SessionStart hook at `hooks/session-start` injects `using-superpowers` + `bd prime`
- Subagent prompt files are NOT beads-aware (orchestrator-only design)

## Beads Workflow

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id> --reason "description"  # Complete work
bd dolt push          # Sync beads to remote
```

## Session Close (Land the Plane)

Work is NOT complete until `git push` succeeds:

```bash
bd close <completed-ids> --reason "description"
bd dolt push
git pull --rebase && git push
git status  # MUST show "up to date with origin"
```
