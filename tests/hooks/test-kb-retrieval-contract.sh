#!/usr/bin/env bash
# tests/hooks/test-kb-retrieval-contract.sh — pins the bd behaviors the beads-native
# KB store (ADR-0056) depends on. Runs against a SCRATCH bd DB (mktemp -d, outside the
# repo tree) — never the real, Dolt-synced store. A future `bd` upgrade that regresses
# any of the 5 pinned behaviors below must fail THIS test, not silently break the store.
set -euo pipefail

# Visible SKIP when bd is absent (matches the node/shellcheck SKIP convention) —
# run-hook-tests.sh treats a non-zero exit as FAIL, so guard rather than fail.
command -v bd >/dev/null 2>&1 || { echo "SKIP (bd not installed)"; exit 0; }

T=$(mktemp -d)
trap 'rm -rf "$T" 2>/dev/null || true' EXIT
bde() { bd -C "$T" "$@"; }

# --skip-agents --skip-hooks: no CLAUDE.md/AGENTS.md/git-hooks scaffolding in the
# scratch dir — this test only needs a working embedded-Dolt bd DB, nothing else.
# `bd init` must run via `cd` (subshell), NOT `bd -C <dir> init` — `-C` requires an
# EXISTING beads project to change into, so it can't bootstrap a new one (verified:
# `bd -C <empty-dir> init` fails with "no beads project found").
( cd "$T" && bd init -p kbtest --non-interactive --skip-agents --skip-hooks -q >/dev/null ) \
  || { echo "FAIL: setup — bd init failed in scratch dir (rig broken, not a bd regression)"; exit 1; }

BDVER=$(bd version)

# --- fixture: one deferred knowledge-bead, labeled kb + a topic label ---
id=$(bde create "positioning decision sample" -t decision -l kb,positioning --defer 2099-01-01 --silent)

# 1. Label query: `bd list --label <topic> --status all` returns the deferred bead.
bde list --label positioning --status all | grep -q "$id" \
  || { echo "FAIL: label query did not return $id"; exit 1; }
echo "PASS (1/5): label query finds deferred knowledge-bead"

# 2. Ready-hidden: a deferred knowledge-bead is NOT in `bd ready`.
bde ready | grep -q "$id" && { echo "FAIL: deferred bead $id appeared in bd ready"; exit 1; }
echo "PASS (2/5): deferred knowledge-bead hidden from bd ready"

# 3. GC-safety — TWO-SIDED (Branch 7, the crux). `bd gc --dry-run` (verified against
# `bd gc --help` and its --json output) reports only an aggregate per-phase COUNT for
# the decay phase, never per-issue IDs — so an ID-grep over the decay listing (as the
# task-5 pseudocode sketched) is not the real interface. The discriminating check is
# built on controlled cardinality instead: with only the deferred bead in the DB, the
# decay count must be exactly 0; after closing exactly one control bead, it must become
# exactly 1 (not 0 — the closed control must be swept; not 2 — the deferred bead must
# not be). No `|| true` anywhere near these two assertions.
decay_count() {
  bde gc --dry-run --older-than 0 --skip-dolt 2>&1 | grep -oE 'Decay: [0-9]+' | grep -oE '[0-9]+'
}

before=$(decay_count)
[ "$before" = "0" ] \
  || { echo "FAIL: decay set non-empty before any closed bead exists (got $before, want 0) — deferred bead is leaking into GC"; exit 1; }

closed=$(bde create "closed control" -t task --silent)
bde close "$closed" --reason ctl >/dev/null
# `--older-than 0` compares closed_at against a same-second cutoff; a bead closed in the
# same wall-clock second as the gc check can race the cutoff and be excluded (verified
# empirically: 3/3 runs showed decay=0 with no sleep, 3/3 showed decay=1 with sleep 1).
sleep 1
after=$(decay_count)
[ "$after" = "1" ] \
  || { echo "FAIL: decay set did not isolate the closed control (got $after, want 1) — either the deferred bead leaked into GC or the closed control was skipped"; exit 1; }
echo "PASS (3/5): GC-safety two-sided (before=$before after=$after) — deferred bead survives decay, closed control does not"

# 4. Supersede: `bd supersede <old> --with <new>` closes+links the old bead, and it
# stays queryable via --status all (the KB store's edit-in-place path).
new=$(bde create "positioning reconsider" -t decision -l kb,positioning --defer 2099-01-01 --silent)
bde supersede "$id" --with "$new" >/dev/null
bde list --label positioning --status all | grep -q "$id" \
  || { echo "FAIL: superseded bead $id no longer queryable via --status all"; exit 1; }
echo "PASS (4/5): supersede closes+links old bead, still queryable via --status all"

# 5. Search: `bd search <kw> --status all` finds the bead by keyword.
bde search "positioning decision" --status all | grep -q "$id" \
  || { echo "FAIL: search did not find $id"; exit 1; }
echo "PASS (5/5): search finds knowledge-bead by keyword"

echo "PASS: KB retrieval contract — all 5 behaviors pinned [$BDVER]"
