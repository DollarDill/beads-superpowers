# Agent Instructions

This project is a **Claude Code plugin** (beads-superpowers). It provides 22 skills for AI coding agents with integrated beads issue tracking.

## Beads Issue Tracking

This project uses **bd (beads)** for ALL issue tracking. Issues sync to GitHub Issues via `bd github push`.

- **GitHub Issues:** <https://github.com/DollarDill/beads-superpowers/issues>
- **Issue tracker:** `bd` CLI (beads) with GitHub sync
- Do NOT use TodoWrite, TaskCreate, or markdown TODO lists

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id> --reason "description"  # Complete work
bd github push        # Sync beads to GitHub Issues
bd dolt push          # Sync beads to Dolt remote
```

## For Plugin Development

When modifying skills in this repo:

- Skills are plain Markdown in `skills/<name>/SKILL.md`
- All task tracking uses `bd` commands — never TodoWrite
- Test changes by verifying `grep -r "TodoWrite" skills/` returns only prohibition references
- The SessionStart hook at `hooks/session-start` injects `using-superpowers` + `bd prime`
- Subagent review prompts (spec-reviewer, code-quality-reviewer) are NOT beads-aware — orchestrator only. Exception: `implementer-prompt.md` and `researcher-prompt.md` ARE beads-aware (include skill invocations, bead lifecycle, LSP instructions).
- Subagent prompt templates live inside their respective skills: `skills/subagent-driven-development/implementer-prompt.md`, `skills/research-driven-development/researcher-prompt.md`. Skills own their dispatch prompts — no standalone agent files for subagents.
- Run the Quick Audit before releasing: see `skills/auditing-upstream-drift/SKILL.md`

## Tests

```bash
# Brainstorm server (25+31 tests, fast, free)
cd tests/brainstorm-server && npm test && node ws-protocol.test.js

# Claude Code skill tests (9 subtests, ~$0.10, ~165s)
bash tests/claude-code/run-skill-tests.sh --timeout 600

# Integration test (optional, ~$4-5, 10-30 min)
bash tests/claude-code/run-skill-tests.sh --integration --timeout 2400
```

## Session Close (Land the Plane)

Work is NOT complete until `git push` succeeds:

```bash
bd close <completed-ids> --reason "description"
bd github push
bd dolt push
git pull --rebase && git push
git status  # MUST show "up to date with origin"
```
