#!/usr/bin/env bash
# tests/skills/test-executing-plans-contract.sh — run: bash tests/skills/test-executing-plans-contract.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; F="$ROOT/skills/executing-plans/SKILL.md"; S="$ROOT/skills/subagent-driven-development/SKILL.md"
fail=0
pin() { grep -qF -- "$1" "$F" || { echo "FAIL: missing: $1"; fail=1; }; }
absent() { if grep -qF -- "$1" "$F"; then echo "FAIL: present: $1"; fail=1; fi; }
# absence-of-defect — upstream's markdown ledger/scripts are not ported
absent 'progress.md'; absent 'task-start'; absent 'task-done'
# security-floor
pin 'is NEVER rulable and never parkable'
# security-floor — re-grading by effect never lowers a security finding
pin '**Re-grading never lowers a security finding:** it stays Critical, enters the fix pass, gets the scoped re-review, and is never deferred or ruled.'
# security-floor — the no-subagent path cannot re-review a Critical/security fix
pin 'A Critical or security fix needs a fresh-context re-review this path cannot provide: it escalates to your human partner before merge.'
# never drop a task — resume finds the interrupted task and the epic; Final Review waits for every child
pin 'bd list --parent <epic-id> --status in_progress'
# shellcheck disable=SC2016  # backticks are literal pinned skill text, not command substitution
pin 'Then `bd ready --parent <epic-id>` is the remaining work'
# shellcheck disable=SC2016  # backticks are literal pinned skill text, not command substitution
pin 'Final Review starts only when `bd list --parent <epic-id> --status open,in_progress,blocked,deferred` lists no children'
# absence-of-defect — bd epic status ignores the id (prints every epic), so it cannot gate one epic
absent 'bd epic status <epic-id>'
pin 'bd list -t epic --status open --desc-contains "Plan: <plan file path>"'
absent 'bd search "<plan basename>"'
absent 'The stops above are the only reasons to stop.'
absent 'Rule on each conflict a row surfaces'
# CHANGE-DETECTOR (convert: plugin-eval executing-plans case, s9xyx)
pin 'Do not pause to check in between tasks'
pin 'complete (commits <base7>..<head7>, tests: <cmd>'
pin 'rulings: <n>'
pin 'the third ruling in one run'
pin 'Plan: <plan file path>'
pin 'task-<N>-tests.log'
pin '### Declined to judge'
pin 'Rulings I made'
pin 'Deferred minors'
pin 'Fixes applied'
pin 'bd ready --parent <epic-id> --claim'
pin '## Red Flags'
pin 'most capable'
pin 'Final: Ruling: <behavior set aside> — settled by <spec §> — <effect on a reasonable person> — <cost if wrong>'
# CHANGE-DETECTOR (convert: plugin-eval executing-plans case, s9xyx) — the ruling budget counts task-loop rulings only; Final: rulings are listed exhaustively and still escalate without a spec §
pin 'The budget counts task-loop rulings only'
pin 'rulings from the final review do not count toward it'
pin 'with no citable spec § still escalates'
# absence-of-defect — the MERGE_BASE example must not assume main (work integrates on a target branch such as dev)
absent 'git merge-base main HEAD'
pin 'git merge-base <target-branch> HEAD'
# absence-of-defect — no sibling skill or doc may describe the per-task/batch cadence executing-plans no longer has
for stale in "$ROOT/skills/requesting-code-review/SKILL.md|review after each task or at natural checkpoints" \
             "$ROOT/README.md|executes in batches with human checkpoints" \
             "$ROOT/README.md|Batch plan execution in a single session with checkpoints" \
             "$ROOT/CLAUDE.md|Batch execution in single session"; do
  if grep -qF -- "${stale#*|}" "${stale%%|*}"; then echo "FAIL: stale executing-plans description in ${stale%%|*}: ${stale#*|}"; fail=1; fi
done
# CHANGE-DETECTOR (convert: plugin-eval executing-plans case, s9xyx) — requesting-code-review states the real cadence
grep -qF -- '**executing-plans** — one whole-branch review after the last task (most capable tier)' "$ROOT/skills/requesting-code-review/SKILL.md" || { echo "FAIL: requesting-code-review lacks the executing-plans cadence line"; fail=1; }
# CB-7 ruling-format block byte-identical with SDD (three physical lines)
if ! diff -q <(grep -A2 -F '**Every ruling cites its authority**' "$S") <(grep -A2 -F '**Every ruling cites its authority**' "$F") >/dev/null; then echo "FAIL: CB-7 ruling block diverges from SDD"; fail=1; fi
# upstream v6.4.1 parity — passages never adopted at the original port, restored by user ruling (0.17.0 quality gate, beads-superpowers-cxwy4)
pin "Another plan's directory is never yours to read or write."
pin 'Sibling directories belong to other plans; leave them alone.'
pin 'a test that passes before the implementation exists is a finding about the test.'
pin 'does not exempt you from reading it.'
pin "Each task's own text is checked when you read its brief, not here."
pin 'the reviewer checks each deliberately'
pin '## Example Workflow'
# guardrail floor: Red Flags table has at least 12 rows
rows=$(awk '/^## Red Flags/{f=1;next} f&&/^## /{f=0} f&&/^\|/{c++} END{print c+0}' "$F")
[ "$rows" -ge 14 ] || { echo "FAIL: Red Flags table has $rows lines (< header+separator+12 rows)"; fail=1; }
# no model names (tiers only)
if grep -qiE 'sonnet|opus|haiku|gpt-|claude-' "$F"; then echo "FAIL: model name in skill"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: executing-plans contract" || exit 1
