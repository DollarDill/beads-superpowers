#!/usr/bin/env bash
# Self-test for scripts/check-todowrite.sh — drives the REAL script (no copied filter).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$ROOT/scripts/check-todowrite.sh"
fail=0

# Positive: the real skills/ tree must pass clean (no false positive).
if bash "$GATE" >/dev/null 2>&1; then
  echo "PASS: gate clean on skills/"
else
  echo "FAIL: gate flagged the current skills/ tree (false positive)"; fail=1
fi

# Negative: a prescriptive TodoWrite line in a fixture must be caught.
fixture=$(mktemp -d)
printf 'Use TodoWrite to track tasks\n' > "$fixture/sample.md"
if bash "$GATE" "$fixture" >/dev/null 2>&1; then
  echo "FAIL: gate did NOT catch a prescriptive TodoWrite line"; fail=1
else
  echo "PASS: gate caught prescriptive TodoWrite in fixture"
fi
rm -rf "$fixture"

[ "$fail" -eq 0 ] && echo "PASS: TodoWrite gate self-test" || exit 1
