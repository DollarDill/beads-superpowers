# Tips & Tricks

Beads command cheat sheet, skill selection guide, troubleshooting, and contributor tips.

## Beads Command Cheat Sheet

Quick reference for the `bd` commands used throughout the skills. The orchestrating agent calls these — subagents do not touch beads.

### Finding Work

| Command | What it does |
|---------|-------------|
| `bd ready` | List unclaimed, unblocked beads ready to work |
| `bd ready --parent <epic-id>` | Check remaining tasks inside a specific epic |
| `bd list --status=open` | List all open beads regardless of block status |
| `bd show <id>` | Show full details for a single bead |
| `bd blocked` | Show all beads currently blocked by a dependency |
| `bd epic status <id>` | Show progress summary for an epic and its children |

### Creating Beads

| Command | What it does |
|---------|-------------|
| `bd create "Epic: name" -t epic -p 2` | Create a new epic at priority 2 |
| `bd create "Task: title" -t task --parent <epic-id>` | Create a task under an epic |
| `bd q "quick title"` | Quick-capture a bead without flags |

### Working a Bead

| Command | What it does |
|---------|-------------|
| `bd update <id> --claim` | Claim a bead as in-progress |
| `bd close <id> --reason "..."` | Mark a bead complete with an evidence reason |
| `bd dep add <child> <depends-on>` | Add a dependency between two beads |

### Memory

| Command | What it does |
|---------|-------------|
| `bd remember "insight"` | Store a learning that persists across sessions |
| `bd forget <id>` | Remove a stale or outdated memory |
| `bd memories <keyword>` | Search stored learnings by keyword |

### Sync

| Command | What it does |
|---------|-------------|
| `bd dolt push` | Push beads database to the Dolt remote |
| `bd dolt pull` | Pull latest beads from the Dolt remote |
| `bd github push` | Sync beads to GitHub Issues |
| `bd github pull` | Pull GitHub Issues into beads |
| `bd github status` | Check GitHub sync configuration |

### Health & Housekeeping

| Command | What it does |
|---------|-------------|
| `bd stats` | Summary counts of open, closed, and blocked beads |
| `bd doctor` | Diagnose common configuration problems |
| `bd preflight` | PR readiness check — are all beads closed? |
| `bd find-duplicates` | Find semantically similar beads that may be duplicates |
| `bd note <id> "context"` | Append a note to a bead (evidence, context, updates) |
| `bd stale` | Find beads that have not been touched recently |
| `bd orphans` | Find beads with no parent epic |

> **Land the Plane**
>
> Every session ends with the same three steps: `bd close <id> --reason "..."` for each completed bead, then `bd dolt push` to sync, then `git push` to push code. The **finishing-a-development-branch** skill enforces this sequence.

## Which Skill for Which Situation?

Skills are not suggestions — if a skill applies, it must be used. Use this table to route to the right skill quickly.

| Situation | Skill to invoke |
|-----------|----------------|
| Starting a session or returning after compaction | `getting-up-to-speed` |
| I need to design something before writing code | `brainstorming` |
| I want to stress-test a design or plan | `stress-test` |
| I have an approved design and need a task plan | `writing-plans` |
| I need to implement tasks with full review per task | `subagent-driven-development` |
| I need to execute a plan in a single session | `executing-plans` |
| I am writing any feature or bugfix | `test-driven-development` |
| Tests are failing or behaviour is unexpected | `systematic-debugging` |
| I am about to say the work is done | `verification-before-completion` |
| I need a code review | `requesting-code-review` |
| Someone gave me code review feedback | `receiving-code-review` |
| I need to merge, open a PR, or close a branch | `finishing-a-development-branch` |
| Two or more tasks can be parallelised | `dispatching-parallel-agents` |
| I need to create or modify a skill | `writing-skills` |
| Post-ship — documentation needs updating | `document-release` |
| I need to research a topic before deciding | `research-driven-development` |
| I am writing human-facing documentation or prose | `write-documentation` |

> **Tip**
>
> The **using-superpowers** bootstrap skill (injected automatically at session start) contains the full routing logic and anti-rationalization table. If you are unsure which skill applies, ask Claude to read it explicitly.

## Common Issues

> **Skills not loading**
>
> Verify the plugin is installed and enabled:
>
> ```
> claude plugin list
> # Expected: beads-superpowers@beads-superpowers-marketplace — Status: enabled
>
> /plugins     # Inside Claude Code session — should list beads-superpowers
> /skills      # Should show beads-superpowers: prefixed skills ({{ skill_count }} total)
> ```
>
> If the plugin is listed but skills are missing, check that the SessionStart hook is executable:
>
> ```
> ls -la hooks/session-start   # Should show -rwxr-xr-x
> chmod +x hooks/session-start  # If not executable
> ```

> **`bd: command not found`**
>
> The `bd` CLI is not installed. Install it using one of these methods:
>
> ```
> # Homebrew (macOS / Linux)
> brew install beads
>
> # npm (any platform)
> npm install -g @beads/bd
>
> # curl installer
> curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
>
> # Verify
> bd version
> ```

> **Duplicate context injection (double `bd prime`)**
>
> Running `bd init` or `bd setup claude` installs a SessionStart hook that also runs `bd prime`. The beads-superpowers plugin already does this, so you get double injection — roughly 2x token overhead per session start.
>
> The plugin detects the duplicate and warns you. Fix it with:
>
> ```
> bd setup claude --remove
>
> # Verify no "bd prime" entries remain
> cat .claude/settings.json
> ```

