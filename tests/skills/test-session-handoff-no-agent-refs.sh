#!/usr/bin/env bash
# Asserts session-handoff is absent from every agent-facing surface.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
fail=0

# Agent-facing surfaces that must NOT mention the skill.
SURFACES=(
  "skills/using-superpowers/SKILL.md"
  "hooks/superpowers-reminder.sh"
  "hooks/session-start"
  "example-workflow/agents/yegge.md"
  "hooks/hooks.json"
  "hooks/codex-hooks.json"
  "opencode/beads-superpowers-plugin.ts"
  ".kimi-plugin/plugin.json"
)
for f in "${SURFACES[@]}"; do
  if grep -q "session-handoff" "$f" 2>/dev/null; then
    echo "FAIL: session-handoff referenced in agent surface $f"; fail=1
  else
    echo "PASS: clean — $f"
  fi
done

# Other skills' Integration sections must not reference it.
if grep -rl "session-handoff" skills/ --include=SKILL.md | grep -v "skills/session-handoff/" ; then
  echo "FAIL: another skill references session-handoff"; fail=1
else
  echo "PASS: no sibling skill references it"
fi

[ "$fail" -eq 0 ] && echo "PASS: no-agent-refs" || exit 1
