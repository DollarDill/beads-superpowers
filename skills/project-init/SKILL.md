---
name: project-init
description: Use when beads/Dolt database initialization fails, when bd commands return errors about missing databases, when setting up beads in a new project, or when recovering from diverged Dolt history. Handles fresh init, bootstrap from remote, and recovery workflows.
---

# Project Init: Beads/Dolt Database Setup and Recovery

> **Source:** Based on [gastownhall/beads SYNC_SETUP.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_SETUP.md)

**Announce at start:** "I'm using the project-init skill to set up or recover the beads database."

## Iron Law: NEVER Run `bd init --force`

```
NEVER run bd init --force (deprecated in v1.0.4). Use the named-intent alternatives: bd init --reinit-local (preserves remote) or bd init --discard-remote (explicit destruction).
```

**Why:** Issue #2363 documents an AI agent that destroyed 247 issues via `bd init --force` cascade. The root cause was misdiagnosing "server can't connect" as "database missing". `bd init --force` is a nuclear option that should ONLY be run by a human who explicitly types it.

This Iron Law is the Production-Grade Doctrine applied to your data ledger: never take the shortcut that accepts catastrophic, irreversible risk.

| Action | Safe? | Use When |
|--------|-------|----------|
| `bd init` | ✅ Safe | Fresh project, no existing .beads/ |
| `bd bootstrap` | ✅ Safe | Cloned repo with remote beads data |
| `bd doctor --fix --yes` | ✅ Safe | Database exists but seems broken |
| `bd init --force` | ❌ **NEVER** | **Deprecated (v1.0.4) — do NOT use** |
| `bd init --reinit-local` | ⚠️ Recovery only | Reinitialize local state, preserve remote data |
| `bd init --discard-remote` | ⚠️ Recovery only | Discard remote data and reinitialize (explicit destruction) |

## Diagnostic Phase (Always Run First)

Before taking ANY action, run diagnostics to understand the current state:

```bash
bash scripts/diagnose.sh
```

One Bash call gathers the full read-only battery as labeled RAW DATA (no verdicts, no
fixes): `bd`/`dolt` versions, `.beads/` presence, `config.yaml`/`metadata.json`, whether
`bd list`/`bd vc log` work, and any dolt refs on the git remote. Read the `== section ==`
output, then author the diagnosis yourself against the Decision Matrix below:

**Diagnosis:** <one-line read of what the sections above show>
**Path:** <A/B/C/D/E/F, from the Decision Matrix>

`bd doctor` is intentionally NOT part of the battery — `--fix --yes` can mutate. Run it only
after the diagnosis→path block above is emitted and a path is chosen (bd v1.1.0+ `bd doctor`
also flags migration-content skew vs remote; surface that before any sync work).

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

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

# After any pull: repair denormalized blocked flags (bd v1.1.0+)
bd recompute-blocked
```

**If `bd bootstrap` fails:** open `references/recovery.md` (open when bootstrap auto-detect fails) for the manual 8-step fallback.

## Path C: Fix Diverged History

Open `references/recovery.md` (open when push is rejected) for the v1.1.0 remote-migrate gate, the diverged-history fix, and the GitHub push-protection recovery.

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
- Run `bd init --force` (deprecated) — use `--reinit-local` or `--discard-remote` instead
- Manually delete files inside `.dolt/` directories — causes unrecoverable corruption
- Run raw `dolt` CLI commands while bd Dolt server is running — causes journal corruption
- Assume "database not found" means data is missing — it may be a server connectivity issue

**Always:**
- Run diagnostics before taking action
- Export data before any recovery that removes `.beads/`
- Use `bd dolt ...` commands instead of raw `dolt` commands
- Distinguish "database missing" from "server can't connect" (check `bd dolt status`)
- Commit before pulling: `bd dolt commit` before `bd dolt pull`
- After any pull: repair denormalized blocked flags — `bd recompute-blocked` (bd v1.1.0+)

## Lessons Learnt (Field-Validated)

These lessons come from real recovery scenarios, not theory.

### GitHub Push Protection blocks `bd dolt push --force`

**Scenario:** Diverged Dolt history → Path C (`git update-ref -d` + `bd dolt push`) fails → try `bd dolt push --force` → GitHub Push Protection blocks it because a GitHub OAuth token is embedded in the Dolt commit history (from a previous `bd config set github.token`).

**Resolution:** Do NOT try to unblock the secret via GitHub's URL. Use Path F (export → destroy → re-init → re-import) to create clean history without the embedded token. This is faster, safer, and produces a clean history.

**Prevention:** Use `GITHUB_TOKEN` env var instead of `bd config set github.token` — env vars don't get persisted into Dolt commit history.

### `bd init --force` after previous init creates diverged history

**Scenario:** Machine A pushed beads. Machine B runs `bd init --force` (or `bd init` on a fresh clone without bootstrapping), creating an independent Dolt history. Machine B's `bd dolt push` then fails with "no common ancestor".

**Resolution:** On cloned repos, always use `bd bootstrap` (not `bd init`). If divergence already happened, use Path C or Path F. If you need to reinitialize, use the named-intent flags introduced in v1.0.4: `bd init --reinit-local` (preserves remote data) or `bd init --discard-remote` (explicit destruction of remote data). Never use `bd init --force` (deprecated).

### Auto-export warning is benign when `issues.jsonl` is gitignored

**Scenario:** Every `bd` write command shows `Warning: auto-export: git add failed: exit status 1`. This is because bd v1.0.1+ auto-exports to `issues.jsonl` and tries to `git add` it, but the file is gitignored.

**Resolution:** This warning is harmless. The export still succeeds (file is written), only the `git add` step fails. No action needed.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## Integration

**Called by:**
- SessionStart hook — when beads context injection fails (or a manual `bd prime` fails)
- Any workflow where `bd` commands return database errors

**Pairs with:**
- **using-superpowers** — beads quick reference for post-init commands
- **finishing-a-development-branch** — Land the Plane requires working `bd dolt push`
