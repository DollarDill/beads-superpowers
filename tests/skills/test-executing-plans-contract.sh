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
pin 'Final Review starts only when `bd epic status <epic-id>` shows every child closed'
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
# CB-7 ruling-format block byte-identical with SDD (three physical lines)
if ! diff -q <(grep -A2 -F '**Every ruling cites its authority**' "$S") <(grep -A2 -F '**Every ruling cites its authority**' "$F") >/dev/null; then echo "FAIL: CB-7 ruling block diverges from SDD"; fail=1; fi
# guardrail floor: Red Flags table has at least 12 rows
rows=$(awk '/^## Red Flags/{f=1;next} f&&/^## /{f=0} f&&/^\|/{c++} END{print c+0}' "$F")
[ "$rows" -ge 14 ] || { echo "FAIL: Red Flags table has $rows lines (< header+separator+12 rows)"; fail=1; }
# no model names (tiers only)
if grep -qiE 'sonnet|opus|haiku|gpt-|claude-' "$F"; then echo "FAIL: model name in skill"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: executing-plans contract" || exit 1
