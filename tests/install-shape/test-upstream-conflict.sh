#!/usr/bin/env bash
# test-upstream-conflict.sh — detect_upstream_conflict: an installed upstream
# superpowers plugin (superpowers@claude-plugins-official in
# installed_plugins.json) is detected reliably, and the install WARNS (duplicate
# skill loading, the exact uninstall command) and CONTINUES. A missing key, a
# malformed or unreadable plugins file gives no warning and no traceback.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
fail=0
n=0

# run_case <name> <plugins file content | -> (- = no file); sets $h $log $rc
run_case() {
  n=$((n + 1))
  h="$SANDBOX/h$n"; log="$SANDBOX/h$n.log"
  mkdir -p "$h/.claude/plugins"
  # shellcheck disable=SC2059
  [ "$2" = "-" ] || printf "$2" >"$h/.claude/plugins/installed_plugins.json"
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$log" 2>&1
  rc=$?
  if [ "$rc" != 0 ]; then echo "FAIL [$1]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ ! -f "$h/skills/.beads-superpowers-version" ]; then echo "FAIL [$1]: the install did not finish"; fail=1; fi
  if grep -q "Traceback" "$log"; then echo "FAIL [$1]: traceback in output"; fail=1; fi
}
warned() { grep -q "claude plugin uninstall superpowers@claude-plugins-official" "$log"; }

run_case "upstream key present" '{"plugins": {"superpowers@claude-plugins-official": [{}]}}'
if ! warned; then echo "FAIL [upstream key present]: no warning with the uninstall command"; fail=1; fi
if ! grep -q "duplicate skill loading" "$log"; then echo "FAIL [upstream key present]: warning does not explain duplicate skill loading"; fail=1; fi
if ! grep -q "^warn " "$log"; then echo "FAIL [upstream key present]: not worded as a warning"; fail=1; fi
if grep -q "^error " "$log"; then echo "FAIL [upstream key present]: reported as an error"; fail=1; fi

run_case "upstream key absent" '{"plugins": {"other@x": [{}]}}'
if warned; then echo "FAIL [upstream key absent]: warned without the key"; fail=1; fi
run_case "no plugins file" -
if warned; then echo "FAIL [no plugins file]: warned"; fail=1; fi
for bad in '{"plugins": ' 'not json' '' '[1, 2]' '{"plugins": 5}' '{"plugins": null}'; do
  run_case "plugins file: $bad" "$bad"
  if warned; then echo "FAIL [plugins file: $bad]: warned"; fail=1; fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: an upstream superpowers plugin is detected, warned about, and the install continues"; fi
exit "$fail"
