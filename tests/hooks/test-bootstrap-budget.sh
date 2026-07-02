#!/usr/bin/env bash
# test-bootstrap-budget.sh — guard the always-injected session bootstrap size (ADR-0039).
# SCOPE: SKILL.md FILE bytes only. bd prime output and conditional warnings are
# deliberately OUT of budget — they are environment-sized and dedup-guarded.
# Do not "fix" this test to measure the full injection; that makes it flaky.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/using-superpowers/SKILL.md"
CEILING=6144
WRAPPER_CEILING=1024
fail=0
size=$(wc -c < "$SKILL")
if [ "$size" -gt "$CEILING" ]; then
  echo "FAIL: using-superpowers/SKILL.md is ${size} bytes (> ${CEILING})"; fail=1
fi
# Static wrapper template (the session_context assignment line in the hook,
# variable names unexpanded) must stay small too.
wrapper=$(grep -m1 'session_context=' "$ROOT/hooks/session-start" | wc -c)
if [ "$wrapper" -gt "$WRAPPER_CEILING" ]; then
  echo "FAIL: session-start wrapper template is ${wrapper} bytes (> ${WRAPPER_CEILING})"; fail=1
fi
if [ "$fail" = 0 ]; then
  echo "PASS: bootstrap ${size}B <= ${CEILING}B; wrapper ${wrapper}B <= ${WRAPPER_CEILING}B"
fi
exit "$fail"
