<!-- Based on https://github.com/forrestchang/andrej-karpathy-skills (MIT License) -->

# beads-superpowers — Claude Code Plugin

Behavioral guidelines to reduce common LLM coding mistakes, plus project-specific instructions.

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

```text
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Project Overview

A Claude Code marketplace plugin that merges [Superpowers](https://github.com/obra/superpowers) skills (v5.0.7) with [Beads](https://github.com/gastownhall/beads) issue tracking (v1.0.2). It gives AI coding agents 22 composable process-discipline skills (TDD, brainstorming, systematic debugging, two-stage code review, verification) plus persistent task memory via a Dolt-backed database.

**Repository:** <https://github.com/DollarDill/beads-superpowers>
**Version:** 0.5.3
**License:** MIT (fork of obra/superpowers, also MIT)

## Architecture

- `.claude-plugin/` — Plugin manifest (`plugin.json`) and marketplace config (`marketplace.json`). Claude Code auto-discovers these.
- `skills/` — 22 skills, each in `skills/<name>/SKILL.md`. Some include prompt templates (`implementer-prompt.md`, `researcher-prompt.md`) or helper scripts. Auto-discovered by Claude Code — do NOT declare in `plugin.json`.
- `agents/` — `code-reviewer.md` agent. Auto-discovered. Subagents (implementer, researcher) use prompt templates inside their skills, not standalone agent files.
- `hooks/` — `session-start` (injects `using-superpowers` + `bd prime`) and `superpowers-reminder.sh` (UserPromptSubmit skill trigger reminders). Registered in `hooks/hooks.json`. Auto-discovered.
- `example-workflow/` — Ready-to-use project template: `CLAUDE.md` (Karpathy behavioral principles + beads integration) and `agents/yegge.md` (11-state FSM orchestrator). `install.sh` copies `yegge.md` globally.
- `docs/` — MkDocs Material source pages (6 pages + assets). Template variables (`{{ skill_count }}`) computed at build time via `main.py` macros plugin. Contains ONLY website content.
- `decisions/` — Architecture Decision Records (ADRs). Local working docs (gitignored).
- `.internal/` — Working docs (gitignored): specs from brainstorming, plans from writing-plans, research output, audits, reference docs.
- `tests/` — 6 test suites: brainstorm-server (Node.js), claude-code skill tests, explicit-skill-requests, installer (Docker E2E), skill-triggering, subagent-driven-dev.
- `scripts/` — `bump-version.sh` (sync version across 3 files), `sync-skill-count.sh` (sync skill counts across all files), `build-docs.sh`.
- `install.sh` — curl installer. Installs plugin + yegge agent globally.
- `mkdocs.yml` + `main.py` — MkDocs Material site config and macros plugin.

## Key Design Decisions

- **Skills are pure Markdown** — No executable code in skills. Claude Code auto-discovers `skills/*/SKILL.md`. Platform-agnostic by design. (See: upstream superpowers architecture)
- **Prompt templates over standalone agent files** — Subagent prompts (`implementer-prompt.md`, `researcher-prompt.md`) live inside their skills. Only the orchestrator (`yegge.md`) is a standalone agent file. Prevents drift between skill and dispatch instructions. (See: ADR-0003)
- **`bd` replaces TodoWrite everywhere** — Every `TodoWrite` reference in upstream superpowers replaced with `bd` commands. Beads provides persistent cross-session memory that TodoWrite lacks.
- **Three-layer architecture for example workflow** — `CLAUDE.md` (behavioral principles + project context) + `agents/yegge.md` (FSM orchestration) + prompt templates (subagent dispatch). Each layer has a distinct responsibility. (See: ADR-0003)
- **MkDocs Material for docs site** — HashiCorp/Terraform-style sidebar, dark theme, Mermaid diagrams. Template variables via macros plugin avoid hardcoded counts. (See: ADR-0001)
- **Per-task worktree isolation for parallel SDD** — Independent plan tasks execute in parallel (max 5), each in its own `bd worktree`. Prevents merge conflicts between concurrent subagents. (See: ADR-0002)

## Common Gotchas

- **Embedded Dolt mode** — This project uses embedded Dolt (`.beads/metadata.json` `dolt_mode: embedded`). `bd dolt push/pull/status/show` all fail. No remote configured.
- **`export.git-add` pollutes branches** — `bd config set export.git-add false` BEFORE starting branch work. Default is `true`, which auto-stages `issues.jsonl` on every commit.
- **DCI only works in SKILL.md** — The `!` backtick syntax (Dynamic Context Injection) only works in `SKILL.md` and `.claude/commands/*.md`. NOT in agent `.md` files, `CLAUDE.md`, or rules files.
- **Never run `npx skills add` from inside this repo** — It replaces real skill files in `skills/` with symlinks to `.agents/skills/`, destroying the source. Use `-g` flag from `/tmp` or another directory.
- **Never chain `open` after `bd` commands** — `open <file>` hangs when chained in the same Bash invocation with `bd` commands. Always run `open` as a standalone call.
- **Worktree path default** — `bd worktree create <name>` creates at `./<name>` (sibling to repo files), NOT `.worktrees/<name>`. Pass the full path: `bd worktree create .worktrees/<name>`.
- **Worktree detection** — Use `git rev-parse --is-inside-work-tree`, NOT `[ -d .git ]`. In a worktree, `.git` is a file, not a directory.
- **Plugin cache goes stale** — After modifying skills, the installed plugin cache is outdated. Symlink the cache to this repo (see "Syncing Source" section below). `claude plugin update` has a [cache bug](https://github.com/anthropics/claude-code/issues/14061).
- **Skill `description` field trap** — Putting workflow descriptions in skill `description` frontmatter causes Claude to follow the description instead of reading the full skill body (CSO problem). Descriptions should state trigger conditions only.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging:

```bash
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

## Plugin Structure

```text
.claude-plugin/
  plugin.json              # Plugin manifest (auto-discovered by Claude Code)
  marketplace.json         # Marketplace config for plugin discovery
agents/                    # Code reviewer agent (auto-discovered)
assets/                    # Banner SVG
docs/                      # MkDocs source pages — website content ONLY
  index.md, getting-started.md, methodology.md, skills.md, workflow.md, tips.md
  assets/                  # Banner SVG
decisions/                 # Architecture Decision Records (gitignored, local-only)
.internal/                 # Working docs (gitignored)
  specs/                   # Design specs from brainstorming
  plans/                   # Implementation plans from writing-plans
  research/                # Research output from research-driven-development
  audits/                  # Upstream drift audit reports
  reference/               # Upstream design docs
  windows/                 # Windows polyglot hook docs
  SETUP-GUIDE.md           # Installation and setup guide
  testing.md               # Test infrastructure docs
example-workflow/
  CLAUDE.md                # Karpathy behavioral principles + beads integration (generic project template)
  agents/yegge.md          # Orchestrator agent — 11-state FSM lifecycle
hooks/
  hooks.json               # SessionStart + UserPromptSubmit hook registration
  session-start            # Bash: injects using-superpowers + runs bd prime
  superpowers-reminder.sh  # UserPromptSubmit: injects skill trigger reminders
  run-hook.cmd             # Windows polyglot wrapper
scripts/
  bump-version.sh          # Sync version across package.json + plugin manifests
  sync-skill-count.sh      # Sync skill counts across all files (idempotent)
  build-docs.sh            # Build MkDocs site
skills/                    # 22 beads-native skills (auto-discovered, each has SKILL.md)
tests/                     # Test infrastructure (6 suites)
install.sh                 # curl installer (installs plugin + yegge agent globally)
mkdocs.yml                 # MkDocs Material site config
```

**Important:** Claude Code auto-discovers `skills/`, `agents/`, and `hooks/` directories by convention. Do NOT declare these paths in `plugin.json` — it causes validation failures.

## Beads Integration

This plugin uses `bd` (beads) for ALL task tracking.

### Commands Used in Skills

| Action | Command |
|--------|---------|
| Create epic | `bd create "Epic: name" -t epic -p 2` |
| Create task | `bd create "Task: title" -t task --parent <epic-id>` |
| Quick capture | `bd q "title"` |
| Claim work | `bd update <id> --claim` |
| Complete work | `bd close <id> --reason "description"` |
| Check remaining | `bd ready --parent <epic-id>` |
| Show blocked | `bd blocked` |
| Epic status | `bd epic status <id>` |
| Add dependency | `bd dep add <child> <depends-on>` |
| Store learning | `bd remember "insight"` |
| Remove stale memory | `bd forget <id>` |
| Search memories | `bd memories <keyword>` |
| Append note to bead | `bd note <id> "context"` |
| Find duplicate beads | `bd find-duplicates` |
| PR readiness | `bd preflight` |
| Sync beads | `bd dolt push` |
| Sync to GitHub Issues | `bd github push` |

### Rules

- Use `bd` for ALL task tracking — never TodoWrite, TaskCreate, or markdown TODOs
- Only the orchestrating agent manages beads — subagents do NOT touch beads
- Include bead IDs in commit messages: `git commit -m "Add feature (bd-a1b2)"`
- Every session ends with Land the Plane: `bd close` → `bd dolt push` → `git push`

### GitHub Issue Sync

This project syncs beads to GitHub Issues. Issues appear at <https://github.com/DollarDill/beads-superpowers/issues>.

```bash
bd github push              # Push beads to GitHub Issues
bd github pull              # Pull GitHub Issues into beads
bd github status            # Check sync configuration
```

GitHub sync is configured via:

- `bd config set github.token <token>` (or `GITHUB_TOKEN` env var)
- `bd config set github.repository DollarDill/beads-superpowers`

### Duplicate Hook Detection

If `bd setup claude` hooks are installed in any settings file (project or global), the plugin's session-start hook detects them and automatically skips its own `bd prime` call to avoid duplicate context injection. No manual intervention needed.

## Skills (22 Total)

| Skill | Purpose |
|-------|---------|
| using-superpowers | Bootstrap — loaded at session start, routes to other skills |
| setup | Post-npx hook installation — configures SessionStart hook |
| brainstorming | Socratic design before code — creates session beads |
| stress-test | Adversarial design interrogation with recommended answers |
| writing-plans | Bite-sized task plans — each task becomes a bead |
| subagent-driven-development | Fresh agent per task + two-stage review; parallel batch mode for independent tasks |
| executing-plans | Batch execution in single session |
| test-driven-development | RED-GREEN-REFACTOR — Iron Law: no code without failing test |
| systematic-debugging | 4-phase root cause analysis before proposing fixes |
| verification-before-completion | Evidence before claims — bd close requires evidence |
| requesting-code-review | Dispatches code reviewer subagent |
| receiving-code-review | Anti-sycophancy review reception |
| using-git-worktrees | Isolated development branches |
| finishing-a-development-branch | Merge/PR + Land the Plane (Step 6) |
| document-release | Post-ship documentation audit and sync |
| project-init | Beads/Dolt DB setup, bootstrap, and recovery |
| dispatching-parallel-agents | 2+ independent tasks without shared state |
| writing-skills | Meta-skill for creating/modifying skills |
| auditing-upstream-drift | Detect staleness vs upstream superpowers/beads |
| getting-up-to-speed | Session orientation — bd context + adaptive codebase deep-dive + structured current-state summary |
| research-driven-development | Parallel research agents → synthesized knowledge base document. Triggers on "research this", "what is X", "how does Y work" |
| write-documentation | Human-quality prose for all human-facing text — 14-rule writing system with context-first drafting and required checks |

## Modifying Skills

### Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter:

   ```yaml
   ---
   name: skill-name
   description: When to use this skill (trigger condition, not workflow summary)
   ---
   ```

2. Make it beads-aware: use `bd create`/`bd close`/`bd ready` for task tracking
3. If it has a checklist, create beads per checklist item
4. Update CLAUDE.md skills table (count and row) and CHANGELOG.md

### Modifying an Existing Skill

1. **Do NOT remove** anti-rationalization tables, Iron Laws, or Red Flags sections
2. **Do NOT add** TodoWrite references — use `bd` commands
3. **Do NOT modify** subagent review prompts (spec-reviewer, code-quality-reviewer) with beads commands — orchestrator only. Exception: `implementer-prompt.md` IS beads-aware by design (includes skill invocations, bead lifecycle, LSP instructions).
4. Verify after changes: `grep -r "TodoWrite" skills/ | grep -v "Do NOT use" | grep -v "replaces"` — must return empty

### Key Anti-Patterns

- Putting workflow descriptions in skill `description` fields (causes Claude to follow description instead of reading full skill — see CSO in METHODOLOGY.md)
- Softening bright-line rules ("consider" instead of "MUST")
- Adding platform-specific code to skills (skills are pure Markdown)

## Build & Test

Skills are plain Markdown. The docs site uses MkDocs Material.

### Validation

```bash
# Validate plugin manifests
claude plugin validate .claude-plugin/plugin.json

# Sync skill counts across all files (idempotent)
./scripts/sync-skill-count.sh

# Verify skill counts are consistent
./scripts/sync-skill-count.sh --check

# Verify zero active TodoWrite references
grep -r "TodoWrite" skills/ | grep -v "Do NOT use TodoWrite" | grep -v "replaces TodoWrite"

# Verify beads integration (should be 30+)
grep -r "bd create\|bd close\|bd ready" skills/ | wc -l

# Test hook output
bash hooks/session-start 2>&1 | python3 -m json.tool

# Build docs site locally
pip install mkdocs-material mkdocs-macros-plugin  # one-time
mkdocs build --strict                              # build
mkdocs serve                                       # preview at http://localhost:8000
```

### Running Skill Tests

```bash
# Fast tests (skill content verification, ~2 min)
cd tests/claude-code && ./run-skill-tests.sh

# Integration tests (full workflow execution, 10-30 min)
cd tests/claude-code && ./run-skill-tests.sh --integration
```

### Running Installer E2E Test

```bash
# Requires Docker. Tests install/re-install/uninstall in a clean container.
./tests/installer/run-tests.sh
```

## Version Management

Version is declared in 3 files that must stay in sync:

- `package.json`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

Use `scripts/bump-version.sh` to update all at once:

```bash
./scripts/bump-version.sh 0.5.3        # Bump to new version
./scripts/bump-version.sh --check      # Detect version drift
```

## Installation (for users, not contributors)

```bash
# Option A: Marketplace
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace

# Option B: curl (one command, no dependencies)
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

## Example Workflow

The `example-workflow/` directory provides a ready-to-use development workflow:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Karpathy's 4 behavioral principles + beads integration (generic template for any project) |
| `agents/yegge.md` | Complete orchestrator agent — 11-state FSM, triage, planning, rules, session protocol. Named after Steve Yegge (beads creator). Installed globally by `install.sh`. |

Subagents (researcher, implementer, code-reviewer) are dispatched via **prompt templates** within their skills — no standalone agent files. The `researcher-prompt.md` is named after Jesse Vincent (superpowers creator).

## Syncing Source to Installed Plugin

After modifying skills, the installed plugin cache at `~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.3/` goes stale.

**Recommended:** Symlink the cache to this repo (one-time, survives edits):

```bash
rm -rf ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.3
ln -s ~/workplace/beads-superpowers \
  ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.3
```

**Quick check for drift:** `diff -rq skills/ ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.3/skills/`

**Note:** `claude plugin update` has a [cache bug](https://github.com/anthropics/claude-code/issues/14061) — use symlink instead.

## Upstream Sources

| Source | Version | What We Track |
|--------|---------|---------------|
| [obra/superpowers](https://github.com/obra/superpowers) | v5.0.7 (baseline) | Skill content, new skills, hook changes |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.0.2 (baseline) | CLI commands, new features, bd prime format |

Use the `auditing-upstream-drift` skill to check for staleness.
