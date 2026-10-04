#!/usr/bin/env bash
# tests/skills/test-project-init-contract.sh — run: bash tests/skills/test-project-init-contract.sh
set -euo pipefail
R="$(cd "$(dirname "$0")/../.." && pwd)/skills/project-init"
F="$R/SKILL.md"; REC="$R/references/recovery.md"
fail=0
pin() { grep -qF -- "$1" "${2:-$F}" || { echo "FAIL: missing: $1"; fail=1; }; }
absent() { if grep -qF -- "$1" "${2:-$F}"; then echo "FAIL: still present: $1"; fail=1; fi; }
# CHANGE-DETECTOR — bd v1.3.1 minimum (0.17.0 U3)
pin '## Version floor: bd v1.3.1 minimum. NEVER install v1.2.0 or v1.2.1'
pin '**Minimum supported: bd v1.3.1.**'
pin 'The first bd command after upgrading runs the in-place v53→v66 schema migration — run any bd command once in a terminal before starting an agent session.'
pin '--skip-agents'
pin '--destroy-token'
pin '--check=artifacts'
pin 'bd serve'
pin '--auth-token-file'
pin 'caller-asserted'
pin 'bd migrate --force' "$REC"
pin '--strategy ours|theirs' "$REC"
# KERNEL_MAP pin
pin 'Iron Law: NEVER Run'
# absence-of-defect — superseded text gone
absent 'Safe versions: v1.1.2 or v1.2.2'
absent 'forward-compat'
absent 'releases after 1.1.0'
absent 'releases after v1.1.0'
# shellcheck disable=SC2016  # pins are literal shell text, not expansions
for f in "$F" "$REC"; do
  # one LITERAL private path — agents run each step in a fresh shell, so no variable survives
  pin 'install -d -m 700 ~/.beads-recovery' "$f"
  pin 'bd export --all -o ~/.beads-recovery/backup.jsonl' "$f"
  pin 'bd import ~/.beads-recovery/backup.jsonl' "$f"
  # the delete is its own bare line, run only after bd list + bd memories show the restore
  grep -qxF -- 'rm -f ~/.beads-recovery/backup.jsonl' "$f" || { echo "FAIL: missing bare line: rm -f ~/.beads-recovery/backup.jsonl ($f)"; fail=1; }
  pin 'only after `bd list` and `bd memories` show the restored issues and memories' "$f"
  # `bd list` succeeds after re-bootstrap even when the import failed — never gate the delete on it
  absent 'bd list && rm -f' "$f"
  absent 'bd import ~/.beads-recovery/backup.jsonl 2>/dev/null' "$f"
  # an empty $BACKUP made `rm -rf "$(dirname "$BACKUP")"` expand to `rm -rf .`
  absent 'rm -rf "$(' "$f"
  absent 'dirname "$BACKUP"' "$f"
  absent 'BACKUP=' "$f"
  absent '/tmp/beads-backup.jsonl' "$f"
  absent 'bd export -o' "$f"
  # a corrupt-DB export is EXPECTED to fail: hiding it let a stale backup from an earlier
  # recovery (another project's, even) survive and be imported — clear it BEFORE the export
  absent 'backup.jsonl 2>/dev/null' "$f"
  pin 'import ONLY if step 1' "$f"
  rm_first=$(grep -nxF -- 'rm -f ~/.beads-recovery/backup.jsonl' "$f" | head -n1 | cut -d: -f1 || true)
  rm_last=$(grep -nxF -- 'rm -f ~/.beads-recovery/backup.jsonl' "$f" | tail -n1 | cut -d: -f1 || true)
  exp=$(grep -nF -- 'bd export --all -o ~/.beads-recovery/backup.jsonl' "$f" | head -n1 | cut -d: -f1 || true)
  imp=$(grep -nF -- 'bd import ~/.beads-recovery/backup.jsonl' "$f" | head -n1 | cut -d: -f1 || true)
  if [ -z "$rm_first" ] || [ -z "$exp" ] || [ -z "$imp" ] || [ "$rm_first" -ge "$exp" ] || [ "$rm_last" -le "$imp" ]; then
    echo "FAIL: order: stale-backup rm -f must precede the export, and the final rm -f must follow the import ($f)"; fail=1
  fi
done
# I3 — the designated-migrator backup holds memories: never in the repo root (CWD)
absent '-o backup.jsonl' "$REC"
pin 'install -d -m 700 ~/.beads-recovery && bd export --all -o ~/.beads-recovery/pre-migrate.jsonl' "$REC"
pin 'rm -f ~/.beads-recovery/pre-migrate.jsonl' "$REC"
# M1 — DB_NAME set on a previous line is empty in a fresh shell: rm -rf would hit all of embeddeddolt/
# shellcheck disable=SC2016  # pins are literal shell text, not expansions
{ pin 'rm -rf ".beads/embeddeddolt/${DB_NAME:?' "$REC"
  absent 'rm -rf ".beads/embeddeddolt/$DB_NAME/"' "$REC"; }
# M2 — manual bootstrap uses the dedicated beads remote, and the collision-guard refusal stays visible
absent '<owner>/<repo>.git' "$REC"
if grep -E 'bd dolt remote add.*2>/dev/null' "$REC" >/dev/null; then echo "FAIL: still present: bd dolt remote add … 2>/dev/null"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: project-init contract" || exit 1
