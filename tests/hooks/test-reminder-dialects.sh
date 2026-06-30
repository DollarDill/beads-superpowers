#!/usr/bin/env bash
# test-reminder-dialects.sh — assert superpowers-reminder.sh emits valid JSON
# per harness dialect and that content includes "memory-curator".
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/superpowers-reminder.sh"
fail=0

check() {
  local desc="$1" envset="$2" filter="$3"
  local out
  # shellcheck disable=SC2086  # $envset is intentionally word-split (space-separated KEY=VALUE pairs)
  out=$(env -i HOME="$HOME" PATH="$PATH" $envset bash "$HOOK" 2>/dev/null)
  if echo "$out" | jq -e "$filter" >/dev/null 2>&1; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"; echo "  got: $out"; fail=1
  fi
}

# Generic dialect: top-level additionalContext, must contain "memory-curator"
check "Generic → additionalContext contains memory-curator" \
  "" \
  '.additionalContext | contains("memory-curator")'

# Injected content must NOT leak the maintainer-only "# ..." comment line.
check "Generic → injected content excludes session-handoff" \
  "" \
  '.additionalContext | contains("session-handoff") | not'
check "Generic → injected content has no full-line # comment" \
  "" \
  '.additionalContext | split("\n") | (map(test("^\\s*#")) | any) | not'

# Cursor dialect: additional_context (snake_case)
check "Cursor → .additional_context present" \
  "CURSOR_PLUGIN_ROOT=/x" \
  '.additional_context'

# Claude dialect: nested hookSpecificOutput.additionalContext
check "Claude → .hookSpecificOutput.additionalContext present" \
  "CLAUDE_PLUGIN_ROOT=/x" \
  '.hookSpecificOutput.additionalContext'

exit $fail
