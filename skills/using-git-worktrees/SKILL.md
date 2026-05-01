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

## Directory Selection Process

Follow this priority order:

### 1. Check Existing Directories

```bash
# Check in priority order
ls -d .worktrees 2>/dev/null     # Preferred (hidden)
ls -d worktrees 2>/dev/null      # Alternative
```

**If found:** Use that directory. If both exist, `.worktrees` wins.

### 2. Check CLAUDE.md

```bash
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

**If preference specified:** Use it without asking.

### 3. Ask User

If no directory exists and no CLAUDE.md preference, **use the `AskUserQuestion` tool**:

```json
{
  "questions": [{
    "question": "No worktree directory found. Where should I create worktrees?",
    "header": "Worktree dir",
    "options": [
      {
        "label": ".worktrees/ (Recommended)",
        "description": "Project-local hidden directory — keeps worktrees near the code"
      },
      {
        "label": "~/.config/superpowers/worktrees/",
        "description": "Global location outside the project — no .gitignore needed"
      }
    ],
    "multiSelect": false
  }]
}
```

## Safety Verification

**Note:** `bd worktree create` automatically adds the worktree path to `.gitignore` when inside the repo root. Manual verification is a safety net, not the primary mechanism.

### For Project-Local Directories (.worktrees or worktrees)

**Verify directory is ignored after creation:**

```bash
# Check if directory is ignored (respects local, global, and system gitignore)
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**If NOT ignored** (edge case — `bd worktree create` should have handled this):

1. Add appropriate line to .gitignore
2. Commit the change

**Why critical:** Prevents accidentally committing worktree contents to repository.

### For Global Directory (~/.config/superpowers/worktrees)

No .gitignore verification needed - outside project entirely.

## Creation Steps

### 1. Create Worktree with `bd worktree create`

```bash
# Simple — creates worktree at ./<name> with matching branch
bd worktree create <feature-name>

# With explicit branch name
bd worktree create <feature-name> --branch <branch-name>

# At a specific path (e.g., global location)
bd worktree create ~/.config/superpowers/worktrees/<project>/<feature-name>

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

## Quick Reference

| Situation | Action |
|-----------|--------|
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check CLAUDE.md → Ask user |
| Directory not ignored | Add to .gitignore + commit |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Mistakes

### Using `git worktree` instead of `bd worktree`

- **Problem:** Raw `git worktree add` misses `.gitignore` setup and safety checks — while beads database sharing works via git common directory, you lose the automation `bd worktree create` provides
- **Fix:** ALWAYS use `bd worktree create`. If you catch yourself typing `git worktree`, stop and use `bd worktree` instead.

### Skipping ignore verification

- **Problem:** Worktree contents get tracked, pollute git status
- **Fix:** Verify with `git check-ignore` after creation (`bd worktree create` handles this automatically, but verify as a safety net)

### Assuming directory location

- **Problem:** Creates inconsistency, violates project conventions
- **Fix:** Follow priority: existing > CLAUDE.md > ask

### Proceeding with failing tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

### Hardcoding setup commands

- **Problem:** Breaks on projects using different tools
- **Fix:** Auto-detect from project files (package.json, etc.)

## Example Workflow

```
You: I'm using the using-git-worktrees skill to set up an isolated workspace.

[Check .worktrees/ - exists]
[Create worktree: bd worktree create auth --branch feature/auth]
  ✓ Created worktree at .worktrees/auth
  ✓ Beads database shared via git common directory
  ✓ Added to .gitignore
[cd .worktrees/auth]
[Run npm install]
[Run npm test - 47 passing]

Worktree ready at /Users/jesse/myproject/.worktrees/auth
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
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
- Follow directory priority: existing > CLAUDE.md > ask
- Verify directory is ignored for project-local
- Auto-detect and run project setup
- Verify clean test baseline

