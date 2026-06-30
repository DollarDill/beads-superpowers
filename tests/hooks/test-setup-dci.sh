#!/usr/bin/env bash
# test-setup-dci.sh — assert that the setup DCI scripts emit canonical hook content
# and that the session-start DCI output produces the correct nested JSON shape.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0

# (a) get-session-start-hook.sh emits non-empty canonical content
out_session=$(bash "$ROOT/skills/setup/get-session-start-hook.sh" 2>/dev/null)
if [ -z "$out_session" ]; then
  echo "FAIL (a): get-session-start-hook.sh emitted nothing"; fail=1
elif ! echo "$out_session" | grep -q 'SessionStart hook for beads-superpowers'; then
  echo "FAIL (a): missing canonical marker 'SessionStart hook for beads-superpowers'"; fail=1
elif echo "$out_session" | grep -q '# ERROR'; then
  echo "FAIL (a): get-session-start-hook.sh emitted # ERROR"; fail=1
else
  echo "PASS (a): get-session-start-hook.sh emits canonical session-start content"
fi

# (b) get-reminder-hook.sh emits non-empty canonical content
out_reminder=$(bash "$ROOT/skills/setup/get-reminder-hook.sh" 2>/dev/null)
if [ -z "$out_reminder" ]; then
  echo "FAIL (b): get-reminder-hook.sh emitted nothing"; fail=1
elif ! echo "$out_reminder" | grep -q 'SUPERPOWERS REMINDER'; then
  echo "FAIL (b): missing marker 'SUPERPOWERS REMINDER'"; fail=1
elif echo "$out_reminder" | grep -q '# ERROR'; then
  echo "FAIL (b): get-reminder-hook.sh emitted # ERROR"; fail=1
else
  echo "PASS (b): get-reminder-hook.sh emits canonical reminder content"
fi

# (c) Session-start hook produced by the DCI, when executed with CLAUDE_PLUGIN_ROOT set
# against a temp skills tree, must emit nested .hookSpecificOutput.additionalContext
# (proves the npx path no longer emits the broken top-level shape).
if [ $fail -eq 0 ]; then
  tmp=$(mktemp -d)
  mkdir -p "$tmp/hooks" "$tmp/skills/using-superpowers"
  cp -f "$ROOT/skills/using-superpowers/SKILL.md" "$tmp/skills/using-superpowers/SKILL.md"
  # The DCI output IS the canonical hook content — write it as the installed hook
  printf '%s\n' "$out_session" > "$tmp/hooks/session-start"
  chmod +x "$tmp/hooks/session-start"
  # Run with CLAUDE_PLUGIN_ROOT set → must emit nested hookSpecificOutput
  hook_out=$(CLAUDE_PLUGIN_ROOT=/x bash "$tmp/hooks/session-start" 2>/dev/null)
  if echo "$hook_out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    echo "PASS (c): installed session-start emits nested hookSpecificOutput.additionalContext"
  else
    echo "FAIL (c): expected nested form; got: $hook_out"; fail=1
  fi
  rm -rf "$tmp"
else
  echo "SKIP (c): skipping nested-form check (earlier assertions failed)"
fi

exit $fail
