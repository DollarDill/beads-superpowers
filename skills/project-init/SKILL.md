---
name: project-init
description: Use when beads/Dolt database initialization fails, when bd commands return errors about missing databases, when setting up beads in a new project, or when recovering from diverged Dolt history. Handles fresh init, bootstrap from remote, and recovery workflows.
---

# Project Init: Beads/Dolt Database Setup and Recovery

<!-- Based on gastownhall/beads docs/SYNC_SETUP.md (MIT). Attribution: README "Built on". -->

**Announce at start:** "I'm using the project-init skill to set up or recover the beads database."

## Iron Law: NEVER Run `bd init --force`

```
NEVER run bd init --force (deprecated in v1.0.4). Use the named-intent alternatives: bd init --reinit-local (preserves remote) or bd init --discard-remote (explicit destruction).
```

## Version floor: bd v1.3.1 minimum. NEVER install v1.2.0 or v1.2.1

**Minimum supported: bd v1.3.1.** Check with `bd version` before any init, bootstrap or
recovery — including on a machine you are only *adding* to an existing setup.

**Upgrading from an older bd:** back up first with the bd you have now (after upgrading, `bd export`
auto-migrates before exporting), and finish `bd dolt push/pull` before installing — remote-backed
stores keep the designated-migrator gate, and push/pull are refused until the store is migrated
(beads CHANGELOG [1.3.0] upgrade notes).

- **v1.1.2 and v1.2.2 are unsupported — upgrade.** Skills assume the 1.3-only flags
  `--merged-into`, `bd heartbeat`, `--destroy-token`, `migrate --force` and `dolt pull --strategy`,
  and a remote migrated by 1.3.x is unreadable by older bd.
