#!/usr/bin/env bash
# tests/skills/test-sdd-structure.sh — run: bash tests/skills/test-sdd-structure.sh
# MECHANICAL INVARIANTS ONLY. These assert structure (a pointer target exists, a
# file is within budget) — never the wording of instruction text. Adding prose
# assertions here reintroduces the string-presence trap; don't.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/subagent-driven-development/SKILL.md"
rc=0

# 1. every referenced context pointer resolves to a real file
#    (a cross-skill pointer keeps its ../<skill>/ prefix so it resolves where it really points)
while read -r target; do
  [ -n "$target" ] || continue
  [ -f "$ROOT/skills/subagent-driven-development/$target" ] || {
    echo "FAIL: dangling context pointer: $target"; rc=1; }
done < <(grep -oE '(\.\./[a-z0-9-]+/)?references/[a-z0-9-]+\.md' "$SKILL" | sort -u)

# 2. C1 line budget
lines=$(grep -c '' "$SKILL")
if [ "$lines" -ge 500 ]; then
  echo "FAIL: SKILL.md is $lines lines (C1 budget is <500) — move material behind a context pointer"
  rc=1
fi

[ "$rc" -eq 0 ] && echo "PASS: sdd structural invariants ($lines lines)"
exit "$rc"
