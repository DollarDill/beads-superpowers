#!/usr/bin/env bash
# Contract test for getting-up-to-speed Phase-4 output contract.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/getting-up-to-speed/SKILL.md"
fail=0

check_exact() {  # behavioral output string — fixed-string, must be present
  if grep -Fq "$1" "$SKILL"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi
}
check_loose() {  # structural header — case-insensitive substring, must be present
  if grep -iq "$1" "$SKILL"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi
}

# Behavioral contract strings — exact
check_exact "I'm ready for your next instruction"
check_exact "Do NOT auto-claim"
# Structural headers — loose (ASCII substrings, no em-dash/parenthetical)
check_loose "Phase 4"
check_loose "Current State"
check_loose "Recent Activity"
check_loose "Verification Gate"
check_loose "Output Contract"
# Band rescale (Change 2) — new Heavy threshold present, old > 500 gone
check_loose "> 150"
if grep -Fq -- "> 500" "$SKILL"; then echo "FAIL: stale > 500 band threshold present"; fail=1; else echo "PASS: no stale > 500 threshold"; fi

# Handoff read (Change 1)
check_loose "Session-handoff doc"
check_loose "Last handoff"
check_loose "ls -t .internal/handoff"
check_loose "Headline-only"

# Continuation prune (Change 3)
check_loose "superseded continuation"
check_loose "key prefix"
check_loose "memory-curator"
check_loose "never guess-delete"

# Recency backstop (mu0s fix — Task 1)
check_loose "possibly stale"
check_loose "is-ancestor"
check_loose "older unread handoff"
check_loose "recency"
check_loose "predates HEAD"   # locks the terminal-line suppression narration

[ "$fail" -eq 0 ] && echo "PASS: getting-up-to-speed contract" || exit 1
