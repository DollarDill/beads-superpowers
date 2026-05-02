<!-- Based on https://github.com/forrestchang/andrej-karpathy-skills (MIT License) -->

# Agent Instructions

Behavioral guidelines to reduce common LLM coding mistakes when working on this project.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Project Overview

This project is a **Claude Code marketplace plugin** (beads-superpowers) that merges [Superpowers](https://github.com/obra/superpowers) skills with [Beads](https://github.com/gastownhall/beads) issue tracking. It provides 22 skills for AI coding agents with persistent task memory via a Dolt-backed database.

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

## Common Gotchas

- **Embedded Dolt mode** — `bd dolt push/pull/status/show` all fail. No remote configured.
- **`export.git-add` pollutes branches** — Set `bd config set export.git-add false` before branch work.
- **DCI only works in SKILL.md** — `!` backtick syntax does NOT work in agent `.md` files, `CLAUDE.md`, or rules files.
- **Never run `npx skills add` from inside this repo** — Destroys skill files with symlinks. Use `-g` from `/tmp`.
- **Never chain `open` after `bd` commands** — Hangs. Run `open` as a standalone Bash call.
- **Worktree path default** — `bd worktree create <name>` creates at `./<name>`, not `.worktrees/<name>`. Pass full path.
- **Skill `description` field trap** — Put trigger conditions in `description`, not workflow summaries.

## Tests

```bash
# Brainstorm server (25+31 tests, fast, free)
cd tests/brainstorm-server && npm test && node ws-protocol.test.js

# Claude Code skill tests (9 subtests, ~$0.10, ~165s)
bash tests/claude-code/run-skill-tests.sh --timeout 600

# Integration test (optional, ~$4-5, 10-30 min)
bash tests/claude-code/run-skill-tests.sh --integration --timeout 2400
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging:

```bash
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file
rm -rf directory            # NOT: rm -r directory
```

## Session Close (Land the Plane)

Work is NOT complete until `git push` succeeds:

```bash
bd close <completed-ids> --reason "description"
bd github push
git pull --rebase && git push
git status  # MUST show "up to date with origin"
```
