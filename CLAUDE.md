# beads-superpowers — Claude Code Plugin

This project IS a Claude Code marketplace plugin that merges [Superpowers](https://github.com/obra/superpowers) skills (v5.0.7) with [Beads](https://github.com/gastownhall/beads) issue tracking (v1.0.0).

**Repository:** https://github.com/DollarDill/beads-superpowers
**Version:** 0.1.0
**License:** MIT (fork of obra/superpowers, also MIT)

## Project Context

This plugin gives AI coding agents two things simultaneously:
1. **Process discipline** — 15 composable skills enforcing TDD, brainstorming, systematic debugging, two-stage code review, and verification
2. **Persistent memory** — Every task is a bead tracked in a Dolt-backed database that survives across sessions

The key modification from upstream superpowers: every `TodoWrite` reference has been replaced with `bd` (beads) commands. The plugin's SessionStart hook runs `bd prime` to inject beads workflow context alongside skills.

## Plugin Structure

```
.claude-plugin/
  plugin.json              # Plugin manifest (auto-discovered by Claude Code)
  marketplace.json         # Marketplace config for plugin discovery
hooks/
  hooks.json               # SessionStart hook registration
  session-start            # Bash: injects using-superpowers + runs bd prime
  run-hook.cmd             # Windows polyglot wrapper
skills/                    # 15 beads-native skills (auto-discovered)
agents/                    # Code reviewer agent (auto-discovered)
commands/                  # Deprecated slash commands (auto-discovered)
docs/                      # METHODOLOGY.md, SETUP-GUIDE.md, testing.md, etc.
tests/                     # Test infrastructure (5 suites)
scripts/                   # bump-version.sh
```

**Important:** Claude Code auto-discovers `skills/`, `agents/`, `commands/`, and `hooks/` directories by convention. Do NOT declare these paths in `plugin.json` — it causes validation failures.

## Beads Integration

This plugin uses `bd` (beads) for ALL task tracking.

### Commands Used in Skills

| Action | Command |
|--------|---------|
| Create epic | `bd create "Epic: name" -t epic -p 2` |
| Create task | `bd create "Task: title" -t task --parent <epic-id>` |
| Claim work | `bd update <id> --claim` |
| Complete work | `bd close <id> --reason "description"` |
| Check remaining | `bd ready --parent <epic-id>` |
| Add dependency | `bd dep add <child> <depends-on>` |
| Store learning | `bd remember "insight"` |
| Sync beads | `bd dolt push` |
| Sync to GitHub Issues | `bd github sync` |

### Rules

- Use `bd` for ALL task tracking — never TodoWrite, TaskCreate, or markdown TODOs
- Only the orchestrating agent manages beads — subagents do NOT touch beads
- Include bead IDs in commit messages: `git commit -m "Add feature (bd-a1b2)"`
- Every session ends with Land the Plane: `bd close` → `bd dolt push` → `git push`

### GitHub Issue Sync

This project syncs beads to GitHub Issues via `bd github sync`. Issues appear at https://github.com/DollarDill/beads-superpowers/issues.

```bash
bd github sync              # Push all beads to GitHub Issues
bd github status            # Check sync configuration
```

GitHub sync is configured via:
- `bd config set github.token <token>` (or `GITHUB_TOKEN` env var)
- `bd config set github.repository DollarDill/beads-superpowers`

### Duplicate Hook Warning

If `bd setup claude` hooks are installed in `.claude/settings.json`, this plugin detects them and warns. Run `bd setup claude --remove` — the plugin's hook already handles `bd prime`.

## Skills (15 Total)

| Skill | Purpose |
|-------|---------|
| using-superpowers | Bootstrap — loaded at session start, routes to other skills |
| brainstorming | Socratic design before code — creates session beads |
| writing-plans | Bite-sized task plans — each task becomes a bead |
| subagent-driven-development | Fresh agent per task + two-stage review |
| executing-plans | Batch execution in single session |
| test-driven-development | RED-GREEN-REFACTOR — Iron Law: no code without failing test |
| systematic-debugging | 4-phase root cause analysis before proposing fixes |
| verification-before-completion | Evidence before claims — bd close requires evidence |
| requesting-code-review | Dispatches code reviewer subagent |
| receiving-code-review | Anti-sycophancy review reception |
| using-git-worktrees | Isolated development branches |
| finishing-a-development-branch | Merge/PR + Land the Plane (Step 6) |
| dispatching-parallel-agents | 2+ independent tasks without shared state |
| writing-skills | Meta-skill for creating/modifying skills |
| auditing-upstream-drift | Detect staleness vs upstream superpowers/beads |

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
4. Update README.md skills table and CHANGELOG.md

### Modifying an Existing Skill

1. **Do NOT remove** anti-rationalization tables, Iron Laws, or Red Flags sections
2. **Do NOT add** TodoWrite references — use `bd` commands
3. **Do NOT modify** subagent prompts (implementer, spec-reviewer, code-quality-reviewer) with beads commands — orchestrator only
4. Verify after changes: `grep -r "TodoWrite" skills/ | grep -v "Do NOT use" | grep -v "replaces"` — must return empty

### Key Anti-Patterns

- Putting workflow descriptions in skill `description` fields (causes Claude to follow description instead of reading full skill — see CSO in METHODOLOGY.md)
- Softening bright-line rules ("consider" instead of "MUST")
- Adding platform-specific code to skills (skills are pure Markdown)

## Build & Test

No build step — skills are plain Markdown.

### Validation

```bash
# Validate plugin manifests
claude plugin validate .claude-plugin/plugin.json

# Verify skill count (should be 15)
ls -d skills/*/ | wc -l

# Verify zero active TodoWrite references
grep -r "TodoWrite" skills/ | grep -v "Do NOT use TodoWrite" | grep -v "replaces TodoWrite"

# Verify beads integration (should be 30+)
grep -r "bd create\|bd close\|bd ready" skills/ | wc -l

# Test hook output
bash hooks/session-start 2>&1 | python3 -m json.tool
```

### Running Skill Tests

```bash
# Fast tests (skill content verification, ~2 min)
cd tests/claude-code && ./run-skill-tests.sh

# Integration tests (full workflow execution, 10-30 min)
cd tests/claude-code && ./run-skill-tests.sh --integration
```

## Version Management

Version is declared in 3 files that must stay in sync:
- `package.json`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

Use `scripts/bump-version.sh` to update all at once:
```bash
./scripts/bump-version.sh 0.2.0        # Bump to new version
./scripts/bump-version.sh --check      # Detect version drift
```

## Installation (for users, not contributors)

```bash
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

## Upstream Sources

| Source | Version | What We Track |
|--------|---------|---------------|
| [obra/superpowers](https://github.com/obra/superpowers) | v5.0.7 (baseline) | Skill content, new skills, hook changes |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.0.0 (baseline) | CLI commands, new features, bd prime format |

Use the `auditing-upstream-drift` skill to check for staleness.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging:

```bash
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file
rm -rf directory            # NOT: rm -r directory
```
