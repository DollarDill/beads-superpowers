#!/usr/bin/env bash
# shellcheck disable=SC2119  # shape_install's flags are optional; none are needed here
# test-backup-collision.sh — a settings backup whose timestamped name is
# already taken. The writer names its backup settings.json.<prefix>-<stamp>
# with 1-second resolution and creates it with O_EXCL, so a second settings
# operation in the same second (an uninstall then a reinstall, or a
# previous-tier cleanup then the register in one run) finds the name taken.
# The op must still happen, behind a backup under a free name, and never
# write to, truncate or remove a file that already has a candidate name.
# When no backup can be made at all, the warning names that cause (not the
# user's file) and the verify step does not claim a stale pre-fix
# `bash <shim>` registration is the hook.
# Collisions are made deterministic by planting the next 30 seconds' names.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# plant <settings file> <prefix> <names per second>: for each of the next 30
# seconds, the stamp itself and <names per second - 1> counter variants
# (-1, -2 ...) are created read-only, holding "planted".
plant() {
  python3 -I - "$@" <<'PY'
import os, sys, time
sf, prefix, per = sys.argv[1], sys.argv[2], int(sys.argv[3])
now = time.time()
for i in range(30):
    stamp = sf + "." + prefix + time.strftime("-%Y%m%d-%H%M%S", time.localtime(now + i))
    for n in range(per):
        p = stamp if n == 0 else stamp + "-" + str(n)
        with open(p, "w") as f:
            f.write("planted\n")
        os.chmod(p, 0o444)
PY
}
# planted_intact <settings file> <expected count>: every planted name is
# still there, still holding "planted".
planted_intact() {
  local got
  got=$(grep -lx planted "$1".* 2>/dev/null | wc -l | tr -d ' ')
  if [ "$got" = "$2" ]; then
    _pass "all $2 planted names still hold their own content"
  else
    _fail "planted names holding their own content: $got, expected $2"
  fi
}
# new_backups <settings file> <prefix>: the names of backups that were not
# planted (one per line).
new_backups() { grep -Lx planted "$1.$2-"* 2>/dev/null; }
# prefix_settings <settings file> <shim>: a pre-fix `bash <shim>` registration
# next to a foreign hook.
prefix_settings() {
  python3 -I -c 'import json,sys
json.dump({"hooks": {"SessionStart": [
    {"matcher": "startup|clear|compact", "hooks": [{"type": "command", "command": "bash " + sys.argv[2]}]},
    {"hooks": [{"type": "command", "command": "bash /somewhere/else.sh"}]}]}},
    open(sys.argv[1], "w"))' "$1" "$2"
}
# registered_ok <settings file> <shim>: our entry is <absolute bash> <shim>
# and the foreign hook is kept.
registered_ok() {
  python3 -I -c 'import json, shlex, sys
d = json.load(open(sys.argv[1]))
ours, foreign = [], False
for e in d["hooks"]["SessionStart"]:
    for h in e.get("hooks", []):
        c = h.get("command", "")
        if "beads-superpowers" in c:
            ours.append(shlex.split(c))
        if c == "bash /somewhere/else.sh":
            foreign = True
ok = (foreign and len(ours) == 1 and len(ours[0]) == 2 and ours[0][1] == sys.argv[2]
      and ours[0][0].startswith("/") and ours[0][0].endswith("/bash"))
sys.exit(0 if ok else 1)' "$1" "$2" 2>/dev/null
}
# one_backup_of <settings file> <prefix> <original copy> <case>: exactly one
# new backup under that prefix, holding the original bytes, mode 0600.
one_backup_of() {
  local b n
  n=$(new_backups "$1" "$2" | grep -c .)
  if [ "$n" != 1 ]; then _fail "[$4] expected one new $2 backup, found $n"; return; fi
  b=$(new_backups "$1" "$2")
  if cmp -s "$b" "$3"; then _pass "[$4] the new backup holds the original bytes: ${b##*/}"; else _fail "[$4] the new backup does not hold the original bytes"; fi
  if [ "$(python3 -I -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$b")" = 0o600 ]; then
    _pass "[$4] the new backup is 0600"
  else
    _fail "[$4] the new backup is not 0600"
  fi
}

