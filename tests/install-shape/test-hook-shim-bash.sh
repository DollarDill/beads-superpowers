#!/usr/bin/env bash
# test-hook-shim-bash.sh — the hook command install.sh registers never runs a
# bash from inside the project, even when an ABSOLUTE PATH entry points into
# it (npm exec's <proj>/node_modules/.bin, direnv PATH_add). The shim walks
# its cleaned PATH and takes the first bash that passes the containment rule
# it applies to $BASH, then falls back to $BASH. So an in-project bash first
# on PATH is skipped for a real bash further down, and one that is the only
# bash on PATH is refused.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
fail=0
h="$SANDBOX/home"
mkdir -p "$h/.claude"

HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
  bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$SANDBOX/install.log" 2>&1 \
  || { echo "FAIL: install exited non-zero"; sed -n '1,30p' "$SANDBOX/install.log"; exit 1; }
cmd=$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
print([h["command"] for e in d["hooks"]["SessionStart"] for h in e["hooks"] if "beads-superpowers" in h["command"]][0])
' "$h/.claude/settings.json") || { echo "FAIL: no registered hook command"; exit 1; }

# Planted bashes inside the project only log that they ran. The real bash
# outside it logs, then runs /bin/bash, so the hook still produces output.
proj="$SANDBOX/proj"
mkdir -p "$proj/.git" "$proj/sub" "$proj/node_modules/.bin" "$SANDBOX/real"
for d in "$proj/sub" "$proj/node_modules/.bin"; do
  printf '#!/bin/sh\necho "%s" >>"%s"\n' "$d" "$SANDBOX/planted.marker" >"$d/bash"
  chmod +x "$d/bash"
done
printf '#!/bin/sh\necho real >>"%s"\nexec /bin/bash "$@"\n' "$SANDBOX/real.marker" >"$SANDBOX/real/bash"
chmod +x "$SANDBOX/real/bash"

# hook_run <PATH> [CLAUDE_PROJECT_DIR]: the registered command, run through a
# shell from the project the way a harness runs it.
hook_run() {
  rm -f "$SANDBOX/planted.marker" "$SANDBOX/real.marker"
  (cd "$proj" && env -i HOME="$h" PATH="$1" ${2:+CLAUDE_PROJECT_DIR="$2"} /bin/sh -c "$cmd" >"$SANDBOX/out" 2>"$SANDBOX/err" </dev/null)
}
not_planted() {
  if [ -e "$SANDBOX/planted.marker" ]; then echo "FAIL [$1]: a bash from inside the project ran: $(cat "$SANDBOX/planted.marker")"; fail=1; fi
}
# The real bash further down PATH ran the hook.
real_used() {
  not_planted "$1"
  if [ ! -e "$SANDBOX/real.marker" ]; then echo "FAIL [$1]: the bash further down PATH was not used"; fail=1; fi
  if ! python3 -I -m json.tool <"$SANDBOX/out" >/dev/null 2>&1; then echo "FAIL [$1]: the hook produced no JSON: $(head -c 200 "$SANDBOX/out")"; fail=1; fi
}

hook_run "$proj/sub:$SANDBOX/real:/usr/bin:/bin" "$proj"
real_used "absolute in-project PATH entry first, CLAUDE_PROJECT_DIR set"
hook_run "$proj/node_modules/.bin:$SANDBOX/real:/usr/bin:/bin"
real_used "absolute node_modules/.bin entry first, root from .git"
hook_run "$proj/sub/../sub:$SANDBOX/real:/usr/bin:/bin" "$proj"
real_used "in-project PATH entry spelled with .. first"

# The in-project bash is the only bash on PATH: refused.
hook_run "$proj/sub" "$proj"
not_planted "in-project bash is the only bash on PATH"

# Control: a bash outside the project, first on PATH, is used.
hook_run "$SANDBOX/real:/usr/bin:/bin" "$proj"
real_used "control: bash outside the project first on PATH"

# When hook_bash finds no usable bash, every setup_hooks caller names that
# cause, not python3. Each caller line runs against the real setup_hooks
# with hook_bash stubbed to fail (no /bin/bash host needed); a host without
# python3 still gets the python3 advice.
{
  awk '/^setup_hooks\(\) \{$/,/^}$/' "$REPO_ROOT/install.sh"
  awk '/^hook_setup_failed\(\) \{$/,/^}$/' "$REPO_ROOT/install.sh"
} >"$SANDBOX/setup.sh"
callers=$(grep -E '^[[:space:]]*setup_hooks( |$).*\|\| ' "$REPO_ROOT/install.sh")
if [ "$(printf '%s\n' "$callers" | grep -c .)" != 4 ]; then echo "FAIL: expected 4 setup_hooks callers in install.sh, found: $callers"; fail=1; fi
while IFS= read -r line; do
  # shellcheck disable=SC2016 # $1/$2 are expanded by the inner bash
  msg=$(HAS_PYTHON3=1 bash -c 'warn() { echo "warn $1"; }; info() { :; }; hook_bash() { return 1; }; STAGING_DIR=/nonexistent; . "$1"; eval "$2"' _ "$SANDBOX/setup.sh" "$line" 2>&1)
  if [[ "$msg" == *"no usable bash outside the project"* ]] && [[ "$msg" != *python3* ]]; then :; else
    echo "FAIL [no usable bash]: caller '${line#"${line%%[![:space:]]*}"}' printed: $msg"; fail=1
  fi
  # shellcheck disable=SC2016 # $1/$2 are expanded by the inner bash
  msg=$(HAS_PYTHON3=0 bash -c 'warn() { echo "warn $1"; }; info() { :; }; hook_bash() { return 1; }; STAGING_DIR=/nonexistent; . "$1"; eval "$2"' _ "$SANDBOX/setup.sh" "$line" 2>&1)
  if [[ "$msg" == *"once python3 is available"* ]] && [[ "$msg" != *"no usable bash"* ]]; then :; else
    echo "FAIL [no python3]: caller '${line#"${line%%[![:space:]]*}"}' printed: $msg"; fail=1
  fi
done <<<"$callers"

if [ "$fail" -eq 0 ]; then echo "PASS: the registered hook never runs a bash from inside the project"; fi
exit "$fail"
