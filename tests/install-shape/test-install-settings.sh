#!/usr/bin/env bash
# test-install-settings.sh — install.sh's install-side settings writers
# (register_hook, cleanup_stale_reminder, the previous-tier cleanup) never
# lose the user's settings: a file the rewrite cannot be completed for (too
# deeply nested for the encoder, a write that runs out of room, a read-only
# file) is left byte-for-byte unchanged or restored, with fixed-text warnings
# and no exception text, and no stray backup. Malformed hook entries never
# crash the cleanup. Every python3 call ignores a json.py planted in the cwd,
# and a settings path with a ' in it is read correctly.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
REAL_PY=$(command -v python3)
fail=0
n=0

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}
backups() { find "$1/.claude" -maxdepth 1 \( -name 'settings.json.backup-*' -o -name 'settings.json.bak-*' \) -exec echo x \; | wc -l | tr -d ' '; }
no_exception_text() {
  if grep -Eq "Traceback|Error|File \"|errno|USERKEY" "$log"; then
    echo "FAIL [$1]: exception text in output:"; grep -E "Traceback|Error|File \"|errno|USERKEY" "$log" | head -3; fail=1
  fi
}

# new_home: a fresh HOME in $h, log path in $log.
new_home() {
  n=$((n + 1))
  h="$SANDBOX/h$n"; log="$SANDBOX/h$n.log"
  mkdir -p "$h/.claude"
}
install_in() {
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$log" 2>&1
  rc=$?
}
# deep <file> <depth> [extra JSON members]: valid JSON nested <depth> deep.
# At 1200 the C parser loads it but json.dump's pure-Python indent encoder
# cannot write it (RecursionError part-way); json.dumps can on a Python whose
# C encoder handles indent. At 60000 nothing can write it back: either the
# parser or every encoder raises RecursionError, whatever the Python.
deep() {
  "$REAL_PY" -I -c '
import sys
d = int(sys.argv[2])
extra = sys.argv[3] if len(sys.argv) > 3 else ""
s = "{\"USERKEY\": " + "[" * d + "]" * d + ", \"keep\": \"USERDATA\"" + extra + "}"
open(sys.argv[1], "w").write(s)
' "$@"
}

# The file must be unchanged, the hook NOT registered (named in a warning),
# no exception text, no backup left, and the rest of the install done.
unchanged_check() {
  local name="$1" before="$2"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [$name]: settings file was modified ($(wc -c <"$h/.claude/settings.json") bytes now)"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT registered" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT registered'"; fail=1; fi
  no_exception_text "$name"
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [$name]: a stray backup was left"; fail=1; fi
  if [ ! -f "$h/skills/.beads-superpowers-version" ]; then echo "FAIL [$name]: rest of the install missing"; fail=1; fi
}

# register_hook: too deeply nested to re-encode.
new_home
deep "$h/.claude/settings.json" 60000
before=$(sha "$h/.claude/settings.json")
install_in
unchanged_check "register: depth 60000" "$before"

# register_hook at depth 1200 (the review's P2 case): either the file cannot
# be written back and is left unchanged as above, or it is written in full,
# keeping every byte of the user's data, behind a backup of the original.
new_home
deep "$h/.claude/settings.json" 1200
cp -f "$h/.claude/settings.json" "$SANDBOX/p2.orig"
before=$(sha "$h/.claude/settings.json")
install_in
if [ "$before" = "$(sha "$h/.claude/settings.json")" ]; then
  unchanged_check "register: depth 1200" "$before"
else
  name="register: depth 1200"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  no_exception_text "$name"
  if ! "$REAL_PY" -I -c '
import json, sys
old, new = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
ss = new.pop("hooks")["SessionStart"]
ok = old == new and len(ss) == 1 and "beads-superpowers" in json.dumps(ss)
sys.exit(0 if ok else 1)
' "$SANDBOX/p2.orig" "$h/.claude/settings.json" 2>/dev/null; then echo "FAIL [$name]: the rewritten file lost user data or has no hook"; fail=1; fi
  if [ "$(backups "$h")" != 1 ]; then echo "FAIL [$name]: expected one backup, found $(backups "$h")"; fail=1; fi
  for b in "$h/.claude/settings.json.backup-"*; do
    if [ -f "$b" ] && [ "$before" != "$(sha "$b")" ]; then echo "FAIL [$name]: the backup does not hold the original bytes"; fail=1; fi
  done
