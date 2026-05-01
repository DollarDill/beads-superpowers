---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Run pre-merge checklist:

```bash
# Run pre-merge quality gate
bd preflight

# Check for duplicate beads (clean up before merge)
bd find-duplicates
```

If `bd preflight` or `bd find-duplicates` reports issues, fix them before proceeding. Then continue to Step 2.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Present Options

**Use the `AskUserQuestion` tool** to present exactly these 4 options. Do NOT output them as text — invoke the tool for structured input:

```json
{
  "questions": [{
    "question": "Implementation complete. How would you like to finish this branch?",
    "header": "Branch",
    "options": [
      {
        "label": "Merge locally",
        "description": "Merge back to <base-branch>, run tests on result, delete feature branch"
      },
      {
        "label": "Create Pull Request",
        "description": "Push branch to origin and open a PR via gh cli"
      },
      {
        "label": "Keep as-is",
        "description": "Leave the branch and worktree intact — handle it later"
      },
      {
        "label": "Discard work",
        "description": "Permanently delete this branch and all its commits (requires confirmation)"
      }
    ],
    "multiSelect": false
  }]
}
```

**Don't add explanation** — the tool options are self-describing. Map the user's selection to Option 1–4 in Step 4.

### Step 4: Execute Choice

#### Option 1: Merge Locally

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest
git pull

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 5)

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree (Step 5)

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

### Step 5: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
bd worktree info
```

If yes:
```bash
bd worktree remove <worktree-name>
```

**For Option 3:** Keep worktree.

### Step 6: Land the Plane

**After executing the chosen option (Steps 1-5), complete the session close ritual. This is MANDATORY.**

Work is NOT complete until `git push` succeeds.

```bash
# 1. Close completed task beads with reasons
bd close <task-id-1> <task-id-2> ... --reason "Completed: description of what was done"

# 2. Close the epic bead (if all child tasks are done)
bd epic status <epic-id>                    # Summary view of completion
bd epic close-eligible                      # Auto-close epics where all children are done
# Or manually: bd close <epic-id> --reason "Epic complete: all tasks finished and reviewed"

# 3. File remaining work as new beads (if any)
bd create "Remaining: description of follow-up work" -t task -p 2

# 4. Push beads to Dolt remote
bd dolt push

# 5. Push code to git remote
git pull --rebase && git push

# 6. Verify clean state
git status    # MUST show "up to date with origin"
```

**If `git push` fails:** Resolve and retry until it succeeds. NEVER stop before pushing — that leaves work stranded locally. NEVER say "ready to push when you are" — YOU must push.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

**Step 6 (Land the Plane) applies to ALL options.** After executing any option above, complete the session close ritual: close beads, `bd dolt push`, `git push`, `git status`.

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** Use `AskUserQuestion` tool with exactly 4 structured options

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request

**Always:**
- Verify tests before offering options
- Present exactly 4 options via `AskUserQuestion` tool
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only

- Work is NOT complete until both syncs succeed
