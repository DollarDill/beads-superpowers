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

# (d) Skills-only layout (npx --copy): get-*-hook.sh must resolve the CO-LOCATED copy with
# NO hooks/ sibling present. Nest under install/ so BOTH repo-relative fallbacks
# ($SCRIPT_DIR/../../hooks and ../../../hooks) resolve to absent dirs inside the temp tree —
# guaranteeing a pre-fix run genuinely emits "# ERROR" rather than finding a real hooks/.
tmpd=$(mktemp -d)
mkdir -p "$tmpd/install/skills"
cp -rf "$ROOT/skills/setup" "$tmpd/install/skills/setup"
rm -rf "$tmpd/install/hooks" "$tmpd/hooks"   # ensure no fallback target exists
setup_dir="$tmpd/install/skills/setup"

d_session=$(bash "$setup_dir/get-session-start-hook.sh" 2>/dev/null)
d_reminder=$(bash "$setup_dir/get-reminder-hook.sh" 2>/dev/null)

if echo "$d_session" | grep -q '# ERROR' || ! echo "$d_session" | grep -q 'SessionStart hook for beads-superpowers'; then
  echo "FAIL (d1): skills-only get-session-start-hook.sh did not resolve co-located copy (# ERROR or missing marker)"; fail=1
elif echo "$d_reminder" | grep -q '# ERROR' || ! echo "$d_reminder" | grep -q 'SUPERPOWERS REMINDER'; then
  echo "FAIL (d2): skills-only get-reminder-hook.sh did not resolve co-located copy (# ERROR or missing marker)"; fail=1
else
  # Canonical content from the skills-only layout must still produce the nested Claude form.
  mkdir -p "$tmpd/inst/hooks" "$tmpd/inst/skills/using-superpowers"
  cp -f "$ROOT/skills/using-superpowers/SKILL.md" "$tmpd/inst/skills/using-superpowers/SKILL.md"
  printf '%s\n' "$d_session" > "$tmpd/inst/hooks/session-start"
  chmod +x "$tmpd/inst/hooks/session-start"
  d_hookout=$(CLAUDE_PLUGIN_ROOT=/x bash "$tmpd/inst/hooks/session-start" 2>/dev/null)
  if echo "$d_hookout" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    echo "PASS (d): skills-only layout resolves co-located copies + emits nested form"
  else
    echo "FAIL (d3): skills-only installed hook not nested; got: $d_hookout"; fail=1
  fi
fi
rm -rf "$tmpd"

exit $fail
