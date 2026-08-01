#!/usr/bin/env bash
# check-live-store-retrieval.sh — durable, numbers-free half of Task 9.
# Visible SKIP, never FAIL, when the store is unavailable OR empty. (Note: `kb
# label vocab` and `kb doc reconciliation` currently FAIL rather than SKIP in a
# bare clone — do not copy that shape.)
#
# The one property that must never regress: a multi-word query — the shape an
# agent naturally types — returns something. The exact counts are Task 9's
# one-time verify-real-store.sh measurement, not this guard's job: a number
# pinned here goes red the first time anyone adds a memory.
set -uo pipefail

if command -v bd >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && bd memories >/dev/null 2>&1; then
  # Captured, not piped straight into grep: a crashed surface.sh (Python
  # traceback, a bd failure inside it) must be reported as a crash, not
  # misattributed to a zero-hit retrieval regression.
  if out="$(bash skills/knowledge-retrieval/scripts/surface.sh "bd worktree gotchas")"; then
    n="$(printf '%s\n' "$out" | grep -c '^  [a-z0-9]' || true)"
    if [ "$n" -gt 0 ]; then
      echo "live-store retrieval: OK (multi-word query returned $n hits)"
    else
      # Zero hits is only a regression against a populated store. Read
      # emptiness off surface.sh's own coverage line (rank.py's _store())
      # instead of a second bd probe, so it comes from the same invocation
      # that produced the zero. An initialised-but-empty store must SKIP
      # here, not FAIL — this file's own note above says not to copy that
      # shape.
      mem_n="$(printf '%s\n' "$out" | grep -oE 'memories\([0-9]+\)' | grep -oE '[0-9]+' || true)"
      if [ "${mem_n:-0}" -eq 0 ]; then
        echo "SKIP: live-store retrieval check (store empty or memories unavailable)"
      else
        echo "FAIL: multi-word query returned zero against the live store"
        exit 1
      fi
    fi
  else
    echo "FAIL: surface.sh crashed against the live store (non-zero exit, not a zero-hit result)"
    exit 1
  fi
else
  echo "SKIP: live-store retrieval check (bd, python3 or store unavailable)"
fi
