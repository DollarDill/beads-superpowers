#!/usr/bin/env bash
# tests/skills/test-brainstorming-contract.sh — run: bash tests/skills/test-brainstorming-contract.sh
set -euo pipefail
F="$(cd "$(dirname "$0")/../.." && pwd)/skills/brainstorming/SKILL.md"
fail=0
pin() { grep -qF -- "$1" "$F" || { echo "FAIL: missing: $1"; fail=1; }; }
# CHANGE-DETECTOR — v6.4.2 adoption (0.17.0 U4): shared understanding + staged approvals
pin '## Establish Shared Understanding'
pin 'A reply approves the stage actually presented.'
pin 'Approval of an idea or feature scope does not approve artifacts that do not exist yet.'
pin 'Resume at the earliest incomplete stage'
pin 'Read-only project exploration is allowed'
pin "carried in the task bead's description"
pin "you MUST complete the selected path's prerequisites"
# Unchanged doctrine + 3-option gate
pin '**Production-Grade Doctrine** applies with full force here'
pin 'Approved + stress-test'
[ "$fail" -eq 0 ] && echo "PASS: brainstorming contract" || exit 1
