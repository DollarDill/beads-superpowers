# Agent Instructions

This project is a **Claude Code plugin** (beads-superpowers). It provides 15 skills for AI coding agents with integrated beads issue tracking.

## Beads Issue Tracking

This project uses **bd (beads)** for ALL issue tracking. Issues sync to GitHub Issues via `bd github sync`.

- **GitHub Issues:** https://github.com/DollarDill/beads-superpowers/issues
- **Issue tracker:** `bd` CLI (beads) with GitHub sync
- Do NOT use TodoWrite, TaskCreate, or markdown TODO lists

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id> --reason "description"  # Complete work
bd github sync        # Sync beads to GitHub Issues
bd dolt push          # Sync beads to Dolt remote
```

## For Plugin Development

When modifying skills in this repo:

- Skills are plain Markdown in `skills/<name>/SKILL.md`
- All task tracking uses `bd` commands — never TodoWrite
- Test changes by verifying `grep -r "TodoWrite" skills/` returns only prohibition references
- The SessionStart hook at `hooks/session-start` injects `using-superpowers` + `bd prime`
- Subagent prompt files are NOT beads-aware (orchestrator-only design)
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
bd github sync
bd dolt push
git pull --rebase && git push
git status  # MUST show "up to date with origin"
```

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
