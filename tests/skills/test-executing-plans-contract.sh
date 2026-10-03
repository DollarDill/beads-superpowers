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
# CB-7 ruling-format block byte-identical with SDD (three physical lines)
if ! diff -q <(grep -A2 -F '**Every ruling cites its authority**' "$S") <(grep -A2 -F '**Every ruling cites its authority**' "$F") >/dev/null; then echo "FAIL: CB-7 ruling block diverges from SDD"; fail=1; fi
# guardrail floor: Red Flags table has at least 12 rows
rows=$(awk '/^## Red Flags/{f=1;next} f&&/^## /{f=0} f&&/^\|/{c++} END{print c+0}' "$F")
[ "$rows" -ge 14 ] || { echo "FAIL: Red Flags table has $rows lines (< header+separator+12 rows)"; fail=1; }
# no model names (tiers only)
if grep -qiE 'sonnet|opus|haiku|gpt-|claude-' "$F"; then echo "FAIL: model name in skill"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: executing-plans contract" || exit 1
