#!/usr/bin/env bash
# Asserts hooks/session-start emits the correct JSON dialect per harness env var.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/session-start"
fail=0
# Isolated runtime dir + distinct session_id per check(): Task 3's event-scoped dedup
# marker suppresses a second same-(session_id,source) event within 60s. These 5 calls
# are ambient (no stdin, unisolated XDG_RUNTIME_DIR) and would otherwise collide on the
# same "nosid/unknown" marker key -- both with each other and with other test files that
# use the same real-/tmp fallback key (see tests/hooks/test-dedup-marker.sh).
RUNDIR=$(mktemp -d); trap 'rm -rf "$RUNDIR"' EXIT
n=0
check() { # desc | env-assignment | jq-filter that must be non-empty
  local desc="$1" envset="$2" filter="$3"
  local out
  n=$((n + 1))
  # shellcheck disable=SC2086  # $envset is intentionally word-split (space-separated KEY=VALUE pairs)
  out=$(printf '{"session_id":"dialect-%s","source":"startup"}' "$n" \
    | env -i HOME="$HOME" PATH="$PATH" XDG_RUNTIME_DIR="$RUNDIR" $envset bash "$HOOK" 2>/dev/null)
  if echo "$out" | jq -e "$filter" >/dev/null 2>&1; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"; echo "  got: $out"; fail=1
  fi
}
check "Cursor → top-level additional_context"        "CURSOR_PLUGIN_ROOT=/x" '.additional_context'
check "Claude → nested additionalContext"            "CLAUDE_PLUGIN_ROOT=/x" '.hookSpecificOutput.additionalContext'
check "Claude settings-channel (PROJECT_DIR only) → nested" "CLAUDE_PROJECT_DIR=/x" '.hookSpecificOutput.additionalContext'
check "Codex → nested additionalContext"             "CODEX_PLUGIN_ROOT=/x" '.hookSpecificOutput.additionalContext'
check "Copilot (with CLAUDE root) → top-level"       "CLAUDE_PLUGIN_ROOT=/x COPILOT_CLI=1" '.additionalContext'
check "Copilot (with PROJECT_DIR) → top-level"       "CLAUDE_PROJECT_DIR=/x COPILOT_CLI=1" '.additionalContext'
check "Generic fallback → top-level additionalContext" "" '.additionalContext'
check "Rule section present in injected context"       "" '.additionalContext | contains("Skill Name Resolution")'
exit $fail
