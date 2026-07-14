---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Iron Law: Use `bd worktree`, NOT `git worktree`

```
ALWAYS use bd worktree commands. NEVER use raw git worktree commands.
```

**Why:** `bd worktree create` does everything `git worktree add` does PLUS:
- Worktree automatically shares the main repo's beads database via git common directory discovery
- Adds the worktree path to `.gitignore` automatically
- Ensures consistent issue state across all worktrees

Raw `git worktree add` misses `.gitignore` setup and safety checks — while beads database sharing works via git common directory, you lose the automation `bd worktree create` provides.

| Action | Use This | NOT This |
|--------|----------|----------|
| Create worktree | `bd worktree create <name>` | ~~`git worktree add`~~ |
| List worktrees | `bd worktree list` | ~~`git worktree list`~~ |
| Remove worktree | `bd worktree remove <name>` | ~~`git worktree remove`~~ |
| Worktree info | `bd worktree info` | ~~(no equivalent)~~ |

> **Note:** Claude Code provides a native `EnterWorktree` tool for worktree management. For non-beads projects, this is a viable alternative. For beads-integrated projects, `bd worktree create` remains mandatory — it handles database sharing and `.gitignore` management that `EnterWorktree` does not provide.
>
> **Deliberate divergence from upstream:** superpowers v6.0.3 rewrote this skill to prefer the harness-native worktree tool first (`EnterWorktree` → existing `.worktrees/` → raw `git worktree`). We do **not** adopt that native-tool-first selection order — it bypasses `bd worktree`'s beads-database sharing across worktrees. The Iron Law above (always `bd worktree`) is intentional and takes precedence.

## Directory Selection

`bd worktree create <name>` handles directory selection automatically:

- Creates the worktree at `./<name>` (e.g., `bd worktree create auth` → `./auth`)
- Adds the path to `.gitignore` automatically
- To use a specific location: `bd worktree create .worktrees/<name>`

If your project has a preferred worktree directory in CLAUDE.md, pass the full path.

## Safety Verification

`bd worktree create` automatically adds the worktree path to `.gitignore` when inside the repo root. Verify as a safety net:

```bash
git check-ignore -q <worktree-path> 2>/dev/null
```

**If NOT ignored** (edge case — `bd worktree create` should have handled this): add the path to `.gitignore` and commit.

## Pre-Flight Checks

Run these checks BEFORE creating any worktree.

### Detect Existing Worktree Isolation

Check whether you are already inside a worktree:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
if [ "$GIT_DIR" != "$GIT_COMMON" ]; then
  echo "WARNING: Already inside a worktree."
fi
```

If already in a worktree, warn and ask via your structured question tool whether to proceed (creating a nested worktree) or abort.

### Submodule Guard

Check whether you are inside a git submodule:

```bash
SUPERPROJECT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
if [ -n "$SUPERPROJECT" ]; then
  echo "WARNING: Inside a git submodule. Worktrees behave unpredictably here."
fi
```

If inside a submodule, warn and **stop**. Do NOT create worktrees inside submodules.

### Consent Flow

- **User-initiated** (manual worktree creation): Ask via your structured question tool before creating — "I'd like to create a worktree at `<path>`. Proceed?"
- **Dispatched by subagent-driven-development**: Consent is implicit — the orchestrator authorized worktree creation. Skip the prompt.

## Creation Steps

### 0. Claim the bead first

Before creating the worktree, claim the issue you're about to work on. This prevents ownerless work — you own the bead before any environment exists.

```bash
bd update <issue-id> --claim
```

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several closes/updates/dep-adds = one `bd batch`; an epic + children =
> `bd import`, not a create-loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

### 1. Create Worktree with `bd worktree create`

```bash
# Simple — creates worktree at ./<name> with matching branch
bd worktree create <feature-name>

# With explicit branch name
bd worktree create <feature-name> --branch <branch-name>

# At a specific path (e.g., project worktrees directory)
bd worktree create .worktrees/<feature-name>

# Then cd into it
cd <worktree-path>
```

**What `bd worktree create` does automatically:**
1. Creates the git worktree with a new branch
2. Worktree automatically discovers the main repo's beads database via git common directory (no redirect file needed)
3. Adds worktree path to `.gitignore` (if inside repo root)

### 2. Run Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 3. Verify Clean Baseline

Run tests to ensure worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
cargo test
pytest
go test ./...
```

