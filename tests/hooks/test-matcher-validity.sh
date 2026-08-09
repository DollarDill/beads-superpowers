#!/usr/bin/env bash
# Asserts both hooks.json and codex-hooks.json have SessionStart matchers
# containing all four sources: startup, resume, clear, compact.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
for f in hooks/hooks.json hooks/codex-hooks.json; do
  m=$(jq -r '.hooks.SessionStart[0].matcher' "$ROOT/$f")
  for src in startup resume clear compact; do
    if grep -q "$src" <<<"$m"; then
      echo "PASS: $f contains '$src'"
    else
      echo "FAIL: $f missing '$src' (matcher: $m)"; fail=1
    fi
  done
done

if grep -Fq '"shell": "bash"' "$ROOT/hooks/hooks.json"; then
  echo "PASS: hooks/hooks.json declares shell:bash (Windows: git-bash, not cmd.exe)"
else
  echo "FAIL: hooks/hooks.json is missing \"shell\": \"bash\" — the hook runs under cmd.exe on Windows"; fail=1
fi

exit $fail
