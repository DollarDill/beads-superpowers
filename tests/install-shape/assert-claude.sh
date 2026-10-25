#!/usr/bin/env bash
# assert-claude.sh — Tier A: full artifact + uninstall round-trip for Claude Code.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup claude
trap 'shape_sandbox_teardown' EXIT
shape_install

assert_all_skills "$SANDBOX/skills"
# ADR-0044: maintainer-only skill must never be installed
assert_no_file "$SANDBOX/skills/auditing-upstream-drift/SKILL.md"
assert_file "$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
# Written hook must be a thin exec shim of the canonical composer (bead bb6x),
# and the canonical copy must land where the shim points.
assert_file "$SANDBOX/.claude/hooks/beads-superpowers/hooks/session-start"
# Its exec names bash by $BASH, so `#!/usr/bin/env bash` never looks bash up on
# an empty PATH (which would search the untrusted cwd).
# shellcheck disable=SC2016  # the '$BSP_ROOT' exec line is matched literally, not expanded
if [ "$(tail -n 1 "$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh" 2>/dev/null)" = 'exec "${BASH:-bash}" "$BSP_ROOT/hooks/session-start" "$@"' ]; then
  _pass "written hook execs the canonical composer via \${BASH:-bash}"
else
  _fail "written hook's last line is not the \${BASH:-bash} exec of hooks/session-start"
fi
# With PATH= and binaries planted in the cwd, the shim still injects the
# bootstrap and never runs a planted binary.
_evil="$SANDBOX/.evil"
mkdir -p "$_evil" "$SANDBOX/.rt"
for _b in bash cat sed dirname id bd; do
  printf '#!/bin/sh\n: > "%s/ran-%s"\n' "$SANDBOX" "$_b" > "$_evil/$_b"
  chmod +x "$_evil/$_b"
done
(cd "$_evil" && env -i HOME="$SANDBOX" XDG_RUNTIME_DIR="$SANDBOX/.rt" PATH= "$(command -v bash)" \
  "$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh" </dev/null > "$SANDBOX/.shim-out" 2>/dev/null)
_rc=$?
if [ "$_rc" -eq 0 ] && python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert "Production-Grade Doctrine" in d["hookSpecificOutput"]["additionalContext"]' < "$SANDBOX/.shim-out" 2>/dev/null; then
  _pass "shim with PATH= emits the bootstrap envelope"
else
  _fail "shim with PATH= did not emit the bootstrap envelope (rc=$_rc)"
fi
if compgen -G "$SANDBOX/ran-*" > /dev/null; then
  _fail "shim with PATH= ran a planted binary: $(cd "$SANDBOX" && echo ran-*)"
else
  _pass "shim with PATH= ran no planted binary"
fi
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
assert_no_file "$SANDBOX/.claude/hooks/beads-superpowers"
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
