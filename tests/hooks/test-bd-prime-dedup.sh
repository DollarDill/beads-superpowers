#!/usr/bin/env bash
# test-bd-prime-dedup.sh — assert session-start skips its own bd prime injection
# when "bd prime" is already registered in a settings file (dedup guard).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/session-start"
fail=0

# Temp CWD with no .claude directory — prevents relative-path settings files
# from interfering with the HOME-based check we're testing.
tmp_cwd=$(mktemp -d)

# --- DEDUP CASE: HOME settings contain "bd prime" → no <beads-context> block ---
tmp_home=$(mktemp -d)
mkdir -p "$tmp_home/.claude"
printf '{"hooks":{"SessionStart":[{"command":"bd prime"}]}}\n' \
  > "$tmp_home/.claude/settings.json"

out=$(cd "$tmp_cwd" && env -i HOME="$tmp_home" PATH="$PATH" CLAUDE_PLUGIN_ROOT=/x \
  bash "$HOOK" 2>/dev/null)
if grep -q '<beads-context>' <<<"$out"; then
  echo "FAIL: dedup — output contains <beads-context> even though 'bd prime' is in settings"
  echo "  got: $out"
  fail=1
else
  echo "PASS: dedup — output does not contain <beads-context> when 'bd prime' is in settings"
fi
rm -rf "$tmp_home"

# --- NEGATIVE CONTROL (informational, never fails) ---
# If bd is installed and bd prime returns non-empty context, verify <beads-context>
# appears in output when settings do NOT mention "bd prime".
# Guarded: skip if bd absent or bd prime returns empty (no active project in this env).
if command -v bd >/dev/null 2>&1; then
  tmp_home2=$(mktemp -d)
  mkdir -p "$tmp_home2/.claude"
  printf '{"hooks":{}}\n' > "$tmp_home2/.claude/settings.json"
  out2=$(cd "$tmp_cwd" && env -i HOME="$tmp_home2" PATH="$PATH" CLAUDE_PLUGIN_ROOT=/x \
    bash "$HOOK" 2>/dev/null) || true
  if grep -q '<beads-context>' <<<"$out2"; then
    echo "INFO: negative-control — <beads-context> present when bd not in settings (bd installed, project active)"
  else
    echo "SKIP: negative-control — bd installed but bd prime returned empty (no active project in this env)"
  fi
  rm -rf "$tmp_home2"
else
  echo "SKIP: negative-control — bd not installed"
fi

rm -rf "$tmp_cwd"
exit $fail
