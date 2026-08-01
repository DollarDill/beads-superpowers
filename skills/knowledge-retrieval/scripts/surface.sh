#!/usr/bin/env bash
# surface.sh — bd interface for the knowledge-retrieval skill.
# Queries are passed as ARGV ONLY, never interpolated into a command string:
# the 3-8 keyword expansion is the model inventing search strings, so an
# interpolated query is an execution primitive, not a theoretical risk.
# Reads only — this script never writes, re-scores, prunes or mutates a store.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$#" -gt 0 ] || { echo "usage: surface.sh <query...>" >&2; exit 2; }

if ! command -v bd >/dev/null 2>&1; then
  echo "searched: memories(SKIP) beads(SKIP) — bd absent"; exit 0
fi

# Each bd call's exit status is captured separately. Falling back to an empty
# document set WITHOUT recording the failure would print a bd error as
# "memories(0)" — indistinguishable from an empty store, which is precisely the
# silent partial the coverage line exists to prevent (orient.sh:29-33).
degraded=""
if ! mem="$(bd memories --json 2>/dev/null)"; then
  mem='{}'; degraded="memories"
fi
# -n 0 is mandatory: a captured lesson records bd list defaulting to --limit 50
# (v1.1.0). It did NOT reproduce on v1.1.2 (232 returned either way), but silent
# truncation is the exact failure this design exists to prevent, and the existing
# guard scripts already pass it. Costs nothing; immune to version/flag drift.
if ! beads="$(bd list --label kb --status all -n 0 --json 2>/dev/null)"; then
  beads='[]'; degraded="${degraded:+$degraded,}beads"
fi

if ! command -v python3 >/dev/null 2>&1; then
  # Visible degradation, never a silent partial (orient.sh:29-33).
  # BODIES ARE WITHHELD: redact() lives in rank.py, so without python3 there is
  # no redaction. A floor with a bypass is not a floor — print keys only and let
  # the agent `bd recall <key>` deliberately, at the same trust boundary as today.
  echo "searched: memories(DEGRADED) beads(SKIPPED)"
  echo "ranking requires python3 — matching keys only, bodies withheld (redaction unavailable)"
  # "$1", not "$*": bd substring-matches the whole phrase, so a joined multi-word
  # query returns zero. || true because a no-match grep must not turn this
  # deliberate degradation into a failed exit under pipefail.
  bd memories "$1" 2>/dev/null | grep -E '^  [a-z0-9-]+$' | head -20 || true
  exit 0
fi

# NUL-separated so no field can be confused with another: memories JSON, beads
# JSON, then the comma-separated names of any store bd failed to return.
printf '%s\0%s\0%s' "$mem" "$beads" "$degraded" | python3 "$HERE/rank.py" --stdin "$@"