fi

# cleanup_stale_reminder: the same file, with a stale reminder entry.
new_home
deep "$h/.claude/settings.json" 60000 ', "hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash /x/beads-superpowers-reminder.sh"}]}]}'
before=$(sha "$h/.claude/settings.json")
install_in
unchanged_check "stale-reminder cleanup: depth 60000" "$before"
if ! grep -q "stale UserPromptSubmit hook was not cleaned" "$log"; then echo "FAIL [stale-reminder cleanup: depth 60000]: no warning that the stale entry was not cleaned"; fail=1; fi

# The previous-tier cleanup (a version file from another release).
new_home
deep "$h/.claude/settings.json" 60000 ', "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "bash /x/beads-superpowers-session-start.sh"}]}]}'
mkdir -p "$h/skills"; printf '0.0.1:local\n' >"$h/skills/.beads-superpowers-version"
before=$(sha "$h/.claude/settings.json")
install_in
unchanged_check "previous-tier cleanup: depth 60000" "$before"

# The write runs out of room part-way (RLIMIT_FSIZE: EFBIG, like ENOSPC):
# the original is written back and checked, and no backup is left. The file
# fits under the limit; the rewrite (one entry longer) does not.
new_home
mkdir -p "$SANDBOX/fsize"
printf '#!/bin/bash\nulimit -f 10\nexec %q "$@"\n' "$REAL_PY" >"$SANDBOX/fsize/python3"
chmod +x "$SANDBOX/fsize/python3"
"$REAL_PY" -I -c '
import json, sys
s = {"USERKEY": "USERDATA", "pad": ""}
s["pad"] = "A" * (10240 - 40 - len(json.dumps(s, indent=2)))
open(sys.argv[1], "w").write(json.dumps(s, indent=2) + "\n")
' "$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" PATH="$SANDBOX/fsize:$PATH" \
  bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$log" 2>&1
rc=$?
unchanged_check "register: write runs out of room" "$before"
if ! grep -q "$h/.claude/settings.json.*original contents were restored" "$log"; then echo "FAIL [register: write runs out of room]: no message saying the original was restored"; fail=1; fi

# A read-only settings file is left alone with a warning.
new_home
printf '{"USERKEY": "USERDATA"}\n' >"$h/.claude/settings.json"
chmod 444 "$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
install_in
unchanged_check "register: read-only settings file" "$before"
if ! grep -q "$h/.claude/settings.json could not be opened for writing.*NOT registered" "$log"; then echo "FAIL [register: read-only settings file]: the warning does not say the file could not be opened for writing"; grep -m1 "settings.json" "$log"; fail=1; fi
chmod 644 "$h/.claude/settings.json"

# No settings file, and its directory is read-only: it cannot be created,
# and the warning says so (it does not blame a file that is not there).
new_home
mkdir -p "$h/.claude/hooks"
chmod 555 "$h/.claude"
install_in
chmod 755 "$h/.claude"
if [ "$rc" != 0 ]; then echo "FAIL [register: settings cannot be created]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ -e "$h/.claude/settings.json" ]; then echo "FAIL [register: settings cannot be created]: a settings file appeared"; fail=1; fi
if ! grep -q "$h/.claude/settings.json does not exist and could not be created.*NOT registered" "$log"; then echo "FAIL [register: settings cannot be created]: the warning does not say the file could not be created"; grep -m1 "settings.json" "$log"; fail=1; fi
no_exception_text "register: settings cannot be created"