# --- Install over a pre-fix registration; the stamp and -1 are taken ---
shape_sandbox_setup claude
sf="$SANDBOX/.claude/settings.json"
shim="$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
mkdir -p "$SANDBOX/.claude"
prefix_settings "$sf" "$shim"
cp -f "$sf" "$SANDBOX/orig.json"
plant "$sf" backup 2
shape_install
if registered_ok "$sf" "$shim"; then _pass "[install] pre-fix registration rewritten to the absolute form"; else _fail "[install] pre-fix registration not rewritten: $(head -c 400 "$sf")"; fi
planted_intact "$sf" 60
one_backup_of "$sf" backup "$SANDBOX/orig.json" install
b=$(new_backups "$sf" backup)
# bash 3.2 prints the ~ of ${SETTINGS_BACKUP/$HOME/\~} as \~; bash 4+ as ~.
named=$(sed -n 's/.*Settings backup: \\\{0,1\}~//p' "$SANDBOX/install.log")
if [ -n "$b" ] && [ "$SANDBOX$named" = "$b" ]; then
  _pass "[install] the summary names the backup actually made"
else
  _fail "[install] the summary names '$named', the backup made is '${b#"$SANDBOX"}'"
fi
assert_not_in_log "NOT registered"
assert_not_in_log "could not be read"
assert_in_log "Hook registered in settings.json"
shape_sandbox_teardown

# --- Every candidate name taken: the stamp and -1 .. -99 ---
# The op is refused, the warning names the backup as the cause, and verify
# does not count the stale pre-fix `bash <shim>` as the registered hook.
shape_sandbox_setup claude
sf="$SANDBOX/.claude/settings.json"
shim="$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
mkdir -p "$SANDBOX/.claude"
prefix_settings "$sf" "$shim"
cp -f "$sf" "$SANDBOX/orig.json"
plant "$sf" backup 100
shape_install
if cmp -s "$sf" "$SANDBOX/orig.json"; then _pass "[all names taken] settings left byte-for-byte unchanged"; else _fail "[all names taken] settings were changed"; fi
planted_intact "$sf" 3000
n=$(new_backups "$sf" backup | grep -c .)
if [ "$n" = 0 ]; then _pass "[all names taken] no backup made"; else _fail "[all names taken] $n new backup(s) made"; fi
if grep -q "backup of $sf could not be made.*left unchanged.*NOT registered" "$SANDBOX/install.log"; then
  _pass "[all names taken] the warning names the backup as the cause"
else
  _fail "[all names taken] no warning naming the backup as the cause: $(grep -m1 "$sf" "$SANDBOX/install.log")"
fi
assert_not_in_log "could not be read"
assert_not_in_log "Fix the file"
assert_not_in_log "Hook registered in settings.json"
assert_in_log "Current hook registration not found in settings.json"
shape_sandbox_teardown

# --- One run: the previous-tier cleanup, then the register ---
# Both write the settings file and back it up; both prefixes are taken.
shape_sandbox_setup claude
sf="$SANDBOX/.claude/settings.json"
shim="$SANDBOX/.claude/hooks/beads-superpowers-session-start.sh"
mkdir -p "$SANDBOX/.claude" "$SANDBOX/skills"
printf '0.0.1:local\n' > "$SANDBOX/skills/.beads-superpowers-version"
prefix_settings "$sf" "$shim"
cp -f "$sf" "$SANDBOX/orig.json"
plant "$sf" backup 2
plant "$sf" backup-previous 2
shape_install
assert_in_log "Auto-uninstalling previous install"
if registered_ok "$sf" "$shim"; then _pass "[cleanup + register] registered in the absolute form"; else _fail "[cleanup + register] not registered in the absolute form: $(head -c 400 "$sf")"; fi
planted_intact "$sf" 120
one_backup_of "$sf" backup-previous "$SANDBOX/orig.json" "cleanup + register"
n=$(new_backups "$sf" backup | grep -vc 'backup-previous-')
if [ "$n" = 1 ]; then _pass "[cleanup + register] the register made one backup"; else _fail "[cleanup + register] the register made $n backups"; fi
assert_not_in_log "NOT removed"
assert_not_in_log "NOT registered"
assert_in_log "Hook registered in settings.json"
shape_sandbox_teardown

fail_count
