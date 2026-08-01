#!/usr/bin/env bash
# check-live-store-retrieval.sh — durable, numbers-free half of Task 9.
# Visible SKIP, never FAIL, when the store is unavailable. (Note: `kb label
# vocab` and `kb doc reconciliation` currently FAIL rather than SKIP in a bare
# clone — do not copy that shape.)
#
# The one property that must never regress: a multi-word query — the shape an
# agent naturally types — returns something. The exact counts are Task 9's
# one-time verify-real-store.sh measurement, not this guard's job: a number
# pinned here goes red the first time anyone adds a memory.
set -uo pipefail

if command -v bd >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && bd memories >/dev/null 2>&1; then
  n="$(bash skills/knowledge-retrieval/scripts/surface.sh "bd worktree gotchas" | grep -c '^  [a-z]' || true)"
  [ "$n" -gt 0 ] || { echo "FAIL: multi-word query returned zero against the live store"; exit 1; }
  echo "live-store retrieval: OK (multi-word query returned $n hits)"
else
  echo "SKIP: live-store retrieval check (bd, python3 or store unavailable)"
fi