> **Plugin cache is stale after editing skills**
>
> After editing skills in the source repo, the installed plugin cache at `~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.1/` does not update automatically. `claude plugin update` has a [known cache bug](https://github.com/anthropics/claude-code/issues/14061).
>
> Use a one-time symlink instead — see the [Development Tips](#development-tips) section below.
>
> Quick check for drift:
>
> ```
> diff -rq skills/ ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.1/skills/
> ```

> **Tests skip or fail unexpectedly**
>
> The test suite requires `bd`, `git`, and `bash` to be available on `PATH`. Verify each:
>
> ```
> bd version
> git --version
> bash --version
> ```
>
> Fast tests (skill content verification) run in about 2 minutes and have no external dependencies beyond `bash`. Integration tests require a live `bd` installation and a project with `bd init` completed.

> **`bd dolt push` fails**
>
> This most commonly means no Dolt remote is configured. Set one up:
>
> ```
> bd dolt remote add origin https://doltremoteapi.dolthub.com/your-org/your-repo
> ```
>
> If you don't need cross-session remote sync, the failure is harmless — beads continues to work locally. The Land the Plane protocol will still close beads; the push step will simply report an error that can be ignored.

> **Skills still reference TodoWrite**
>
> All active TodoWrite references were replaced with `bd` commands during the migration. If you see any that are not preceded by "Do NOT use TodoWrite", it is a bug.
>
> Verify with:
>
> ```
> grep -r "TodoWrite" skills/ | grep -v "Do NOT use" | grep -v "replaces"
> # Should return empty
> ```

## Development Tips

Tips for contributors who are editing skills or working on the plugin itself.

### One-Time Plugin Cache Symlink

Editing skills in the source repo immediately goes stale in the plugin cache. The symlink approach fixes this permanently — edits in the repo are instantly reflected in the installed plugin, with no sync step required.

```
# Remove the cached copy
rm -rf ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.1

# Symlink the cache entry to this repo
ln -s ~/workplace/beads-superpowers \
  ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.1
```

Verify the symlink is working:

```
diff -rq skills/ ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.5.1/skills/
# Should produce no output
```

### Version Management

The version number is declared in three files that must stay in sync: `package.json`, `.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json`. Always use the bump script — never edit them by hand.

```
# Bump to a new version (updates all three files)
./scripts/bump-version.sh 0.5.1

# Check for version drift across the three files
./scripts/bump-version.sh --check
```

### Running Tests

There is no build step. Skills are plain Markdown and tests verify their content directly.

```
# Fast tests — skill content verification (~2 minutes)
cd tests/claude-code && ./run-skill-tests.sh

# Integration tests — full workflow execution (10–30 minutes)
cd tests/claude-code && ./run-skill-tests.sh --integration
```

### Validation Commands

Run these before opening a PR to verify the plugin is consistent:

```
# Validate plugin manifests
claude plugin validate .claude-plugin/plugin.json

# Verify skill count (should be {{ skill_count }})
ls -d skills/*/ | wc -l

# Verify zero active TodoWrite references (must return empty)
grep -r "TodoWrite" skills/ | grep -v "Do NOT use TodoWrite" | grep -v "replaces TodoWrite"

# Verify beads integration density (should be 30+)
grep -r "bd create\|bd close\|bd ready" skills/ | wc -l

# Test hook output is valid JSON
bash hooks/session-start 2>&1 | python3 -m json.tool
```

### Adding a New Skill

When adding a skill, follow these conventions to avoid breaking Claude's routing logic:

1. Create `skills/<skill-name>/SKILL.md` with a YAML frontmatter block. The `description` field is a trigger condition, not a workflow summary — write it as "Use when X", not "This skill does Y".
2. Make it beads-aware: use `bd create` / `bd close` / `bd ready` for all task tracking. No TodoWrite, no markdown checklists.
3. Update the skills table in `CLAUDE.md` and add a CHANGELOG entry.

> **Anti-patterns to avoid**
>
> When modifying existing skills, do **not** remove anti-rationalization tables, Iron Laws, or Red Flags sections — these are the enforcement mechanism. Do **not** soften bright-line rules by replacing "MUST" with "consider". Do **not** add platform-specific code to skills — skills are pure Markdown.

## Windows Support

The SessionStart hook at `hooks/session-start` is a bash script. On Windows it is called via the polyglot wrapper `hooks/run-hook.cmd`.

The `.cmd` file is simultaneously valid as a Windows batch file and a bash script:

- On Windows: `cmd.exe` interprets the batch portion, which locates Git Bash and re-executes the hook under `bash.exe`.
- On Unix: the shell treats the `:` command as a no-op and executes the rest as bash.

This means the plugin works on Windows without WSL, provided Git for Windows (Git Bash) is installed. No separate Windows configuration is required.

> **Skill content is platform-agnostic**
>
> Skills are plain Markdown with no platform-specific code. The only platform-specific layer is the hook wrapper. If you are writing a new skill, keep it pure Markdown — the hook handles platform differences externally.

## Upstream Tracking

beads-superpowers is a fork that tracks two upstream projects. Changes in either upstream may introduce new skills, modified commands, or updated hook formats that should be merged in.

| Source | Baseline version | What we track |
|--------|-----------------|--------------|
| [obra/superpowers](https://github.com/obra/superpowers) | v5.0.7 | Skill content, new skills, hook changes |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.0.2 | CLI commands, new features, `bd prime` format |

To check whether the repo has drifted from either upstream, invoke the **auditing-upstream-drift** skill. It compares skills, hook output, and command usage against the current upstream releases and produces a prioritised list of changes to review.

> **When to run an upstream audit**
>
> Run `auditing-upstream-drift` before a plugin release, after a long gap between development sessions, or when you notice a skill behaving differently from the upstream documentation.
