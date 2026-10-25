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

# uninstall <home> <log>: lay down a real install first (rest-of-uninstall
# evidence), then restore the settings file to what the case wants and run it.
BSP='{"type":"command","command":"bash /x/beads-superpowers-session-start.sh"}'
FOREIGN='{"type":"command","command":"echo foreign"}'

# run_case <name> <settings content or "@dir"> -> sets $h $log $rc
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
backups() { find "$1/.claude" -maxdepth 1 -name 'settings.json.backup-*' | wc -l | tr -d ' '; }

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
shape_case "hooks null" '{"hooks": null, "keep": 1}' 'd == {"hooks": None, "keep": 1} or d.get("keep") == 1'
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

if [ "$fail" -eq 0 ]; then echo "PASS: --uninstall handles the settings file safely"; fi
exit "$fail"
