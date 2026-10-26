#!/usr/bin/env bash
# test-uninstall-settings.sh — install.sh --uninstall against odd settings files:
# an unparseable or unreadable file is left byte-for-byte untouched with no
# backup and a warning that the entries were NOT removed, while the rest of the
# uninstall still runs and exits 0; malformed-but-valid shapes never crash; a
# settings path with shell/Python metacharacters is handled; a normal file is
# cleaned and backed up once.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
fail=0
n=0

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# setup lays down a real install first (rest-of-uninstall evidence) and removes
# the settings file the install wrote; each case then writes the one it wants.
BSP='{"type":"command","command":"bash /x/beads-superpowers-session-start.sh"}'
FOREIGN='{"type":"command","command":"echo foreign"}'

# setup / run_uninstall set $h $log $rc for the case that follows.
setup() {
  n=$((n + 1))
  h="$SANDBOX/h$n"; log="$SANDBOX/h$n.log"
  mkdir -p "$h/.claude"
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$SANDBOX/h$n.install.log" 2>&1
  rm -f "$h/.claude/settings.json"
}
run_uninstall() {
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --uninstall >"$log" 2>&1
  rc=$?
}
backups() { find "$1/.claude" -maxdepth 1 -name 'settings.json.backup-*' -exec echo x \; | wc -l | tr -d ' '; }

untouched_case() {
  local name="$1" content="$2" before after
  setup
  # shellcheck disable=SC2059
  printf "$content" >"$h/.claude/settings.json"
  before=$(sha "$h/.claude/settings.json")
  run_uninstall
  after=$(sha "$h/.claude/settings.json")
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$after" ]; then echo "FAIL [$name]: settings file was modified"; fail=1; fi
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [$name]: a backup was created"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT removed'"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: claimed hooks were removed"; fail=1; fi
  if grep -q "Traceback" "$log"; then echo "FAIL [$name]: traceback in output"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}

untouched_case "truncated JSON" '{"hooks": '
untouched_case "not json" 'not json'
untouched_case "empty file" ''
untouched_case "whitespace only" ' \n\n'

# A directory at the settings path is handled like invalid JSON.
setup
mkdir -p "$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [directory]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ ! -d "$h/.claude/settings.json" ]; then echo "FAIL [directory]: settings path was modified"; fail=1; fi
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [directory]: a backup was created"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [directory]: no warning"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [directory]: traceback"; fail=1; fi
if [ -e "$h/skills/.beads-superpowers-version" ]; then echo "FAIL [directory]: rest of the uninstall did not run"; fail=1; fi

# Valid-JSON shapes that are not what we write: never crash, foreign data kept.
shape_case() {
  local name="$1" content="$2" check="$3"
  setup
  printf '%s' "$content" >"$h/.claude/settings.json"
  run_uninstall
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if grep -q "Traceback" "$log"; then echo "FAIL [$name]: traceback"; fail=1; fi
  if ! python3 -I - "$h/.claude/settings.json" "$check" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
  then echo "FAIL [$name]: settings content wrong after uninstall"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}
shape_case "hooks null" '{"hooks": null, "keep": 1}' 'd == {"hooks": None, "keep": 1}'
if [ "$(cat "$h/.claude/settings.json")" != '{"hooks": null, "keep": 1}' ]; then echo "FAIL [hooks null]: file not byte-identical"; fail=1; fi
shape_case "hooks a list" '{"hooks": [1], "keep": 1}' 'd["hooks"] == [1] and d["keep"] == 1'
shape_case "SessionStart not a list" '{"hooks": {"SessionStart": "x", "Other": [1]}}' 'd["hooks"]["SessionStart"] == "x"'
shape_case "mixed entries" \
  "{\"hooks\": {\"SessionStart\": [1, null, {\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}" \
  'd["hooks"]["SessionStart"] == [1, None, {"hooks": [{"type": "command", "command": "echo foreign"}]}]'
shape_case "top level a list" '[1, 2]' 'd == [1, 2]'

# A normal file: entries removed, foreign kept, exactly one backup, info shown.
setup
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}], \"UserPromptSubmit\": [{\"hooks\": [$BSP]}]}}" >"$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [normal]: exit $rc"; fail=1; fi
if grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q "echo foreign" "$h/.claude/settings.json"; then echo "FAIL [normal]: wrong content"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [normal]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [normal]: no removal message"; fail=1; fi

# A settings path with a double quote, backslash and dollar in it.
n=$((n + 1))
h="$SANDBOX/h$n\"q\\\$x"; log="$SANDBOX/h$n.log"
mkdir -p "$h/.claude"
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}" >"$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [odd path]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q "echo foreign" "$h/.claude/settings.json"; then echo "FAIL [odd path]: wrong content"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [odd path]: traceback"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [odd path]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [odd path]: no removal message"; fail=1; fi

# The same with a newline in the path.
n=$((n + 1))
h="$SANDBOX/h$n"$'\n'"nl"; log="$SANDBOX/h$n.log"
mkdir -p "$h/.claude"
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}" >"$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [newline path]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q "echo foreign" "$h/.claude/settings.json"; then echo "FAIL [newline path]: wrong content"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [newline path]: traceback"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [newline path]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [newline path]: no removal message"; fail=1; fi

# Valid file with nothing of ours in it: byte-identical, no backup, no removal claim.
setup
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$FOREIGN]}]}}" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [nothing to remove]: exit $rc"; fail=1; fi
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [nothing to remove]: file was rewritten"; fail=1; fi
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [nothing to remove]: a backup was created"; fail=1; fi
if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [nothing to remove]: claimed hooks were removed"; fail=1; fi

