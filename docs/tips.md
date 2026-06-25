---
description: Quick-reference bd command cheat sheet, skill routing table, troubleshooting guide for common issues, and upstream version tracking for superpowers and beads.
---

# Tips & Tricks

## Beads cheat sheet

### Finding work

| Command | Does |
|---------|------|
| `bd ready` | Unblocked beads ready to work |
| `bd ready --parent <epic>` | Remaining tasks in an epic |
| `bd list --status=open` | All open beads |
| `bd query "status=open AND priority<=1"` | Compound query — replaces `bd list` + jq (v1.0.5) |
| `bd count --by-status` | Grouped counts (`--by-priority` / `--by-type`) (v1.0.5) |
| `bd show <id>` | Full details for one bead |
| `bd blocked` | Beads waiting on dependencies |
| `bd epic status <id>` | Epic progress summary |

### Creating

| Command | Does |
|---------|------|
| `bd create "Epic: name" -t epic -p 2` | New epic at priority 2 |
| `bd create "Task: title" -t task --parent <epic>` | Task under an epic |
| `bd q "quick title"` | Quick capture |

### Working

| Command | Does |
|---------|------|
| `bd update <id> --claim` | Claim as in-progress |
| `bd close <id> --reason "..."` | Complete with evidence |
| `bd dep add <child> <depends-on>` | Add dependency |
| `bd batch` (stdin or `-f`) | Atomic multi-op transactions (close, dep, update) |
| `bd -C <path> <command>` | Run bd against another directory without cd |
| `bd ready --explain` | Show why tasks are/aren't ready |
| `bd merge-slot acquire` / `release` | Serialize merges across concurrent orchestrators (v1.0.5) |

### Memory

| Command | Does |
|---------|------|
| `bd remember "insight"` | Persist a learning across sessions |
| `bd forget <id>` | Remove stale memory |
| `bd memories <keyword>` | Search learnings |

### Sync

| Command | Does |
|---------|------|
| `bd dolt push` / `pull` | Sync beads DB to/from Dolt remote |
| `bd github push` / `pull` | Sync beads to/from GitHub Issues |

### Housekeeping

| Command | Does |
|---------|------|
| `bd stats` | Open/closed/blocked counts |
| `bd doctor` | Diagnose config problems |
| `bd lint [id...]` | Check issues for missing required sections |
| `bd note <id> "context"` | Append evidence to a bead |
| `bd stale` | Beads with no recent activity |
| `bd find-duplicates` | Semantically similar beads |
| `bd defer <id> --until="..."` | Defer work to a future date |
| `bd human <id>` | Flag issue for human decision |
| `bd swarm validate <epic>` | Analyze parallel work graph |

**Land the Plane:** Every session ends with `bd close` → `bd dolt push` → `git push`. The `finishing-a-development-branch` skill enforces this.

## Skill routing

| I need to... | Invoke |
|---|---|
| Orient at session start | `getting-up-to-speed` |
| Design before coding | `brainstorming` |
| Stress-test a design | `stress-test` |
| Write a task plan | `writing-plans` |
| Execute tasks with review per task | `subagent-driven-development` |
| Execute a plan in one session | `executing-plans` |
| Write a feature or bugfix | `test-driven-development` |
| Debug a failure | `systematic-debugging` |
| Claim work is done | `verification-before-completion` |
| Get code reviewed | `requesting-code-review` |
| Respond to review feedback | `receiving-code-review` |
| Merge or close a branch | `finishing-a-development-branch` |
| Run independent tasks in parallel | `dispatching-parallel-agents` |
| Create or modify a skill | `writing-skills` |
| Update docs after shipping | `document-release` |
| Research a topic | `research-driven-development` |
| Write human-facing prose | `write-documentation` |

The `using-superpowers` bootstrap skill (auto-loaded at session start) has the full routing logic; if unsure, ask Claude to read it.

## Common issues

See [Getting Started — Troubleshooting](getting-started.md#troubleshooting) for installation and configuration problems. Quick fixes for the most frequent ones:

**Skills not loading** — `/plugins` should list beads-superpowers, `/skills` should show {{ skill_count }} skills. If not, reinstall.

**`bd: command not found`** — `brew install beads` or `npm install -g @beads/bd`.

**Double `bd prime`** — The plugin automatically detects `bd setup claude` hooks and skips its own `bd prime` call. If you still see duplicates, run `bd setup claude --remove`.

**`bd dolt push` fails** — No Dolt remote configured. Harmless if you don't need remote sync.

## Windows

The SessionStart hook (`hooks/session-start`) is bash. On Windows, the polyglot wrapper `hooks/run-hook.cmd` calls it via Git Bash. The `.cmd` file is valid as both a batch file and a bash script — on Windows, `cmd.exe` finds Git Bash and re-executes; on Unix, the `:` command is a no-op and bash runs the rest. It works without WSL as long as Git for Windows is installed.

Skills are pure Markdown with no platform-specific code. Only the hook wrapper handles platform differences.

## Upstream tracking

| Source | Baseline | Tracking |
|--------|----------|----------|
| [obra/superpowers](https://github.com/obra/superpowers) | v6.0.3 | Skill content, new skills, hooks |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.0.5 | CLI commands, `bd prime` format |

Run `auditing-upstream-drift` before a release or after a long gap to check for changes to port.
