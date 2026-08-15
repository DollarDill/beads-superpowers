---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

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
# Check for duplicate beads (clean up before merge)
bd find-duplicates
```

If `bd find-duplicates` reports issues, fix them before proceeding. Then continue to Step 2.

A green suite is necessary but not sufficient: do not merge if a requirement was dropped or a security regression remains (Production-Grade Doctrine).

### Step 2: Detect Environment

Run the following to determine the git context:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
IS_WORKTREE=$( [ "$GIT_DIR" != "$GIT_COMMON" ] && echo "yes" || echo "no" )
IS_DETACHED=$( git symbolic-ref HEAD >/dev/null 2>&1 && echo "no" || echo "yes" )
# Capture now, while still inside the workspace — Step 5 changes directory
# before Step 6 needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

| Context | Detection | Menu |
|---------|-----------|------|
| Normal repo | `IS_WORKTREE=no`, `IS_DETACHED=no` | Full 3 options |
| Named-branch worktree | `IS_WORKTREE=yes`, `IS_DETACHED=no` | Full 3 options |
| Detached HEAD | `IS_DETACHED=yes` | Reduced 2 options (no "Merge locally") |

### Step 3: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3.5: Docs-Audit Gate

document-release must have run on this branch — evidence: a `docs:` commit in `git log <base>..HEAD` not followed by later code commits, or a clean-audit statement from this session. Missing or in doubt → invoke `beads-superpowers:document-release` now (its empty-check exits cheaply when the diff is doc-irrelevant; when in doubt, run the audit). If the audit cannot complete, neither silently pass nor block: prepend "⚠️ docs audit could not complete: <reason>" to the Step 4 options question — the user decides.

### Step 4: Present Options

**Use your structured question tool** to present options. Do NOT present choices as plain prose when your harness has a question tool; without one, numbered list + STOP. A skipped, dismissed, or auto-resolved answer is not consent — stop and ask in plain text.

**For normal repo or named-branch worktree** (`IS_DETACHED=no`), present all 3 options:

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
        "description": "Push branch to origin and open a PR via your forge's CLI or the URL it prints on push"
      },
      {
        "label": "Keep as-is",
        "description": "Leave the branch and worktree intact — handle it later"
      }
    ],
    "multiSelect": false
  }]
}
```

**For detached HEAD** (`IS_DETACHED=yes`), present 2 options (omit "Merge locally"):

```json
{
  "questions": [{
    "question": "Implementation complete. How would you like to finish this work?",
    "header": "Branch",
    "options": [
      {
        "label": "Create Pull Request",
        "description": "Push branch to origin and open a PR via your forge's CLI or the URL it prints on push"
      },
      {
        "label": "Keep as-is",
        "description": "Leave the worktree intact — handle it later"
      }
    ],
    "multiSelect": false
  }]
}
```

Note: Merge is unavailable because HEAD is detached — there is no branch to merge.

**Don't add explanation** — the tool options are self-describing. Map the user's selection to the corresponding option in Step 5.

### Step 5: Execute Choice

#### Option 1: Merge Locally

```bash
# Leave the worktree first — checkout, merge, and worktree removal all have to
# run from the main repo root, and Step 6 needs the path captured in Step 2
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify the merged result before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the worktree and branch in place, and investigate. Nothing has been pushed, so the merge is local and recoverable.

Once the merged result is green, clean up the worktree (Step 6) **first** — git refuses to delete a branch that is still checked out in a live worktree — then delete the branch:

```bash
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR

```bash
# Push branch — IS_DETACHED was captured in Step 2
if [ "$IS_DETACHED" = "yes" ]; then
  # No branch to name from a detached HEAD — push an explicit refspec:
  git push origin HEAD:refs/heads/<new-branch>
else
  git push -u origin <feature-branch>
fi

# Create PR/MR via the forge's CLI (detected from the origin remote)
REMOTE_URL=$(git remote get-url origin)
case "$REMOTE_URL" in
  *github.com*)
    gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)" ;;
  *gitlab*)
    glab mr create --title "<title>" --description "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)" ;;
  *)
    echo "Branch pushed to origin. Open a PR/MR via your forge's web UI or CLI." ;;
esac
```

