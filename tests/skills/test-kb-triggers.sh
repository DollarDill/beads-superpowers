#!/usr/bin/env bash
# Pins Trigger A (ADR-0056): brainstorming's Phase-1 context-gathering step must
# query the beads-native KB before a design is proposed. Asserts both markers are
# present in skills/brainstorming/SKILL.md so the co-located instruction can't be
# silently edited out.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/brainstorming/SKILL.md"
fail=0

if [ ! -f "$SKILL" ]; then
  echo "FAIL: missing $SKILL"; exit 1
fi

if grep -qF -- 'bd list --label' "$SKILL"; then
  echo "PASS: KB query command present (bd list --label)"
else
  echo "FAIL: KB query command missing (bd list --label) in $SKILL"; fail=1
fi

if grep -qF -- 'KB check' "$SKILL"; then
  echo "PASS: visible KB check result present (KB check)"
else
  echo "FAIL: visible KB check result missing (KB check) in $SKILL"; fail=1
fi

[ "$fail" -eq 0 ] && echo "PASS: KB trigger markers present in brainstorming/SKILL.md" || exit 1