# Failure paths on a file that HAS entries to remove: no exception text, file
# untouched, no stray backup, fixed warning, rest of the uninstall runs, exit 0.
failure_case() {
  local name="$1" before
  before=$(sha "$h/.claude/settings.json")
  run_uninstall
  chmod 755 "$h/.claude"; chmod 644 "$h/.claude/settings.json"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [$name]: settings file was modified"; fail=1; fi
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [$name]: stray backup left"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT removed'"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: claimed hooks were removed"; fail=1; fi
  if grep -Eq "Traceback|Error|File \"|errno|Permission denied" "$log"; then echo "FAIL [$name]: exception text in output"; grep -E "Traceback|Error|File \"|errno|Permission denied" "$log" | head -3; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}
WITH_ENTRIES="{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}"

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
chmod 444 "$h/.claude/settings.json"
failure_case "read-only settings file"

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
chmod 555 "$h/.claude"
failure_case "unwritable .claude dir"

setup
python3 -I -c 'import sys; sys.stdout.write("[" * 100000)' >"$h/.claude/settings.json"
failure_case "deeply nested JSON"

# A rewrite that fails after the file was opened (file-size limit hit partway):
# the file must stay byte-identical, no backup or temp file is left, and the
# message must not claim a removal. `ulimit -f 1` is 1024 bytes in bash's
# default mode. The limit applies only inside the subshell; the log is written
# by `cat` outside it.
setup
F3="{\"hooks\":{\"SessionStart\":[{\"hooks\":[$BSP]}"
for _ in 1 2 3 4 5 6 7 8; do F3="$F3,{\"hooks\":[$FOREIGN]}"; done
printf '%s' "$F3]}}" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
if ! python3 -I - "$h/.claude/settings.json" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
d["hooks"]["SessionStart"] = d["hooks"]["SessionStart"][1:]
sys.exit(0 if os.path.getsize(sys.argv[1]) < 1024 < len(json.dumps(d, indent=2)) + 1 else 1)
PY
then echo "FAIL [write fails partway]: fixture does not straddle the 1024-byte limit"; fail=1; fi
( ulimit -f 1; HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" bash "$REPO_ROOT/install.sh" --uninstall 2>&1 ) | cat >"$log"
rc=${PIPESTATUS[0]}
# bash before 5.1 writes heredocs to a temp file, which the limit also blocks,
# so python never runs and the rewrite is not reached: say so, don't fail.
if grep -q "cannot create temp file for here document" "$log"; then
  echo "SKIP [write fails partway]: this bash cannot create a heredoc under the limit; the settings file is still checked"
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [write fails partway]: settings file was modified"; fail=1; fi
else
  if [ "$rc" != 0 ]; then echo "FAIL [write fails partway]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [write fails partway]: settings file was modified ($(wc -c <"$h/.claude/settings.json") bytes now)"; fail=1; fi
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [write fails partway]: stray backup left"; fail=1; fi
  if [ -n "$(find "$h/.claude" -maxdepth 1 -name '*.tmp' -print)" ]; then echo "FAIL [write fails partway]: temp file left"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*left unchanged.*NOT removed" "$log"; then echo "FAIL [write fails partway]: no warning naming the file, 'left unchanged' and 'NOT removed'"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [write fails partway]: claimed hooks were removed"; fail=1; fi
  if grep -Eq "Traceback|Error|File \"|errno" "$log"; then echo "FAIL [write fails partway]: exception text in output"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [write fails partway]: rest of the uninstall did not run"; fail=1
  fi
fi

# A symlinked settings file stays a symlink; its target is cleaned.
setup
mkdir -p "$h/dotfiles"
printf '%s' "$WITH_ENTRIES" >"$h/dotfiles/settings.json"
ln -s "$h/dotfiles/settings.json" "$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [symlink]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ ! -L "$h/.claude/settings.json" ]; then echo "FAIL [symlink]: settings.json is no longer a symlink"; fail=1; fi
if grep -q "beads-superpowers" "$h/dotfiles/settings.json" || ! grep -q "echo foreign" "$h/dotfiles/settings.json"; then echo "FAIL [symlink]: target not cleaned"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [symlink]: no removal message"; fail=1; fi

# A read-only backup that already has this run's one-second name is not ours:
# it must survive, byte-identical. Names are pre-made for the next 30 seconds.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
python3 -I - "$h/.claude/settings.json" <<'PY'
import os, sys, time
now = time.time()
for i in range(30):
    p = sys.argv[1] + ".backup-" + time.strftime("%Y%m%d-%H%M%S", time.localtime(now + i))
    with open(p, "w") as f:
        f.write("pre-existing\n")
    os.chmod(p, 0o444)
PY
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [pre-existing backup]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ "$(backups "$h")" != 30 ]; then echo "FAIL [pre-existing backup]: expected the 30 pre-existing backups, found $(backups "$h")"; fail=1; fi
if grep -L -x "pre-existing" "$h/.claude/settings.json.backup-"* 2>/dev/null | grep -q .; then echo "FAIL [pre-existing backup]: a pre-existing backup was overwritten"; fail=1; fi
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [pre-existing backup]: settings file was modified"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [pre-existing backup]: no warning naming the file and 'NOT removed'"; fail=1; fi
if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [pre-existing backup]: claimed hooks were removed"; fail=1; fi

if [ "$fail" -eq 0 ]; then echo "PASS: --uninstall handles the settings file safely"; fi
exit "$fail"