Keep the worktree — PR feedback gets fixed there, so it stays until the work lands.

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the work away. It is never offered in the menu.

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
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git checkout <base-branch>
```

Then clean up the worktree (Step 6) — git refuses to delete a branch still checked out in a live worktree — and force-delete the branch:

```bash
git branch -D <feature-branch>
```

### Step 6: Cleanup Worktree

**Runs for Option 1 and confirmed discards. Options 2 and 3 always keep the worktree** — PR feedback gets fixed in it, and it stays until the work lands.

`GIT_DIR == GIT_COMMON` means a normal repo with no worktree to clean up — done. Otherwise check provenance before removing, using the `WORKTREE_PATH` captured in Step 2, from before Step 5 changed directory:

```bash
# Only remove worktrees inside .worktrees/ (created by our tooling)
case "$WORKTREE_PATH" in
  */.worktrees/*) bd worktree remove "$WORKTREE_PATH" ;;
  *) echo "WARNING: This worktree is not inside .worktrees/ — it may have been created externally. Skipping automatic removal." ;;
esac
```

`bd worktree remove` refuses while the branch has unpushed commits. Verify the work is safe first — `git merge-base --is-ancestor <branch-tip> <base>` — and only then re-run with `--force`.

**If removal is refused because the worktree "contains modified or untracked files":** those files exist **nowhere else** — uncommitted plans, notes, scratch work. **NEVER `--force` on your own initiative.** Show your human partner exactly what is at stake and ask:

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

```text
Worktree removal refused — these files were never committed:

<file list>

1. Commit them to <branch> before cleanup
2. Move them into <main repo root>
3. Delete them (unrecoverable)

Which?
```

Carry out their choice, then remove the worktree. Note the two refusals are different: unpushed *commits* are recoverable from the branch, but modified/untracked *files* are not recoverable from anywhere.

**Capture what you learned.** At close, record durable, evidence-backed insights (still true next month, tied to a file, test, or command). Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

### Step 7: Land the Plane

**After executing the chosen option (Steps 1-6), complete the session close ritual. This is MANDATORY.**

Work is NOT complete until `git push` succeeds.

```bash
# 1. Close completed task beads with reasons
bd close <task-id-1> <task-id-2> ... --reason "Completed: description of what was done"
```

> **Tip — atomic batch close + follow-up creation:** If you need to close multiple tasks and create a follow-up bead in one atomic operation (all succeed or none do), use `bd batch`:
> ```bash
> printf 'close <task-id-1> Completed: description\nclose <task-id-2> Completed: description\ncreate task 2 Follow-up: remaining work\n' | bd batch
> ```
> Note: `bd batch create` is simplified — no `--description`, `--parent`, or `--acceptance` flags. Use regular `bd create` when those are needed.

```bash
# 2. Close the epic bead (if all child tasks are done)
bd epic status <epic-id>                    # Summary view of completion
bd epic close-eligible                      # Auto-close epics where all children are done
# Or manually: bd close <epic-id> --reason "Epic complete: all tasks finished and reviewed"
```

**3. File remaining work as new beads (if any)**

File remaining work per the **Agent-Filed Bead Discipline** (see `verification-before-completion`):

```bash
bd create "[spec] Remaining: <title>" -t task -p <priority> \
  --notes "Severity: <Critical|Important|Minor>
Confidence: <Confirmed|Speculative>
Evidence: <file:line / failing test / repro | none>"
```

Drop the `[spec]` prefix when the item is Confirmed (evidence cited).

**3.5. Offer memory curation (conditional) — before the push.** If this session produced curation-worthy volume — roughly **3+ new `bd remember` calls** — OFFER (do not auto-run) a capture-enrichment pass now, so curated memories are included in the `bd dolt push` below — or if the session-start composer showed a *store-size nudge* (store ≥ the nudge threshold), offer the pass regardless of this session's capture count. Ask via your structured question tool:

```json
{
  "questions": [{
    "question": "This session captured several new memories. Run a memory-curation pass (consolidate/dedup/structure) before closing?",
    "header": "Curate memory",
    "options": [
      {"label": "Yes, curate", "description": "Invoke memory-curator to enrich + dedup this session's memories (you review the command list before anything is written)"},
      {"label": "Skip", "description": "Leave memories as-is; the on-demand sweep is always available later"}
    ],
    "multiSelect": false
  }]
}
```

If selected, invoke `Skill(beads-superpowers:memory-curator)` (it proposes a reviewed command list; you approve before any write). Below the ~3-memory threshold, stay silent — do NOT prompt every close (offer fatigue retired a similar over-firing hook). Applies to ALL session closes, branch and non-branch.

```bash
# 4. Push beads to Dolt remote
bd dolt push

# 5. Push code to git remote
git pull --ff-only && git push
# If --ff-only fails, the remote actually moved: rebase ONLY if local history is linear;
# a local merge commit means merge deliberately (rebase flattens it and orphans recorded SHAs).

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
| Discard (explicit request only) | - | - | - | ✓ (force) |

**Step 7 (Land the Plane) applies to ALL options.** After executing any option above, complete the session close ritual: close beads, `bd dolt push`, `git push`, `git status`.

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| **Skipping test verification** | Merge broken code, create failing PR | Always verify tests before offering options |
| **Open-ended questions** | "What should I do next?" → ambiguous | Use your structured question tool (3 options for normal/worktree context, 2 for detached HEAD) |
| **Automatic worktree cleanup** | Remove worktree when might need it (Option 2, 3) | Only cleanup for Option 1 and confirmed discards |
| **No confirmation for discard** | Accidentally delete work | Require typed "discard" confirmation |
| **"They seem done with this feature — I'll offer to discard it"** | Discard offered unprompted, next to merge/PR options | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| **"'Yeah, get rid of it' counts as confirmation"** | Loose language treated as authorization to permanently delete work | Only the typed word `discard` authorizes deletion. |

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Merge a dropped requirement or a security regression behind a green test suite
- `--force` a refused worktree removal on your own initiative — "removal refused, `--force` is just finishing the cleanup" is backwards: the refusal means files exist **only** in that worktree, so `--force` destroys them permanently. Show your human partner and ask.

**Always:**
- Verify tests before offering options
- Detect environment before presenting options (Step 2)
- Present 3 options for normal/worktree context, 2 for detached HEAD, via your structured question tool
- Get typed confirmation for discard option
- Clean up worktree for merge and confirmed-discard only (PR and keep-as-is preserve it)
- Check worktree provenance before automatic removal

- Work is NOT complete until both syncs succeed

## Integration

**Called by:**
- **subagent-driven-development** — terminal state after all tasks pass review.
- **executing-plans** — terminal state after all tasks complete.

**Pairs with:**
- **document-release** — invoked by Step 3.5 (Docs-Audit Gate) before merge/PR options.
- **verification-before-completion** — tests must pass before merge options are presented.
