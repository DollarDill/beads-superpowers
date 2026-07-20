#!/usr/bin/env bash
# run-contracts.sh — deterministic skill-contract tests (tests/skills/*).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit
rc=0
for t in tests/skills/*.sh; do
  echo "── $t"
  if bash "$t"; then echo "   PASS"; else echo "   FAIL"; rc=1; fi
done

# Installer runtime-detection unit test (stubbed — no container needed).
t=tests/installer/test-select-runtime.sh
echo "── $t"
if bash "$t"; then echo "   PASS"; else echo "   FAIL"; rc=1; fi
exit "$rc"
