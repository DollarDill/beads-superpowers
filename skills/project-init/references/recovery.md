# project-init: Recovery Reference

Branch-only recovery content moved out of `skills/project-init/SKILL.md` — the manual
bootstrap fallback and the diverged-history / push-protection walkthrough. SKILL.md
states exactly when to open each section below.

## Path B: Manual Bootstrap Fallback

**If `bd bootstrap` fails**, use the manual fallback:

```bash
# Manual bootstrap (8 steps)
bd init --skip-agents                      # Creates empty .beads/
bd dolt stop 2>/dev/null                   # Stop server if running
DB_NAME=$(python3 -c "import json; print(json.load(open('.beads/metadata.json')).get('dolt_database','beads'))" 2>/dev/null || echo "beads")
rm -rf ".beads/embeddeddolt/$DB_NAME/"     # Remove empty database
cd .beads/embeddeddolt
dolt clone git@github.com:<owner>/<repo>.git "$DB_NAME"
cd ../..
bd migrate --yes                           # Apply pending migrations — do NOT silence stderr: on a
                                           # remote-backed clone the v1.1.0 gate may refuse; if it does,
                                           # STOP and read "The v1.1.0 remote-migrate gate" (Path C)
bd dolt remote add origin git+ssh://git@github.com/<owner>/<repo>.git 2>/dev/null  # May already exist
bd list                                    # Verify
```

## Path C: Fix Diverged History

### The v1.1.0 remote-migrate gate (read this first)

Since beads v1.1.0, `bd` refuses to silently apply pending schema migrations to a remote-backed
database (per upstream changelog v1.1.0: the provably-safe same-version case auto-migrates; anything
else stops). When the gate blocks you, pick ONE:

- **You are the designated migrator** (one machine per team, by agreement): back up first —
  `bd export --all -o backup.jsonl` — then `bd migrate --force` (the CLI twin of
  `BD_ALLOW_REMOTE_MIGRATE=1`; single designated migrator only), then `bd dolt push`.
- **Any other machine:** do NOT migrate. Adopt the already-migrated database: `bd bootstrap`.

Never set `BD_ALLOW_REMOTE_MIGRATE=1` or run `bd migrate --force` outside the designated-migrator role — independently migrated
clones fork the schema and break `bd dolt pull`. `BD_SMART_GATE=0` disables the smart gate entirely;
discouraged for the same reason.

**Observed vs documented (flagged, unresolved):** the documented position is the bright line above:
only the designated migrator forces a migration. Separately, on embedded storage bd has been
observed to auto-migrate as a "safe first-mover", which appears to contradict `bd migrate --help`
("refuses to migrate in place" on a remote-backed database with pending migrations). Not resolved
here; the flag stays and neither side is chosen. Follow the two options above.

If a pull conflicts and the auto-resolver declines it, `bd dolt pull --strategy ours|theirs`
resolves it (embedded storage only; `bd dolt pull --help`). Pick the side deliberately — the
other side's changes are discarded.

If a pull/push fails with Dolt's "cannot merge because table X has different primary keys" refusal,
bd prints the bootstrap-from-canonical recovery recipe — follow it (upstream playbook:
docs/RECOVERY.md#pk-fork-refused in gastownhall/beads). Do not improvise a manual merge.

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
# Export local data as backup first (--all includes memories, which may hold
# sensitive agent context — keep the backup in a private 0700 dir)
BACKUP="$(mktemp -d)/beads-backup.jsonl"
bd export --all -o "$BACKUP"

# Nuclear recovery
bd dolt stop 2>/dev/null     # server mode only
rm -rf .beads/
bd bootstrap

# Re-import if needed
bd import "$BACKUP"

# Only after `bd list` confirms the import, delete the backup
bd list && rm -rf "$(dirname "$BACKUP")"
```