# Malformed UserPromptSubmit entries: the stale reminder is removed, every
# other entry is kept as it was, and the hook is registered.
new_home
cat >"$h/.claude/settings.json" <<'EOF'
{"hooks": {"UserPromptSubmit": ["junk", {"hooks": null}, {"hooks": ["x", {"command": 5}, {"type": "command", "command": "bash /x/beads-superpowers-reminder.sh"}]}]}}
EOF
install_in
if [ "$rc" != 0 ]; then echo "FAIL [malformed reminder entries]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
no_exception_text "malformed reminder entries"
if ! "$REAL_PY" -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
ups = d["hooks"]["UserPromptSubmit"]
ok = ups == ["junk", {"hooks": None}, {"hooks": ["x", {"command": 5}]}]
ok = ok and any("beads-superpowers" in json.dumps(e) for e in d["hooks"]["SessionStart"])
sys.exit(0 if ok else 1)
' "$h/.claude/settings.json"; then echo "FAIL [malformed reminder entries]: settings not as expected: $(head -c 400 "$h/.claude/settings.json")"; fail=1; fi

# A non-object top level mentioning the reminder: left untouched, no crash.
new_home
printf '["superpowers-reminder"]\n' >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
install_in
if [ "$rc" != 0 ]; then echo "FAIL [non-object top level]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
no_exception_text "non-object top level"
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [non-object top level]: settings file was modified"; fail=1; fi
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [non-object top level]: a stray backup was left"; fail=1; fi

# The normal path: one backup holding the original bytes, the hook
# registered, the file rewritten in place (a hard link still shares it).
new_home
printf '{"USERKEY": "USERDATA"}\n' >"$h/.claude/settings.json"
ln "$h/.claude/settings.json" "$h/settings.hardlink"
before=$(sha "$h/.claude/settings.json")
install_in
if [ "$rc" != 0 ]; then echo "FAIL [normal path]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [normal path]: expected one backup, found $(backups "$h")"; fail=1; fi
for b in "$h/.claude/settings.json.backup-"*; do
  if [ -f "$b" ] && [ "$before" != "$(sha "$b")" ]; then echo "FAIL [normal path]: the backup does not hold the original bytes"; fail=1; fi
done
if ! grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q USERDATA "$h/.claude/settings.json"; then echo "FAIL [normal path]: hook not registered or user data lost"; fail=1; fi
if [ ! "$h/.claude/settings.json" -ef "$h/settings.hardlink" ]; then echo "FAIL [normal path]: the file was replaced, not rewritten in place"; fail=1; fi
if ! grep -q "Hook registered in settings.json" "$log"; then echo "FAIL [normal path]: verify did not find the hook"; fail=1; fi

# A json.py planted in the directory install.sh is run from never runs:
# not on install (with an upstream-plugin list to read), not on --uninstall.
new_home
mkdir -p "$SANDBOX/evil" "$h/.claude/plugins"
printf '{"plugins": {}}\n' >"$h/.claude/plugins/installed_plugins.json"
printf '{"USERKEY": "superpowers-reminder"}\n' >"$h/.claude/settings.json"
printf 'open(%s, "a").write("ran\\n")\n' "'$SANDBOX/planted.marker'" >"$SANDBOX/evil/json.py"
(cd "$SANDBOX/evil" && HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
  bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$log" 2>&1)
if [ -e "$SANDBOX/planted.marker" ]; then echo "FAIL [planted json.py]: it ran during install"; fail=1; fi
rm -f "$SANDBOX/planted.marker"
(cd "$SANDBOX/evil" && HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
  bash "$REPO_ROOT/install.sh" --uninstall >>"$log" 2>&1)
if [ -e "$SANDBOX/planted.marker" ]; then echo "FAIL [planted json.py]: it ran during --uninstall"; fail=1; fi

# A HOME with a ' in it: verify reads the settings file.
n=$((n + 1)); h="$SANDBOX/it's h$n"; log="$SANDBOX/h$n.log"; mkdir -p "$h/.claude"
install_in
if [ "$rc" != 0 ]; then echo "FAIL [quote in HOME]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if ! grep -q "Hook registered in settings.json" "$log"; then echo "FAIL [quote in HOME]: verify did not find the registered hook"; grep -E "Hook|settings" "$log" | head -3; fail=1; fi

if [ "$fail" -eq 0 ]; then echo "PASS: install.sh handles the settings file safely"; fi
exit "$fail"
