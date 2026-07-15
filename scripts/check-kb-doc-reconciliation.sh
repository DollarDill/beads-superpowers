#!/usr/bin/env bash
# check-kb-doc-reconciliation.sh — LOCAL-DEV guard: every research doc under
# .internal/research/ has a matching knowledge-bead (catches a skipped
# capture at write-time, see skills/research-driven-development). Beads are
# Dolt-synced/shared; .internal/research docs are gitignored/per-machine — so
# this is NOT (and can never be) a CI gate.
#
# NOT YET wired into scripts/run-guards.sh or justfile `just guards` — that
# wiring is deliberately deferred to Task 9 (the research-doc migration).
# Wiring it now would fail `just guards` on every not-yet-migrated doc in any
# checkout that already has a populated .internal/research/.
set -euo pipefail
DIR=".internal/research"
[ -d "$DIR" ] || { echo "SKIP: no $DIR (local-only)"; exit 0; }
fail=0

# Query up front so we can distinguish a genuine 'bd' failure (corrupt/locked/
# unavailable DB) from a genuinely empty store — swallowing stderr into an
# empty read loop would print a false "OK". --limit 0 = unlimited: the default
# --limit 50 would silently skip beads past the 50th, leaving the enforcement
# incomplete.
if ! rows=$(bd list --label kb --status all --limit 0 --json); then
  echo "kb-doc-reconciliation: ERROR — 'bd list' query failed; cannot verify doc<->bead reconciliation" >&2
  exit 2
fi
beaddocs=$(jq -r '.[].metadata.doc // empty' <<<"$rows")

# ENFORCED — doc -> bead: every LOCAL research doc has a knowledge-bead
# (catches a skipped capture). nullglob so an EMPTY (but existing) $DIR
# doesn't leave the literal unexpanded glob pattern as a phantom filename.
shopt -s nullglob
for f in "$DIR"/*.md; do
  grep -qxF "$f" <<<"$beaddocs" || { echo "FAIL: no knowledge-bead for $f"; fail=1; }
done
shopt -u nullglob

# WARN-ONLY — bead -> doc: a bead pointing at a doc absent locally is
# EXPECTED (docs are per-machine) — never fails. Scoped to PATH-SHAPED
# metadata.doc values only: real doc paths contain a '/'
# (.internal/research/foo.md, docs/decisions/ADR-x.md); the kv->beads
# migration also stores opaque bead-id / kv-key refs verbatim (e.g. '4l5v',
# 'aniv', 'beads-superpowers-c2m6'), which are NOT filesystem paths — a bare
# `[ -f "4l5v" ]` is false forever and would emit a false WARN every run,
# indistinguishable from the genuine "doc exists in a bead but isn't synced
# to this machine" case this WARN exists to catch.
while read -r d; do
  [ -z "$d" ] && continue
  case "$d" in
    */*) [ -f "$d" ] || echo "warn: bead doc not present locally: $d" ;;
    *)   : ;;   # opaque ref (bead-id/kv-key), not a path — nothing to reconcile
  esac
done <<<"$beaddocs"

[ "$fail" -eq 0 ] && echo "kb-doc-reconciliation: OK (all local research docs have knowledge-beads)"
exit "$fail"
