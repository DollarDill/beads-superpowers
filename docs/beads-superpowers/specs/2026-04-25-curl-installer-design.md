# Spec: `install.sh` — curl-based one-command installer

**Date:** 2026-04-25
**Status:** Approved (brainstorming complete, awaiting user spec review)
**Brainstorming bead:** `beads-superpowers-4wv`
**Research:** `~/workplace/knowledge/tools-and-processes/curl-installer-patterns-for-cli-plugins.md`
**Author:** Dillon Frawley + Claude

## Summary

Add `install.sh` to the repo root — a curl-pipe-bash installer that replaces the current two-step flow (`npx skills add` + manual "run the setup skill") with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The script downloads a GitHub release tarball, extracts 20 skills to `~/.claude/skills/`, creates the SessionStart hook script, registers it in `~/.claude/settings.json`, and prints next-step guidance. Current 7-step install → 1-step install. ~10-15 seconds vs ~2-5 minutes.

## Problem

The current install paths both have friction:

1. **Marketplace** (`claude plugin marketplace add` + `claude plugin install`) — two commands, requires knowing exact names, [marketplace cache bug](https://github.com/anthropics/claude-code/issues/14061) prevents updates.
2. **npx** (`npx skills add DollarDill/beads-superpowers --all -y -g`) — depends on the Vercel Skills CLI (unreliable — "Unknown command: skills" errors observed 2026-04-25), AND requires a second manual step: telling Claude "run the setup skill" to configure the SessionStart hook. Without that step, skills install but never auto-activate.

## Goals

1. Single `curl | bash` command — zero follow-up steps to get skills working.
2. Direct file installer (not a marketplace orchestrator) — no dependency on `claude` CLI.
3. Safe by default — function-wrapped, strict mode, consent prompt, settings.json backup, custom-skill protection.
4. Idempotent — safe to re-run (detects existing install, compares versions).
5. Uninstallable — `--uninstall` flag cleanly removes everything the installer created.

## Non-Goals

- Installing the beads CLI (`bd`) — print guidance if missing, don't block or install.
- Windows native support — macOS + Linux only; Windows users use WSL or the marketplace path.
- Auto-uninstalling upstream `superpowers@claude-plugins-official` — hard block with clear uninstall command instead.
- Plugin manifest registration in `installed_plugins.json` — the direct file approach bypasses the marketplace entirely.
- Version bumping the project — the installer is a new file, not a version-increment change (unless user chooses to bump during document-release).

## Design Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Scope: skills + hook only** | Install the 20 skills and SessionStart hook. If `bd` is missing, print install guidance but don't block. Keeps installer focused on its own domain. |
| 2 | **Conflict: block until resolved** | If upstream `superpowers@claude-plugins-official` is detected in `installed_plugins.json`, refuse to install and print exact `claude plugin uninstall` command. Safest — forces a clean slate, avoids duplicate skill loading. |
| 3 | **Versioning: GitHub API for latest release** | Query `https://api.github.com/repos/DollarDill/beads-superpowers/releases/latest` to find the latest tag. Supports `--version` flag for pinning. Falls back to `FALLBACK_VERSION` hardcoded in the script if API is unreachable. |
| 4 | **Platforms: macOS + Linux** | `curl \| bash` is a Unix convention. Windows users have WSL (which is Linux). The existing `hooks/run-hook.cmd` polyglot handles Windows at runtime. |
| 5 | **Approach: Direct File Installer** | Download GitHub tarball → extract skills → create hook → modify settings.json. No dependency on `claude` CLI. Replicates exactly what npx + setup skill does, in one step. Matches the user's current `~/.claude/skills/` layout. |

## Architecture

### File

`install.sh` at repo root (committed, versioned, downloadable from GitHub raw URL).

### Invocation

```bash
# Standard (interactive)
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash

# Pin to specific version
curl -fsSL <url> | bash -s -- --version 0.4.0

# CI / non-interactive
curl -fsSL <url> | bash -s -- --yes

# Preview without mutating
curl -fsSL <url> | bash -s -- --dry-run

# Remove everything
curl -fsSL <url> | bash -s -- --uninstall

# Inspect-first (security-conscious)
curl -fsSL <url> -o install.sh && less install.sh && bash install.sh
```

### Security

- **Function wrapping** — entire body in `main() { ... }; main "$@"` (Homebrew/rustup pattern, prevents partial execution)
- **`set -euo pipefail`** — strict mode, fail on any error or unset variable
- **HTTPS only** — `curl -fsSL` (fail on HTTP errors, follow redirects, show errors, silent progress)
- **No sudo** — everything installs to `~/.claude/` (user-writable)
- **Settings.json backup** — timestamped, before every modification
- **Consent prompt** — print plan, wait for Enter (skip with `--yes` or non-TTY)
- **`--dry-run`** — preview without mutations

### Prerequisites

| Tool | Required | Check | Failure message |
|---|---|---|---|
| `curl` | Yes | `command -v curl` | "curl is required. Install via your package manager." |
| `python3` | Yes | `command -v python3` | "python3 is required for safe JSON editing. Install via: brew install python3 / apt install python3" |
| `tar` | Yes | `command -v tar` | "tar is required. Install via your package manager." |
| `bash` | Implicit | — | Script interpreter |
| `claude` | No | — | Not needed — direct file install bypasses marketplace |
| `bd` | No | `command -v bd` | If missing: print install guidance in Phase 5. NOT a blocker. |

## 5-Phase Pipeline

### Phase 1: Checks (zero mutations)

```
detect_platform()           → uname -s (Darwin/Linux), uname -m (x86_64/arm64), $SHELL (bash/zsh)
check_prerequisites()       → curl, python3, tar — fail with clear message if missing
detect_upstream_conflict()   → python3: parse ~/.claude/plugins/installed_plugins.json for "superpowers@claude-plugins-official"
                              If found → print exact uninstall command → EXIT 1 (hard block)
detect_existing_install()    → test -f ~/.claude/skills/.beads-superpowers-version
                              If found → compare version → "already at X" (exit 0) or "upgrading X → Y"
resolve_version()            → --version flag > GitHub API (releases/latest) > FALLBACK_VERSION
detect_beads()               → command -v bd → note for Phase 5 guidance (NOT a blocker)
```

### Phase 2: Consent (interactive only)

```
beads-superpowers v0.4.0 installer

This script will:
  • Download 20 skills to ~/.claude/skills/
  • Create SessionStart hook at ~/.claude/hooks/beads-superpowers-session-start.sh
  • Register hook in ~/.claude/settings.json (backup created first)

Press Enter to continue (or Ctrl+C to cancel)...
```

Skipped when `--yes` flag or stdin is not a TTY.

### Phase 3: Install (mutations)

1. `TMPDIR=$(mktemp -d)` + `trap "rm -rf $TMPDIR" EXIT` — temp workspace with automatic cleanup
2. Download tarball: `curl -fsSL "https://github.com/DollarDill/beads-superpowers/archive/refs/tags/v${VERSION}.tar.gz" -o "$TMPDIR/release.tar.gz"`
3. Extract: `tar xzf "$TMPDIR/release.tar.gz" --strip-components=1 -C "$TMPDIR/extracted"`
4. Copy skills by name — iterate over the 20 known skill directory names, `cp -rf` each from extracted tarball to `~/.claude/skills/<name>/`. **NEVER `rm -rf ~/.claude/skills/`** — this protects custom skills like `daily-digest`.
5. Write hook script to `~/.claude/hooks/beads-superpowers-session-start.sh` — same logic as the existing `skills/setup/SKILL.md` creates: reads `using-superpowers/SKILL.md`, runs `bd prime` if available, outputs platform-appropriate JSON.
6. `chmod +x` the hook script.
7. Backup `settings.json`: `cp -f ~/.claude/settings.json ~/.claude/settings.json.backup-$(date +%Y%m%d-%H%M%S)` (create parent dirs if needed).
8. Register hook via Python3 one-liner: read JSON → add `SessionStart` entry if not present → write. The hook entry matches format: `{ "matcher": "startup|clear|compact", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/beads-superpowers-session-start.sh" }] }`.
9. Write version marker: `echo "$VERSION" > ~/.claude/skills/.beads-superpowers-version`.

### Phase 4: Verify (post-mutation checks)

1. Count installed skills: `ls -d ~/.claude/skills/*/ | wc -l` (should be >= 20)
2. Test hook output: `bash ~/.claude/hooks/beads-superpowers-session-start.sh 2>/dev/null | python3 -m json.tool > /dev/null`
3. Check settings.json: `python3 -c "import json; d=json.load(open(...)); assert any('beads-superpowers' in str(h) for h in d.get('hooks',{}).get('SessionStart',[]))"`
4. Read version marker: `cat ~/.claude/skills/.beads-superpowers-version`

If any check fails: print specific failure + suggest manual remediation. Do NOT exit 1 — partial success is still useful.

### Phase 5: Print next steps

```
✓ beads-superpowers v0.4.0 installed (20 skills, hook configured)

Next steps:
  1. Restart Claude Code (or start a new session) to activate skills
  2. Run /skills to verify — you should see 20+ skills available
```

If `bd` not found, append:
```
  3. Install beads for persistent task tracking:
       brew install beads          # macOS (Homebrew)
       npm install -g @beads/bd   # any platform (npm)
  4. In each project: bd init
```

## The `--uninstall` Flow

1. Read the 20 known skill names from the hardcoded list in the script.
2. Remove ONLY those 20 directories from `~/.claude/skills/` (never blanket-delete).
3. Remove `~/.claude/hooks/beads-superpowers-session-start.sh`.
4. Remove the `SessionStart` hook entry from `settings.json` via Python3 (read → filter → write, with backup first).
5. Remove version marker (`.beads-superpowers-version`).
6. Print summary of what was removed.

Does NOT touch: settings.json backups, custom skills, `.beads/` directories, `bd` CLI.

## The 20 Known Skill Names (hardcoded list)

```
auditing-upstream-drift    brainstorming              dispatching-parallel-agents
document-release           executing-plans            finishing-a-development-branch
getting-up-to-speed        project-init               receiving-code-review
requesting-code-review     setup                      stress-test
subagent-driven-development systematic-debugging      test-driven-development
using-git-worktrees        using-superpowers           verification-before-completion
writing-plans              writing-skills
```

This list MUST be updated when skills are added or removed. It is the safety boundary between "our skills" and "user's custom skills".

## Hook Script Content

The hook script (`~/.claude/hooks/beads-superpowers-session-start.sh`) is functionally identical to the one created by `skills/setup/SKILL.md` today. It:

1. Finds `using-superpowers/SKILL.md` (checks `~/.claude/skills/` and `~/.agents/skills/`)
2. Runs `bd prime` if `bd` is available (captures beads workflow context + persistent memories)
3. Escapes both for JSON embedding (backslashes, quotes, newlines, tabs)
4. Outputs Claude Code hook JSON: `{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." } }`

The installer embeds this script inline (heredoc) rather than downloading it separately — reduces network calls from 2 to 1.

## Edge Cases

| Scenario | Behaviour |
|---|---|
| `~/.claude/` doesn't exist | Create it (and `skills/`, `hooks/` subdirs) |
| `~/.claude/settings.json` doesn't exist | Create with minimal `{"hooks":{"SessionStart":[...]}}` |
| `settings.json` exists but no `hooks` key | Add `hooks` key via Python3 |
| `settings.json` already has beads-superpowers hook | Skip registration (idempotent) |
| GitHub API unreachable (rate limited, offline) | Fall back to `FALLBACK_VERSION` hardcoded in script |
| GitHub tarball download fails | Error with URL + HTTP status, suggest retry or `--version` flag |
| `python3` missing | Fail with clear message + install guidance |
| Upstream superpowers detected | Hard block — print uninstall command, exit 1 |
| Same version already installed | Print "already installed at vX.Y.Z", exit 0 |
| Older version installed | Print "Upgrading vX → vY", overwrite skills + hook |
| `--dry-run` | Print every step without writing to disk |
| Partial prior install (from crash) | Treat as upgrade — overwrite whatever exists |
| Disk full / permission denied | `set -e` catches write failure; `trap` cleans up tmpdir |

## Files Touched (by this feature)

| File | Change |
|---|---|
| `install.sh` | NEW — the installer script (~250-350 lines) |
| `README.md` | Add "Option C: curl" install path to "Try it in 60 seconds" section |
| `CHANGELOG.md` | New `### Added` entry under `[Unreleased]` |
| `CLAUDE.md` | Note installer in "Installation" section |

## Testing Plan

| # | Scenario | Setup | Expected |
|---|---|---|---|
| 1 | Fresh macOS (no Claude Code) | Remove `~/.claude/` entirely | `~/.claude/{skills,hooks}` created; 20 skills installed; settings.json created from scratch; hook outputs valid JSON |
| 2 | Existing install (same version) | Run installer twice | Second run prints "already installed at vX.Y.Z", exit 0 |
| 3 | Existing install (older version) | Set version marker to "0.3.1", run installer | Prints "Upgrading 0.3.1 → 0.4.0"; skills overwritten; custom skills preserved |
| 4 | Upstream superpowers conflict | Install `superpowers@claude-plugins-official` | Blocks with "upstream superpowers detected" + exact uninstall command |
| 5 | `--dry-run` | Run with flag | Prints plan; no files created or modified |
| 6 | `--uninstall` | Install first, then uninstall | 20 skill dirs removed; hook removed; settings entry removed; custom skills preserved |
| 7 | No `python3` | Temporarily hide python3 | Clear error: "python3 is required..." |
| 8 | CI mode (`--yes`) | Pipe with `--yes` flag | Runs non-interactively; no consent prompt |
| 9 | Custom skill protection | Create `~/.claude/skills/my-custom-skill/` before install | After install: `my-custom-skill/` still present alongside 20 beads-superpowers skills |
| 10 | GitHub API down | Block API calls | Falls back to FALLBACK_VERSION, installs successfully |

## Acceptance Criteria

- [ ] `install.sh` exists at repo root, ~250-350 lines
- [ ] `bash install.sh --dry-run` prints the plan without writing anything
- [ ] `bash install.sh --yes` installs 20 skills + hook + settings entry non-interactively
- [ ] `ls -d ~/.claude/skills/*/ | wc -l` returns >= 20 after install
- [ ] `bash ~/.claude/hooks/beads-superpowers-session-start.sh 2>/dev/null | python3 -m json.tool` succeeds
- [ ] `~/.claude/settings.json` contains beads-superpowers hook entry
- [ ] `~/.claude/skills/.beads-superpowers-version` contains the installed version
- [ ] `bash install.sh --uninstall` removes only beads-superpowers artifacts
- [ ] Custom skills at `~/.claude/skills/` survive both install and uninstall
- [ ] Re-running the installer (same version) exits 0 with "already installed"
- [ ] README.md documents the curl install path
- [ ] CHANGELOG.md has the entry under `[Unreleased]`
- [ ] Script is function-wrapped (`main()`) and starts with `set -euo pipefail`
- [ ] `shellcheck install.sh` passes (or has documented exceptions)

## Rollback

`bash install.sh --uninstall` removes everything the installer created. Additionally, `~/.claude/settings.json.backup-<timestamp>` restores the pre-install settings state.
