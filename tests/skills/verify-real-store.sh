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

S="$(cd "$(dirname "$0")/../.." && pwd)/skills/knowledge-retrieval/scripts/surface.sh"
fail=0

for q in "bd worktree gotchas" "memory salience"; do
  n="$(bash "$S" "$q" | grep -c '^  [a-z]' || true)"
  echo "multi-word '$q' -> $n hits"
  [ "$n" -gt 0 ] || { echo "FAIL: multi-word query returned zero"; fail=1; }
done

echo "--- salience query (baseline: naive bd memories returned 144-148 header-only false positives) ---"
bash "$S" salience | head -8

echo "--- worktree top-5 (expect the salience-3 gotchas present) ---"
bash "$S" worktree | grep -q "worktree-creation-gotchas" \
  || { echo "FAIL: a salience-3 gotcha dropped out of the top-5"; fail=1; }

exit "$fail"
