#!/usr/bin/env bash
# test-install-settings.sh — install.sh's settings handling. Every python3
# call ignores a json.py planted in the directory install.sh is run from, and
# a settings path with a ' in it is read correctly.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
fail=0
n=0

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