**If tests fail:** Report failures, then **use your structured question tool** to ask:
  Question: "Baseline tests failing in worktree (<N> failures). How should I proceed?"
  Options: "Investigate failures" (debug before starting feature work), "Proceed anyway" (start implementation despite pre-existing failures)
  A skipped, dismissed, or auto-resolved answer is not consent — stop and ask in plain text.

**If tests pass:** Report ready.

### 4. Report Location

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Multiple Worktrees for Parallel Subagents

When Subagent-Driven Development runs independent tasks in parallel, the **orchestrator** creates and manages multiple worktrees. Subagents never create or destroy worktrees — they receive a path and work within it.

**Pattern:**

```bash
# 1. Orchestrator creates epic worktree (once)
bd worktree create <epic-name>

# 2. For each parallel task (max 5 concurrent):
bd worktree create <task-name> --branch feature/<epic>/<task>

# 3. Subagent receives path in its prompt:
#    "Work from: <task-worktree-path>"

# 4. After task passes review — orchestrator merges and cleans up:
cd <epic-worktree-path>
git merge feature/<epic>/<task>
bd worktree remove <task-name>
```

**Constraints:**
- Maximum 5 concurrent task worktrees (resource limit)
- Orchestrator manages the full lifecycle — subagents never run `bd worktree` commands
- All task worktrees branch from the same HEAD commit (created before any subagent commits)
- After merge, run the full test suite on the epic worktree to catch integration issues

**See also:** `beads-superpowers:subagent-driven-development` → Parallel Batch Mode section for the full orchestration flow.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Creating a worktree | `bd worktree create <name>` — handles path + .gitignore |
| Custom location needed | `bd worktree create .worktrees/<name>` or path from CLAUDE.md |
| Directory not ignored | Add to .gitignore + commit (edge case) |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Parallel subagent work | Create one `bd worktree` per task, orchestrator manages lifecycle (max 5) |
| Working across worktrees | `bd -C .worktrees/<name> ready` — run bd in a worktree without cd |

## Common Mistakes

### Using `git worktree` instead of `bd worktree`

- **Problem:** Raw `git worktree add` misses `.gitignore` setup and safety checks — while beads database sharing works via git common directory, you lose the automation `bd worktree create` provides
- **Fix:** ALWAYS use `bd worktree create`. If you catch yourself typing `git worktree`, stop and use `bd worktree` instead.

### Skipping ignore verification

- **Problem:** Worktree contents get tracked, pollute git status
- **Fix:** Verify with `git check-ignore` after creation (`bd worktree create` handles this automatically, but verify as a safety net)

### Overriding `bd worktree create` path logic

- **Problem:** Manually picking directories when `bd worktree create` handles it
- **Fix:** Just run `bd worktree create <name>` — it creates at `./<name>` and handles `.gitignore`

### Proceeding with failing tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

### Hardcoding setup commands

- **Problem:** Breaks on projects using different tools
- **Fix:** Auto-detect from project files (package.json, etc.)

## Example Workflow

```
You: I'm using the using-git-worktrees skill to set up an isolated workspace.

[Create worktree: bd worktree create auth --branch feature/auth]
  ✓ Created worktree at ./auth
  ✓ Beads database shared via git common directory
  ✓ Added to .gitignore
[cd auth]
[Run npm install]
[Run npm test - 47 passing]

Worktree ready at /Users/jesse/myproject/auth
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
```

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## Red Flags

**Never:**
- Use raw `git worktree` commands — ALWAYS use `bd worktree`
- Create worktree without verifying it's ignored (project-local)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous
- Skip CLAUDE.md check

**Always:**
- Use `bd worktree create` / `bd worktree list` / `bd worktree remove`
- Let `bd worktree create` handle path and `.gitignore`
- Auto-detect and run project setup
- Verify clean test baseline

## Integration

**Invoked by:** Any task needing workspace isolation, or user on-demand.

**Required by:**
- **subagent-driven-development** — must create worktree before delegating to implementer subagents.
- **executing-plans** — workspace isolation before starting plan execution.

**Pairs with:** **subagent-driven-development** — parallel batch mode creates multiple worktrees (one per task) for concurrent subagent execution.
