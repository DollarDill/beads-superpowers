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

## Creation Steps

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

**If tests fail:** Report failures, then **use the `AskUserQuestion` tool** to ask:
  Question: "Baseline tests failing in worktree (<N> failures). How should I proceed?"
  Options: "Investigate failures" (debug before starting feature work), "Proceed anyway" (start implementation despite pre-existing failures)

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

**See also:** `superpowers:subagent-driven-development` → Parallel Batch Mode section for the full orchestration flow.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Creating a worktree | `bd worktree create <name>` — handles path + .gitignore |
| Custom location needed | `bd worktree create .worktrees/<name>` or path from CLAUDE.md |
| Directory not ignored | Add to .gitignore + commit (edge case) |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Parallel subagent work | Create one `bd worktree` per task, orchestrator manages lifecycle (max 5) |

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

If you discovered something reusable, capture it before closing:

```bash
# Only if worth preserving for future sessions:
bd remember "worktree: <gotcha or workaround>"
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
