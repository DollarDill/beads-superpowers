#!/usr/bin/env bash
# tests/skills/test-project-init-contract.sh — run: bash tests/skills/test-project-init-contract.sh
set -euo pipefail
R="$(cd "$(dirname "$0")/../.." && pwd)/skills/project-init"
F="$R/SKILL.md"; REC="$R/references/recovery.md"
fail=0
pin() { grep -qF -- "$1" "${2:-$F}" || { echo "FAIL: missing: $1"; fail=1; }; }
absent() { if grep -qF -- "$1" "${2:-$F}"; then echo "FAIL: still present: $1"; fail=1; fi; }
# CHANGE-DETECTOR — bd v1.3.1 minimum (0.17.0 U3)
pin '## Version floor: bd v1.3.1 minimum. NEVER install v1.2.0 or v1.2.1'
pin '**Minimum supported: bd v1.3.1.**'
pin 'The first bd command after upgrading runs the in-place v53→v66 schema migration — run any bd command once in a terminal before starting an agent session.'
pin '--skip-agents'
pin '--destroy-token'
pin '--check=artifacts'
pin 'bd serve'
pin '--auth-token-file'
pin 'caller-asserted'
pin 'bd migrate --force' "$REC"
pin '--strategy ours|theirs' "$REC"
# KERNEL_MAP pin
pin 'Iron Law: NEVER Run'
# absence-of-defect — superseded text gone
absent 'Safe versions: v1.1.2 or v1.2.2'
absent 'forward-compat'
absent 'releases after 1.1.0'
absent 'releases after v1.1.0'
pin 'bd export --all -o /tmp/beads-backup.jsonl'
pin 'bd export --all -o /tmp/beads-backup.jsonl' "$REC"
absent 'bd export -o /tmp/beads-backup.jsonl'
absent 'bd export -o /tmp/beads-backup.jsonl' "$REC"
[ "$fail" -eq 0 ] && echo "PASS: project-init contract" || exit 1
