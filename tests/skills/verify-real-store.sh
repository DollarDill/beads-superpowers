#!/usr/bin/env bash
# verify-real-store.sh — one-time reproduction of the design spec's measured
# claims against the live memory + knowledge-bead store (Task 9).
#
# Opt-in, always: run-contracts.sh globs tests/skills/*.sh unconditionally
# (no exclusion mechanism) and `just check` runs contracts, so this must SKIP
# by default or its numbers — which move every time anyone adds a memory —
# would go red on the next commit and get "fixed" by editing the number. Set
# BSP_VERIFY_REAL_STORE=1 to actually run it. Visible SKIP, never silent.
set -euo pipefail

if [ "${BSP_VERIFY_REAL_STORE:-}" != "1" ]; then
  echo "SKIP: verify-real-store (set BSP_VERIFY_REAL_STORE=1 to run against the live store)"
  exit 0
fi
command -v bd >/dev/null 2>&1 || { echo "SKIP: verify-real-store (bd absent)"; exit 0; }
# Without python3, surface.sh falls through to its degraded key-only path and
# rank.py never runs — a pass here would report the headline criterion met
# while the ranker itself was never exercised.
command -v python3 >/dev/null 2>&1 || { echo "SKIP: verify-real-store (python3 absent)"; exit 0; }

S="$(cd "$(dirname "$0")/../.." && pwd)/skills/knowledge-retrieval/scripts/surface.sh"
fail=0

for q in "bd worktree gotchas" "memory salience"; do
  # Captured, not piped straight into grep: a crashed surface.sh (Python
  # traceback, a bd failure) must be reported as a crash, not misread as a
  # zero-hit retrieval regression.
  if out="$(bash "$S" "$q")"; then
    n="$(printf '%s\n' "$out" | grep -c '^  [A-Za-z0-9._-]' || true)"
    echo "multi-word '$q' -> $n hits"
    [ "$n" -gt 0 ] || { echo "FAIL: multi-word query '$q' returned zero hits"; fail=1; }
  else
    echo "FAIL: surface.sh crashed for query '$q' (non-zero exit, not a zero-hit result)"
    fail=1
  fi
done

echo "--- salience query (baseline: naive bd memories returned 144-148 header-only false positives) ---"
if sal="$(bash "$S" salience)"; then
  printf '%s\n' "$sal" | sed -n '1,8p'
  # A header-only false positive is a hit whose only match lies inside the
  # leading @type=/@salience=/@created=/@refs=/@tags= block. strip_header()
  # removes exactly that block before indexing, so it can only reappear in a
  # printed hit if strip_header regresses — assert that trip-wire directly
  # instead of printing eight lines nobody checks.
  hdr="$(printf '%s\n' "$sal" | grep -cE '@(type|salience|created|refs|tags)=' || true)"
  echo "header-only false positives (leaked @key=value marker in a printed hit): $hdr"
  [ "$hdr" -eq 0 ] || { echo "FAIL: header content leaked into a printed hit"; fail=1; }
else
  echo "FAIL: surface.sh crashed for query 'salience' (non-zero exit)"
  fail=1
fi

echo "--- worktree top-5 (expect all three salience-3 gotchas present) ---"
if wt="$(bash "$S" worktree)"; then
  printf '%s\n' "$wt"
  present=0
  for k in lesson-bd-worktree-creation-gotchas \
           lesson-never-use-raw-git-worktree-commands-always \
           worktree-gitignored-files-absent; do
    if printf '%s\n' "$wt" | grep -q "$k"; then
      present=$((present + 1))
    else
      echo "MISSING: salience-3 gotcha '$k' not in the top-5"
    fi
  done
  echo "salience-3 gotchas present in top-5: $present/3"
  [ "$present" -eq 3 ] || { echo "FAIL: not all three salience-3 gotchas are in the worktree top-5 (see beads-superpowers-eo9z2.14)"; fail=1; }
else
  echo "FAIL: surface.sh crashed for query 'worktree' (non-zero exit)"
  fail=1
fi

exit "$fail"
