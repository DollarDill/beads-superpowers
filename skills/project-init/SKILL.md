---
name: project-init
description: Use when beads/Dolt database initialization fails, when bd commands return errors about missing databases, when setting up beads in a new project, or when recovering from diverged Dolt history. Handles fresh init, bootstrap from remote, and recovery workflows.
---

# Project Init: Beads/Dolt Database Setup and Recovery

> **Source:** Based on [gastownhall/beads SYNC_SETUP.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_SETUP.md)

**Announce at start:** "I'm using the project-init skill to set up or recover the beads database."

## Iron Law: NEVER Run `bd init --force`

```
NEVER run bd init --force. It destroys ALL existing data without confirmation.
```

**Why:** Issue #2363 documents an AI agent that destroyed 247 issues via `bd init --force` cascade. The root cause was misdiagnosing "server can't connect" as "database missing". `bd init --force` is a nuclear option that should ONLY be run by a human who explicitly types it.

| Action | Safe? | Use When |
|--------|-------|----------|
| `bd init` | ✅ Safe | Fresh project, no existing .beads/ |
| `bd bootstrap` | ✅ Safe | Cloned repo with remote beads data |
| `bd doctor --fix --yes` | ✅ Safe | Database exists but seems broken |
| `bd init --force` | ❌ **NEVER** | **Do NOT use — destroys all data** |

## Diagnostic Phase (Always Run First)

Before taking ANY action, run diagnostics to understand the current state:

```bash
# 1. Check prerequisites
bd version                          # Must be >= 1.0.0
dolt version 2>/dev/null            # Optional but helpful

# 2. Check if .beads/ exists
ls -la .beads/ 2>/dev/null

# 3. Check database config
cat .beads/config.yaml 2>/dev/null
cat .beads/metadata.json 2>/dev/null

# 4. Test if database is functional
bd list 2>/dev/null

# 5. Check commit history
bd vc log 2>/dev/null | head -5

# 6. Check if remote has beads data
git ls-remote origin 2>/dev/null | grep dolt

# 7. Check registered remotes
bd dolt remote list 2>/dev/null

# 8. Run automated diagnostics
bd doctor --fix --yes 2>/dev/null
```

## Decision Matrix

Based on diagnostic results, follow the appropriate path:

| State | Action | Path |
|-------|--------|------|
| No .beads/, no remote data | Fresh init | → Path A |
| No .beads/, remote has dolt refs | Bootstrap from remote | → Path B |
| .beads/ exists, `bd list` works, remote matches | Already good ✅ | Done |
| .beads/ exists, `bd list` fails | Run `bd doctor --fix --yes` | → Path D |
| .beads/ exists, `bd list` works, no remote | Add remote | → Path E |
| .beads/ exists, push fails "no common ancestor" | Fix diverged history | → Path C |
| .beads/ exists but empty/corrupt, remote has data | Export + re-bootstrap | → Path F |

## Path A: Fresh Initialization (New Project)

```bash
# 1. Initialize beads
bd init

# 2. Verify
bd list                    # Should work (empty is fine)
bd create "Test bead" -t task -p 4
bd list                    # Should show the test bead
bd close <test-id> --reason "Init verification"

# 3. Add remote (if syncing to GitHub)
bd dolt remote add origin git+ssh://git@github.com/<owner>/<repo>.git

# 4. First push
bd dolt push
```

## Path B: Bootstrap from Remote (Cloned Repo)

```bash
# 1. Bootstrap (auto-detects remote dolt data)
bd bootstrap

# 2. Verify
bd list                    # Should show existing issues
bd vc log | head -5        # Should show commit history
```

**If `bd bootstrap` fails**, use the manual fallback:

```bash
# Manual bootstrap (8 steps)
bd init                                    # Creates empty .beads/
bd dolt stop 2>/dev/null                   # Stop server if running
DB_NAME=$(python3 -c "import json; print(json.load(open('.beads/metadata.json')).get('dolt_database','beads'))" 2>/dev/null || echo "beads")
rm -rf ".beads/embeddeddolt/$DB_NAME/"     # Remove empty database
cd .beads/embeddeddolt
dolt clone git@github.com:<owner>/<repo>.git "$DB_NAME"
cd ../..
bd migrate --yes 2>/dev/null               # Apply any pending migrations
bd dolt remote add origin git+ssh://git@github.com/<owner>/<repo>.git 2>/dev/null  # May already exist
bd list                                    # Verify
```

## Path C: Fix Diverged History

**Symptom:** `bd dolt push` fails with "no common ancestor"

```bash
# Clear the stale local ref that's conflicting
git update-ref -d refs/dolt/data

# Retry push
bd dolt push
```

**If `bd dolt push` (or `--force`) fails with GitHub Push Protection:**

GitHub's secret scanner may block the push if a token (e.g., from `bd config set github.token`) is embedded in the Dolt commit history. When this happens, **do NOT try to unblock the secret** — escalate to Path F (nuke + rebuild) to create clean history without the embedded token. This is faster and safer than trying to rewrite Dolt history.

