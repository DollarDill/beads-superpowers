#!/usr/bin/env bash
# tests/skills/test-no-zh-docs.sh — zh docs were removed in 0.17.0 (spec U5).
# absence-of-defect: no tracked zh docs, guard, or dangling reference survives.
# Historical records (CHANGELOG.md, the drift-audit divergence table) may name the removed
# paths; live docs and code may not.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
# Fail closed: outside a git work tree every git probe below would "find nothing" and pass.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "FAIL: not inside a git work tree"; exit 1; }
[ -f skills/using-superpowers/SKILL.md ] || { echo "FAIL: not the beads-superpowers repo root"; exit 1; }
fail=0
for p in README.zh-CN.md docs/zh scripts/check-zh-docs.sh; do
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1 || [ -e "$p" ]; then
    echo "FAIL: still present: $p"; fail=1; fi
done
# Dangling references (history records, this test, and the CJK skill-count guard excluded).
git grep -nE 'README\.zh-CN|docs/zh|check-zh-docs|Chinese siblings|zh-docs' -- . \
  ':!CHANGELOG.md' ':!.claude/skills/auditing-upstream-drift/SKILL.md' \
  ':!tests/skills/test-no-zh-docs.sh' ':!scripts/check-skill-count.sh'
gg=$?   # 0 = matches found, 1 = none, anything else = git error (fail closed)
if [ "$gg" -eq 0 ]; then echo "FAIL: dangling zh reference(s) above"; fail=1
elif [ "$gg" -ne 1 ]; then echo "FAIL: git grep errored (exit $gg)"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: no zh docs surface" || exit 1
