#!/usr/bin/env bash
# Contract test for the session-handoff skill (SKILL.md + bundled template).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/session-handoff/SKILL.md"
# shellcheck disable=SC2034  # TMPL used by Task 2 template checks (not yet added)
TMPL="$ROOT/skills/session-handoff/handoff-template.md"
fail=0

check_exact() { if grep -Fq "$1" "$2"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi; }
check_loose() { if grep -iq "$1" "$2"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi; }

# --- Frontmatter (human-only mechanism) ---
check_exact "name: session-handoff" "$SKILL"
check_exact "disable-model-invocation: true" "$SKILL"
# description must be third-person + trigger-free
desc=$(sed -n 's/^description:[[:space:]]*//p' "$SKILL" | head -1)
echo "$desc" | grep -qiE '\b(I|we|you|your|yours|our|ours|us|my|me)\b' && { echo "FAIL: desc not third-person"; fail=1; } || echo "PASS: third-person desc"
echo "$desc" | grep -qiE '\buse when\b' && { echo "FAIL: desc has trigger phrasing"; fail=1; } || echo "PASS: trigger-free desc"

# --- House conventions ---
check_loose "Announce at start" "$SKILL"
check_loose "human-invoked" "$SKILL"

# --- Pipeline phases ---
check_loose "Gather" "$SKILL"
check_loose "Synthesize" "$SKILL"
check_loose "Verification" "$SKILL"

# --- Doctrine / security floor (all 3 controls test-guarded) ---
check_loose "redact" "$SKILL"
check_loose "git check-ignore" "$SKILL"
check_loose "Secret-scan" "$SKILL"
check_loose "Reference, don't duplicate" "$SKILL"

# --- Standalone integration ---
check_loose "intentionally NOT referenced" "$SKILL"   # guards the Integration sentence

# --- Budget + ships-clean (H1) ---
lines=$(grep -c '' "$SKILL")
if [ "$lines" -lt 500 ]; then echo "PASS: <500 lines ($lines)"; else echo "FAIL: >=500 lines"; fail=1; fi
grep -nE 'ADR-[0-9]|\bbd-[a-z0-9]{4}\b|beads-superpowers-[a-z0-9]+|decisions/' "$SKILL" && { echo "FAIL: unshipped refs"; fail=1; } || echo "PASS: ships clean"
# Only .internal/handoff/ (the write-target default) is an allowed .internal/ ref
grep -nE '\.internal/' "$SKILL" | grep -v '\.internal/handoff/' && { echo "FAIL: non-handoff .internal/ ref"; fail=1; } || echo "PASS: .internal/ clean"

[ "$fail" -eq 0 ] && echo "PASS: session-handoff contract" || exit 1
