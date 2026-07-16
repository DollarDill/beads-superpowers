#!/usr/bin/env bash
# check-kb-doc-reconciliation.sh — LOCAL-DEV guard: every research doc under
# .internal/research/ has a matching knowledge-bead (catches a skipped
# capture at write-time, see skills/research-driven-development), AND every
# ADR under docs/decisions/ (except entries listed in
# docs/decisions/.kb-exclusions) has a matching decision-bead. Beads are
# Dolt-synced/shared; .internal/research and docs/decisions are
# gitignored/per-machine — so this is NOT (and can never be) a CI gate.
#
# Wired into scripts/run-guards.sh (`just guards`) since bd-8o3j.8, after all
# 36 disk docs were indexed as research beads. Each corpus is gated and
# enforced independently (its own `[ -d ]` guard below) — self-SKIPs (exit 0)
# only when NEITHER corpus dir is present locally.
set -euo pipefail
DIR=".internal/research"
ADIR="docs/decisions"
EXCL="$ADIR/.kb-exclusions"
[ -d "$DIR" ] || [ -d "$ADIR" ] || { echo "SKIP: no $DIR or $ADIR (local-only)"; exit 0; }
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
# (catches a skipped capture). Own [ -d ] guard so this corpus enforces
# independently of whether $ADIR exists. nullglob so an EMPTY (but existing)
# $DIR doesn't leave the literal unexpanded glob pattern as a phantom
# filename.
if [ -d "$DIR" ]; then
  shopt -s nullglob
  for f in "$DIR"/*.md; do
    grep -qxF "$f" <<<"$beaddocs" || { echo "FAIL: no knowledge-bead for $f"; fail=1; }
  done
  shopt -u nullglob
fi

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

# ENFORCED — doc -> bead, second corpus: every ADR under docs/decisions/ has
# a decision-bead, except entries listed in docs/decisions/.kb-exclusions
# (sensitivity-parked ADRs, beads-superpowers-99pv). Own [ -d ] guard (see
# $ADIR/$EXCL set at the top) so this corpus enforces independently of
# whether $DIR exists — a decisions-only checkout still catches an orphan
# ADR. The ADR-*.md glob structurally excludes INDEX.md — no denylist
# needed. `[ -e "$f" ]` guards the case where the glob doesn't match
# anything (no nullglob active here): without it, an unmatched glob leaves
# the literal pattern string as $f.
if [ -d "$ADIR" ]; then
  for f in "$ADIR"/ADR-*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    [ -f "$EXCL" ] && grep -qxF "$base" "$EXCL" && continue   # sensitivity-parked (99pv)
    grep -qxF "$f" <<<"$beaddocs" || { echo "FAIL: no decision bead for $f"; fail=1; }
  done
fi

[ "$fail" -eq 0 ] && echo "kb-doc-reconciliation: OK (all local research docs and ADRs have knowledge-beads)"
exit "$fail"
