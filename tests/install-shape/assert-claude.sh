#!/usr/bin/env bash
# assert-claude.sh — Tier A: full artifact + uninstall round-trip for Claude Code.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup claude
trap 'shape_sandbox_teardown' EXIT
shape_install

assert_all_skills "$SANDBOX/skills"
assert_file "$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
assert_file "$SANDBOX/.claude/settings.json"
assert_json "$SANDBOX/.claude/settings.json" "'SessionStart' in d.get('hooks', {})"
assert_json "$SANDBOX/.claude/settings.json" "'UserPromptSubmit' not in d.get('hooks', {})"
assert_no_file "$SANDBOX/.claude/hooks/beads-superpowers-reminder.sh"
# Default install must NOT place the yegge agent (opt-in via --with-yegge, bead 3krn)
assert_no_file "$SANDBOX/.claude/agents/yegge.md"
assert_file "$SANDBOX/skills/.beads-superpowers-version"
grep -q ":local$" "$SANDBOX/skills/.beads-superpowers-version" || _fail "version file tier != local"
assert_shims_never_invoked

# Round-trip: uninstall removes artifacts; designed settings backup MUST remain.
shape_uninstall
assert_no_file "$SANDBOX/skills/using-superpowers/SKILL.md"
assert_no_file "$SANDBOX/.claude/agents/yegge.md"
assert_no_file "$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
assert_no_file "$SANDBOX/skills/.beads-superpowers-version"
if [ -f "$SANDBOX/.claude/settings.json" ]; then
  assert_json "$SANDBOX/.claude/settings.json" "'beads-superpowers' not in json.dumps(d)"
fi
if compgen -G "$SANDBOX/.claude/settings.json.backup-*" > /dev/null; then
  _pass "designed settings backup present"
else
  _fail "designed settings.json.backup-* missing after uninstall"
fi

# Opt-in round-trip: --with-yegge installs the agent; uninstall removes it (bead 3krn)
shape_install --with-yegge
assert_file "$SANDBOX/.claude/agents/yegge.md"
assert_all_skills "$SANDBOX/skills"
assert_shims_never_invoked
shape_uninstall
assert_no_file "$SANDBOX/.claude/agents/yegge.md"

shape_sandbox_teardown
fail_count
