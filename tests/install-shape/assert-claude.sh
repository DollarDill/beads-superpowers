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
# Its exec names the bash it vetted (run-hook.cmd's rule), so neither the
# shebang nor $BASH can bring in a bash from the untrusted cwd.
# shellcheck disable=SC2016  # the '$BSP_ROOT' exec line is matched literally, not expanded
if [ "$(tail -n 1 "$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh" 2>/dev/null)" = 'exec "$bsp_bash" "$BSP_ROOT/hooks/session-start" "$@"' ]; then
  _pass "written hook execs the canonical composer via the vetted bash"
else
  _fail "written hook's last line is not the vetted-bash exec of hooks/session-start"
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
# The harness runs the registered command through a shell, so a bare `bash`
# is looked up on the harness PATH, and an empty or relative entry searches
# the untrusted project. It must name bash by absolute path.
# registered_cmd: the beads-superpowers SessionStart command(s), one per line.
registered_cmd() {
  python3 -I -c 'import json,sys
d = json.load(open(sys.argv[1]))
for e in d.get("hooks", {}).get("SessionStart", []):
    for h in e.get("hooks", []):
        if "beads-superpowers" in h.get("command", ""):
            print(h["command"])' "$SANDBOX/.claude/settings.json" 2>/dev/null
}
_cmd=$(registered_cmd)
case "$_cmd" in
  /*) _pass "registered hook command names bash by absolute path: $_cmd" ;;
  *) _fail "registered hook command does not start with /: $_cmd" ;;
esac
_n=0
for _p in "" ".:/usr/bin"; do
  _n=$((_n + 1))
  mkdir -p "$SANDBOX/.rt-reg$_n"
  (cd "$_evil" && env -i HOME="$SANDBOX" XDG_RUNTIME_DIR="$SANDBOX/.rt-reg$_n" PATH="$_p" /bin/sh -c "$_cmd" \
    </dev/null > "$SANDBOX/.reg-out" 2>/dev/null)
  _rc=$?
  if [ "$_rc" -eq 0 ] && python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert "Production-Grade Doctrine" in d["hookSpecificOutput"]["additionalContext"]' < "$SANDBOX/.reg-out" 2>/dev/null; then
    _pass "registered command via sh -c, PATH='$_p', emits the bootstrap envelope"
  else
    _fail "registered command via sh -c, PATH='$_p', did not emit the bootstrap envelope (rc=$_rc)"
  fi
  if compgen -G "$SANDBOX/ran-*" > /dev/null; then
    _fail "registered command via sh -c, PATH='$_p', ran a planted binary: $(cd "$SANDBOX" && echo ran-*)"
    rm -f "$SANDBOX"/ran-*
  else
    _pass "registered command via sh -c, PATH='$_p', ran no planted binary"
  fi
done
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
# It starts from a pre-fix registration (`bash <shim>`) next to a foreign hook:
# the install rewrites ours to the absolute form and leaves the other alone.
_shim="$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
python3 -I -c 'import json,sys
json.dump({"hooks": {"SessionStart": [
    {"matcher": "startup|clear|compact", "hooks": [{"type": "command", "command": "bash " + sys.argv[2]}]},
    {"hooks": [{"type": "command", "command": "bash /somewhere/else.sh"}]}]}},
    open(sys.argv[1], "w"))' "$SANDBOX/.claude/settings.json" "$_shim"
shape_install --with-yegge
_cmd=$(registered_cmd)
case "$_cmd" in
  /*" $_shim") _pass "pre-fix 'bash <shim>' registration rewritten to the absolute form: $_cmd" ;;
  *) _fail "pre-fix 'bash <shim>' registration not rewritten (got: $_cmd)" ;;
esac
assert_json "$SANDBOX/.claude/settings.json" "any(h.get('command') == 'bash /somewhere/else.sh' for e in d['hooks']['SessionStart'] for h in e.get('hooks', []))"
assert_file "$SANDBOX/.claude/agents/yegge.md"
assert_all_skills "$SANDBOX/skills"
assert_shims_never_invoked
shape_uninstall
assert_no_file "$SANDBOX/.claude/agents/yegge.md"

shape_sandbox_teardown
fail_count
