#!/usr/bin/env bash
# Contract test for getting-up-to-speed — pins INVARIANTS, not prose (ADR-0049 / stress-test B5).
# KEEP: behavioral output-contract strings + hard-won mechanics markers (mu0s fixes).
# Never add prose-structure assertions (section headings, narrative wording).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/getting-up-to-speed/SKILL.md"
EDGE="$ROOT/skills/getting-up-to-speed/references/edge-cases.md"
fail=0

check_exact() {  # fixed-string, must be present
  if grep -Fq "$1" "$2"; then echo "PASS: $1"; else echo "FAIL: missing — $1 ($2)"; fail=1; fi
}

# --- Behavioral output contract (what the user sees) ---
check_exact "I'm ready for your next instruction" "$SKILL"
check_exact "Do NOT auto-claim" "$SKILL"
check_exact "Archived consumed handoff" "$SKILL"
check_exact "left in inbox" "$SKILL"
check_exact "Current State" "$SKILL"
check_exact "Recent Activity" "$SKILL"

# --- Hard-won mechanics markers (mu0s recency + consume-on-read; prune consent) ---
check_exact "is-ancestor" "$SKILL"
check_exact "possibly stale" "$SKILL"
check_exact ".internal/handoff/archive" "$SKILL"
check_exact "predates HEAD" "$SKILL"
check_exact "key prefix" "$SKILL"
check_exact "never guess-delete" "$SKILL"
check_exact "Pruned N superseded continuation pointers" "$SKILL"

# --- Consent + secrets guardrails (security floor: must stay inline) ---
check_exact "FORBIDDEN" "$SKILL"
check_exact "never echo doc body sections that could carry secrets" "$SKILL"
check_exact "never bare \`bd memories\`" "$SKILL"

# --- Scale band (Heavy threshold current, stale band gone) ---
check_exact "> 150" "$SKILL"
if grep -Fq -- "> 500" "$SKILL"; then echo "FAIL: stale > 500 band"; fail=1; else echo "PASS: no stale > 500"; fi

# --- Branch-only reference shipped + pointed at ---
if [ -f "$EDGE" ]; then echo "PASS: edge-cases reference exists"; else echo "FAIL: references/edge-cases.md missing"; fail=1; fi
check_exact "references/edge-cases.md" "$SKILL"
check_exact "possibly stale" "$EDGE"

[ "$fail" -eq 0 ] && echo "PASS: getting-up-to-speed contract" || exit 1