- **v1.3.0 — upgrade.** Its smart-migrate gate can wedge ([beads #6575](https://github.com/gastownhall/beads/issues/6575)); fixed in v1.3.1.
- **v1.2.0 and v1.2.1 remain poisoned.** They were published by accident on 2026-08-11 without
  release testing and are retracted in `go.mod`. Running either **once** migrates the local Dolt
  schema **v53 → v65**, after which every other bd binary refuses to start with `schema version
  mismatch: database is at v65, binary knows up to v53`.

If it has already happened: upgrade **every** machine and clone to v1.3.1 *first* — a
leftover 1.2.1 binary silently re-migrates — then follow
the [upstream runbook](https://beads.gascity.com/recovery/accidental-1-2-1-release)
(roll the schema cursor back to v53; `BD_IGNORE_SCHEMA_SKEW=1 bd <command>` is a verified stopgap).

The first bd command after upgrading runs the in-place v53→v66 schema migration — run any bd command once in a terminal before starting an agent session.

**Why:** Issue #2363 documents an AI agent that destroyed 247 issues via `bd init --force` cascade. The root cause was misdiagnosing "server can't connect" as "database missing". `bd init --force` is a nuclear option that should ONLY be run by a human who explicitly types it.

This Iron Law is the Production-Grade Doctrine applied to your data ledger: never take the shortcut that accepts catastrophic, irreversible risk.

| Action | Safe? | Use When |
|--------|-------|----------|
| `bd init` | ✅ Safe | Fresh project, no existing .beads/ |
| `bd bootstrap` | ✅ Safe | Cloned repo with remote beads data |
| `bd doctor --fix --yes` | ✅ Safe (server mode only) | Database exists but seems broken; embedded: see Path D's embedded branch |
| `bd init --force` | ❌ **NEVER** | **Deprecated (v1.0.4) — do NOT use** |
| `bd init --reinit-local` | ⚠️ Recovery only | Reinitialize local state, preserve remote data |
| `bd init --discard-remote` | ⚠️ Recovery only | Discard remote data and reinitialize (explicit destruction); requires `--destroy-token DESTROY-<prefix>` non-interactively |

## Diagnostic Phase (Always Run First)

Before taking ANY action, run diagnostics to understand the current state:

```bash
bash scripts/diagnose.sh
```

One Bash call gathers the full read-only battery as labeled RAW DATA (no verdicts, no
fixes): `bd`/`dolt` versions, `.beads/` presence, `config.yaml`/`metadata.json`, whether
`bd list`/`bd vc status` work, and any dolt refs on the git remote. Read the `== section ==`
output, then author the diagnosis yourself against the Decision Matrix below:

**Diagnosis:** <one-line read of what the sections above show>
**Path:** <A/B/C/D/E/F, from the Decision Matrix>

Done when: both lines above are written and a single path letter is chosen.

`bd doctor` is intentionally NOT part of the battery — `--fix --yes` can mutate. Run it only
after the diagnosis→path block above is emitted and a path is chosen (bd v1.1.0+ `bd doctor`
also flags migration-content skew vs remote; surface that before any sync work).

## Decision Matrix

Based on diagnostic results, follow the appropriate path. "Remote" below always means
the configured beads remote (`bd dolt remote list`) — independent of the code repo's
git origin; see "Multi-Repo / Private Beads Remote" below.

| State | Action | Path |
|-------|--------|------|
| No .beads/, no remote data | Fresh init | → Path A |
| No .beads/, remote has dolt refs | Bootstrap from remote | → Path B |
| .beads/ exists, `bd list` works, beads remote matches | Already good ✅ | Done |
| .beads/ exists, `bd list` fails | Server mode: `bd doctor --fix --yes`; embedded: Path D's embedded branch | → Path D |
| .beads/ exists, `bd list` works, no beads remote configured | Add remote | → Path E |
| .beads/ exists, push fails "no common ancestor" | Fix diverged history | → Path C |
| .beads/ exists but empty/corrupt, remote has data | Export + re-bootstrap | → Path F |

## Path A: Fresh Initialization (New Project)

```bash
# 1. Initialize beads (--skip-agents: this plugin already supplies the agent context)
bd init --skip-agents

# 2. Verify
bd list                    # Should work (empty is fine)
bd create "Test bead" -t task -p 4
bd list                    # Should show the test bead
bd close <test-id> --reason "Init verification"

# 3. Add remote (if syncing) — RECOMMENDED: a dedicated beads remote (private for public projects),
#    separate from the code repo (ADR-0057; bd v1.3.0+ refuses a code-repo URL without --allow-git-origin)
bd dolt remote add origin git+ssh://git@github.com/<owner>/<repo>-beads.git

# 4. First push
bd dolt push
```

**Note:** `bd init` (v1.3.0+) writes and git-adds agent files (`.cursor/`, `.agents/skills/beads/`,
`.claude/settings.json` hooks); this plugin already supplies the context, so pass `--skip-agents`.
If they already exist, the session-start notice names the remedy.

Done when: `bd list` shows the test bead created and closed, and (if a remote was added) `bd dolt push` succeeds.

## Path B: Bootstrap from Remote (Cloned Repo)

```bash
# 1. Bootstrap (auto-detects remote dolt data)
bd bootstrap

# 2. Verify
bd list                    # Should show existing issues
bd vc status               # Should show branch + commit hash

# After any pull: repair denormalized blocked flags (bd v1.1.0+)
bd recompute-blocked
```

**If `bd bootstrap` fails:** open `references/recovery.md` (open when bootstrap auto-detect fails) for the manual 8-step fallback.

## Path C: Fix Diverged History

Open `references/recovery.md` (open when push is rejected) for the v1.1.0 remote-migrate gate, the diverged-history fix, and the GitHub push-protection recovery.

## Path D: Database Exists but Broken

Check `dolt_mode` in `.beads/metadata.json` first. Embedded is the default.

**Server mode:**

```bash
# 1. Run doctor (non-destructive diagnostics + auto-fix) — server mode only
bd doctor --fix --yes

# 2. If doctor fixes it:
bd list                    # Verify

# 3. If still broken, restart the Dolt server (server mode only)
bd dolt stop
bd dolt start
bd list                    # Retry

# 4. If still broken, check circuit breaker (server mode only)
rm -f /tmp/beads-dolt-circuit-*.json
bd dolt stop
bd dolt start
bd list                    # Retry
```

**Embedded mode (default):** full `bd doctor` diagnostics need server mode (`bd doctor --help`:
embedded supports only `--check=artifacts`, `--check=conventions`, `--check=pollution`). Run those,
then check state:

```bash
bd doctor --check=artifacts
bd doctor --check=conventions
bd doctor --check=pollution
bd vc status
bd list                    # Retry
```

If `bd list` still fails: Path F when the remote has data, otherwise Path B.

## Path E: Add Remote to Existing Database

```bash
# 1. Add the remote — RECOMMENDED: a dedicated beads remote (private for public projects),
#    separate from the code repo (ADR-0057; bd v1.3.0+ refuses a code-repo URL without --allow-git-origin)
bd dolt remote add origin git+ssh://git@github.com/<owner>/<repo>-beads.git

# 2. Push to establish remote
bd dolt push

# 3. Verify
git ls-remote git+ssh://git@github.com/<owner>/<repo>-beads.git | grep dolt    # Should show refs/dolt/data
```

## Path F: Corrupt Local, Remote Has Data

```bash
# 1. Export what we can (may fail if truly corrupt). --all includes memories,
#    which may hold sensitive agent context — keep the backup in a private (0700) dir
#    under $HOME, at a literal path (each step may run in a fresh shell).
install -d -m 700 ~/.beads-recovery
bd export --all -o ~/.beads-recovery/backup.jsonl 2>/dev/null

# 2. Remove and re-bootstrap
bd dolt stop 2>/dev/null     # server mode only
rm -rf .beads/
bd bootstrap

# 3. Verify
bd list
bd vc status

# 4. Re-import exported data if needed (no 2>/dev/null — a failed import must be visible)
bd import ~/.beads-recovery/backup.jsonl

# 5. Verify the restore
bd list
bd memories

# 6. Delete the backup as a separate step, only after `bd list` and `bd memories` show the restored issues and memories
rm -f ~/.beads-recovery/backup.jsonl
```

## Multi-Repo / Private Beads Remote

The Dolt remote is independent of the code repo's git origin — point it anywhere.
**Choose a dedicated beads remote (a separate, private git repo) when:** the code repo
is public and beads will hold anything non-public (strategy, unreleased plans, candid
notes) — Dolt history retains deleted rows, so "public remote" means the full history
is public. **Same-repo is an explicit opt-in** for private/throwaway projects (bd
v1.3.0+ refuses a `bd dolt remote add` URL matching the git origin without
`--allow-git-origin`).

**Setup (existing local database):**

A brand-new private repo must have an initial branch/commit **before** the first
`bd dolt push` — an empty repo has no branches, and Dolt's git-remotes backend fails
with "git remote has no branches" against it. Create it with an initial commit first:

```bash
gh repo create <owner>/<project>-beads --private --add-readme
```

Then add the remote and push:

```bash
bd dolt remote add origin git+ssh://git@github.com/<owner>/<project>-beads.git
bd dolt push
```

**New-machine bootstrap (VALIDATED):**

```bash
bd init --non-interactive --skip-agents --prefix <prefix> --remote "git+ssh://git@github.com/<owner>/<project>-beads.git"
```

This clones the database from the dedicated private remote in one step and persists
`sync.remote` — no separate `bd bootstrap` needed (live rehearsal: hydrated 1,854
records with the private remote correctly wired).

⚠️ **Zero-remote trap (bd v1.1.0–v1.2.2):** with NO Dolt remote configured, `bd dolt push`
silently adopts the git origin. On v1.3.0+ adoption prompts and fails closed non-interactively
(`--no-adopt` / `BD_NO_REMOTE_ADOPT=1` disables it). Never leave zero-remote as a resting state — when
swapping remotes, always chain the change in one command:
`bd dolt remote remove origin && bd dolt remote add origin <url>`.

⚠️ **Verify after swapping remotes:** `bd dolt remote remove` can leave the old value
commented out in `.beads/config.yaml`, and `bd dolt remote add` doesn't always rewrite
`sync.remote` to match. After swapping, confirm:

```bash
grep "sync.remote" .beads/config.yaml
```

If it still shows the old (or code-repo) URL, fix it directly:

```bash
bd config set sync.remote "git+ssh://git@github.com/<owner>/<project>-beads.git"
```

**Collision guard (bd v1.3.0+):** `bd dolt remote add` refuses a URL that matches the git
origin unless `--allow-git-origin` is passed — making same-repo an explicit opt-in rather than an
accident.

**`bd serve` (v1.3.0+):** an HTTP API for automation clients; it refuses embedded mode and needs
server or proxied mode. Embedded is bd's default and the plugin works in every mode, so skip
this unless you run a server. Caveats: no TLS; a token grants the whole surface including
destructive `issues:delete` / `issues:sweep`; `actor` is caller-asserted, not authenticated;
hooks do not fire on HTTP writes; `--allow-non-loopback` requires `--auth-token-file`
(`bd serve --help`; beads CHANGELOG v1.3.1 L272-274 for the embedded refusal, L1792 and L2416 for the
token and `issues:delete` surface).

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

**`bd backup`:** bare `bd backup` takes no backup — it prints help and exits 0 (beads CHANGELOG v1.3.0 upgrade notes, L801). Configure with
`bd backup init <path-or-dolthub-url>`, then `bd backup sync`. Embedded auto-backup is on when a
git remote exists. A `bd backup sync` that fails after upgrading means the backup is already in
the manifest-ahead state and has to be re-seeded (beads CHANGELOG v1.3.1: "backups already in the
manifest-ahead state are not repaired by upgrading").

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

**Capture what you learned.** At close, record durable, evidence-backed insights (still true next month, tied to a file, test, or command). Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update in place (`bd remember --key <key>`) rather than adding a near-duplicate.

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
