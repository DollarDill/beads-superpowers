---
description: Quick-reference bd command cheat sheet, skill routing table, troubleshooting guide for common issues, and upstream version tracking for superpowers and beads.
---

# Tips & Tricks

## Beads cheat sheet

The commands this workflow leans on day-to-day. Everything else — housekeeping,
recovery, coordination — lives in the upstream reference linked below.

| Command | Does |
|---------|------|
| `bd ready` / `--parent <epic>` / `--explain` | Unblocked work / epic remainder / why (not) ready |
| `bd blocked` | Beads waiting on dependencies |
| `bd show <id>` | Full details for one bead |
| `bd query "status=open AND priority<=1"` | Compound query — replaces `bd list` + jq |
| `bd count --by-status` | Grouped counts (`--by-priority` / `--by-type`) |
| `bd epic status <id>` | Epic progress summary |
| `bd create "Epic: name" -t epic -p 2` | New epic at priority 2 |
| `bd create "Task: title" -t task --parent <epic>` | Task under an epic |
| `bd create` epic + `bd import` tasks | Atomic rich task creation (schema via `bd export`) |
| `bd q "quick title"` | Quick capture |
| `bd update <id> --claim` | Claim as in-progress |
| `bd close <id> --reason "..."` | Complete with evidence |
| `bd dep add <child> <depends-on>` | Add dependency |
| `bd note <id> "context"` | Append evidence to a bead |
| `bd remember "insight"` / `bd memories <kw>` / `bd forget <id>` | Persist / search / remove learnings |
| `bd list --label <topic> --status all` / `bd search "<kw>" --status all` | Search the knowledge base — deferred `research`/`design`/`decision` beads labeled `kb` |
| `bd dolt push` / `pull` | Sync beads DB to/from your beads remote |

!!! info "Go deeper — upstream Beads docs"
    - [CLI reference](https://gastownhall.github.io/beads/cli-reference) — every `bd` command and flag, including the housekeeping and coordination commands trimmed from this sheet (`list`, `stats`, `doctor`, `lint`, `stale`, `find-duplicates`, `defer`, `human`, `swarm`, `batch`, `merge-slot`, `github`, `-C`)
    - [Recovery guides](https://gastownhall.github.io/beads/recovery) — diverged Dolt history, failed syncs

**Land the Plane:** Every session ends with `bd close` → `bd dolt push` (to your beads remote) → `git push` (to your code repo). The `finishing-a-development-branch` skill enforces this.

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
| Update docs after shipping | `document-release` |
| Research a topic | `research-driven-development` |
| Write human-facing prose | `write-documentation` |
| Consolidate or dedup memories | `memory-curator` |

The `using-superpowers` bootstrap skill (auto-loaded at session start) has the full routing logic; if unsure, ask Claude to read it.

## Common issues

See [Getting Started — Troubleshooting](getting-started.md#troubleshooting) for installation and configuration problems. Quick fixes for the most frequent ones:

**Skills not loading** — `/plugins` should list beads-superpowers, `/skills` should show {{ skill_count }} skills. If not, reinstall.

**`bd: command not found`** — `brew install beads` or `npm install -g @beads/bd`.

**Double context injection** — The plugin detects `bd setup claude` hooks and skips its own beads-context section; same-event double-firing is suppressed by a dedup marker. If you still see duplicates, run `bd setup claude --remove`.

**`bd dolt push` fails** — No beads remote configured. Harmless if you don't need remote sync.

## Windows

The SessionStart hook (`hooks/session-start`) is bash. On Windows, the polyglot wrapper `hooks/run-hook.cmd` calls it via Git Bash. The `.cmd` file is valid as both a batch file and a bash script — on Windows, `cmd.exe` finds Git Bash and re-executes; on Unix, the `:` command is a no-op and bash runs the rest. It works without WSL as long as Git for Windows is installed.

Skills are pure Markdown with no platform-specific code. Only the hook wrapper handles platform differences.

## Upstream tracking

| Source | Baseline | Tracking |
|--------|----------|----------|
| [obra/superpowers](https://github.com/obra/superpowers) | v6.1.1 | Skill content, new skills, hooks |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.1.0 | CLI commands, `bd prime` format |