```
Error: push to origin/main: ... GH013: Repository rule violations found
       GITHUB PUSH PROTECTION — Push cannot contain secrets
```

→ **Go to Path F** (export → destroy → re-init → re-import → push clean history)

**If local data should be discarded (remote is authoritative):**

```bash
# Export local data as backup first
bd export -o /tmp/beads-backup.jsonl

# Nuclear recovery
bd dolt stop 2>/dev/null
rm -rf .beads/
bd bootstrap

# Re-import if needed
bd import /tmp/beads-backup.jsonl
```

## Path D: Database Exists but Broken

```bash
# 1. Run doctor (non-destructive diagnostics + auto-fix)
bd doctor --fix --yes

# 2. If doctor fixes it:
bd list                    # Verify

# 3. If still broken, restart the Dolt server
bd dolt stop
bd dolt start
bd list                    # Retry

# 4. If still broken, check circuit breaker
rm -f /tmp/beads-dolt-circuit-*.json
bd dolt stop
bd dolt start
bd list                    # Retry
```

## Path E: Add Remote to Existing Database

```bash
# 1. Add the remote
bd dolt remote add origin git+ssh://git@github.com/<owner>/<repo>.git

# 2. Push to establish remote
bd dolt push

# 3. Verify
git ls-remote origin | grep dolt    # Should show refs/dolt/data
```

## Path F: Corrupt Local, Remote Has Data

```bash
# 1. Export what we can (may fail if truly corrupt)
bd export -o /tmp/beads-backup.jsonl 2>/dev/null

# 2. Remove and re-bootstrap
bd dolt stop 2>/dev/null
rm -rf .beads/
bd bootstrap

# 3. Verify
bd list
bd vc log | head -5

# 4. Re-import exported data if needed
bd import /tmp/beads-backup.jsonl 2>/dev/null
```

## Configuration Validation

After any path completes, validate the configuration:

```bash
# Check config
bd config show 2>/dev/null | head -20

# Verify database name is set
grep "name:" .beads/config.yaml 2>/dev/null

# Verify remote is configured
bd dolt remote list

# Check for config drift
bd config drift 2>/dev/null
```

## Red Flags

**Never:**
- Run `bd init --force` — destroys all data
- Manually delete files inside `.dolt/` directories — causes unrecoverable corruption
- Run raw `dolt` CLI commands while bd Dolt server is running — causes journal corruption
- Assume "database not found" means data is missing — it may be a server connectivity issue

**Always:**
- Run diagnostics before taking action
- Export data before any recovery that removes `.beads/`
- Use `bd dolt ...` commands instead of raw `dolt` commands
- Distinguish "database missing" from "server can't connect" (check `bd dolt status`)
- Commit before pulling: `bd dolt commit` before `bd dolt pull`

## Lessons Learnt (Field-Validated)

These lessons come from real recovery scenarios, not theory.

### GitHub Push Protection blocks `bd dolt push --force`

**Scenario:** Diverged Dolt history → Path C (`git update-ref -d` + `bd dolt push`) fails → try `bd dolt push --force` → GitHub Push Protection blocks it because a GitHub OAuth token is embedded in the Dolt commit history (from a previous `bd config set github.token`).

**Resolution:** Do NOT try to unblock the secret via GitHub's URL. Use Path F (export → destroy → re-init → re-import) to create clean history without the embedded token. This is faster, safer, and produces a clean history.

**Prevention:** Use `GITHUB_TOKEN` env var instead of `bd config set github.token` — env vars don't get persisted into Dolt commit history.

### `bd init --force` after previous init creates diverged history

**Scenario:** Machine A pushed beads. Machine B runs `bd init --force` (or `bd init` on a fresh clone without bootstrapping), creating an independent Dolt history. Machine B's `bd dolt push` then fails with "no common ancestor".

**Resolution:** On cloned repos, always use `bd bootstrap` (not `bd init`). If divergence already happened, use Path C or Path F.

### Auto-export warning is benign when `issues.jsonl` is gitignored

**Scenario:** Every `bd` write command shows `Warning: auto-export: git add failed: exit status 1`. This is because bd v1.0.1+ auto-exports to `issues.jsonl` and tries to `git add` it, but the file is gitignored.

**Resolution:** This warning is harmless. The export still succeeds (file is written), only the `git add` step fails. No action needed.

If you discovered something reusable, capture it before closing:

```bash
# Only if worth preserving for future sessions:
bd remember "project-init: <setup pattern or recovery step>"
```

## Integration

**Called by:**
- SessionStart hook — when `bd prime` fails
- Any workflow where `bd` commands return database errors

**Pairs with:**
- **using-superpowers** — beads quick reference for post-init commands
- **finishing-a-development-branch** — Land the Plane requires working `bd dolt push`
