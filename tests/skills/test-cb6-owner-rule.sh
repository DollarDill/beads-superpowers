#!/usr/bin/env bash
# tests/skills/test-cb6-owner-rule.sh — run: bash tests/skills/test-cb6-owner-rule.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
U="$ROOT/skills/using-superpowers/SKILL.md"; C="$ROOT/CLAUDE.md"
fail=0
# security-floor: the capability clause keeps delegation harness-gated
for f in "$U" "$C"; do
  grep -qF 'where the harness supports nested subagents' "$f" || { echo "FAIL: capability clause missing in $f"; fail=1; }
  grep -qF 'One bead owner per plan' "$f" || { echo "FAIL: CB-6 signature missing in $f"; fail=1; }
done
# absence-of-defect: the old bright line must not linger beside the new one
if grep -qF 'Only the orchestrating agent manages beads' "$U"; then echo "FAIL: old rule still in using-superpowers"; fail=1; fi
if grep -qF 'Only the orchestrating agent manages beads' "$C"; then echo "FAIL: old rule still in CLAUDE.md"; fail=1; fi
# absence-of-defect (stress-test B5): exactly one signature line per site — a duplicate breaks whole-line identity
for f in "$U" "$C"; do
  n=$(grep -cF 'One bead owner per plan' "$f" || true); [ "$n" -eq 1 ] || { echo "FAIL: CB-6 signature on $n lines in $f (expected 1)"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "PASS: CB-6 owner rule" || exit 1
