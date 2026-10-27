#!/usr/bin/env bash
# tests/skills/test-python-isolated.sh — every python3/python invocation in shipped skill
# content must use -I. Plain `python3 -c` puts the cwd first on sys.path, so a planted
# json.py in the user's project runs. Comment lines that merely mention python3 are exempt.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
[ -f skills/using-superpowers/SKILL.md ] || { echo "FAIL: not the beads-superpowers repo root"; exit 1; }
# An invocation = python/python3 followed by a flag or a .py path; the flag must be -I.
hits=$(grep -rnEI '(^|[^A-Za-z0-9_./-])python3?[[:space:]]+(-[A-Za-z]|[^[:space:]]*\.py)' skills \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -vE 'python3?[[:space:]]+-[A-Za-z]*I')
if [ -n "$hits" ]; then
  echo "FAIL: python invocation without -I in skills/:"; echo "$hits"; exit 1
fi
echo "PASS: every python invocation in skills/ is isolated (-I)"
