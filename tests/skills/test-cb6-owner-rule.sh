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
# Delegated orchestration reference: the delegate stops before finishing; the session verifies what SDD leaves behind
T="$ROOT/skills/using-superpowers/references/claude-code-tools.md"
# CHANGE-DETECTOR (convert: plugin-eval delegation case, s9xyx) — the delegate never merges, pushes or tears down
grep -qF 'Do not invoke beads-superpowers:finishing-a-development-branch, merge, push, or tear down the plan workspace' "$T" || { echo "FAIL: delegate brief lacks the stop-before-finish line"; fail=1; }
# CHANGE-DETECTOR (convert: plugin-eval delegation case, s9xyx) — verify-on-return checks the review verdict and the ruling lines
grep -qF 'closed only after a review verdict' "$T" || { echo "FAIL: verify-on-return lacks the review-verdict check"; fail=1; }
grep -qF 'A completion line without a matching commit is a finding' "$T" || { echo "FAIL: verify-on-return lacks the missing-commit finding"; fail=1; }
# absence-of-defect — SDD writes no per-task tests log and deletes the plan workspace at teardown
if grep -qF 'tests log exists under the plan workspace' "$T"; then echo "FAIL: verify-on-return still demands a tests log SDD never writes"; fail=1; fi
# absence-of-defect — writing-plans offers no delegation option at its handoff
if grep -qF 'opts in at the writing-plans handoff' "$T"; then echo "FAIL: reference names a handoff option that does not exist"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: CB-6 owner rule" || exit 1
