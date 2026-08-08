#!/usr/bin/env bash
# lint-shell.sh — shellcheck gate over TRACKED shell scripts, with a baseline.
# Fails only on findings NOT in scripts/lint-shell-baseline.txt.
# Visible-SKIP when shellcheck is absent (same convention as node-test skips).
# Usage: scripts/lint-shell.sh [--update-baseline]
# Prior art: obra/superpowers scripts/lint-shell.sh (v6.1.x) — reimplemented for baseline+SKIP.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
BASELINE="scripts/lint-shell-baseline.txt"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "SKIP: shellcheck not installed — shell lint not run (install shellcheck to enable)"
  exit 0
fi

mapfile -t files < <(git ls-files '*.sh')
# tests/skills/helpers/bd-readonly/bd is a bash script with no .sh extension (it must
# be named exactly `bd` to shadow the real binary on PATH), so the glob above never
# finds it. List it explicitly or it escapes this lint gate permanently.
files+=("tests/skills/helpers/bd-readonly/bd")
[ "${#files[@]}" -gt 0 ] || { echo "PASS: no tracked shell scripts"; exit 0; }

# One finding per line: file:line:SCcode (stable across runs; line drift = new finding, acceptable)
findings=$(shellcheck --severity=warning --format=gcc "${files[@]}" 2>/dev/null \
  | sed -nE 's/^([^:]+):([0-9]+):[0-9]+: (note|warning|error): .*\[(SC[0-9]+)\]$/\1:\2:\4/p' | sort -u)

if [ "${1:-}" = "--update-baseline" ]; then
  { echo "# lint-shell baseline — findings present at adoption (burn-down bead tracks removal)"
    echo "# generated with: $(shellcheck --version | grep '^version')"
    echo "$findings"; } > "$BASELINE"
  echo "baseline updated: $(echo "$findings" | grep -c . ) findings"
  exit 0
fi

new=$(comm -23 <(echo "$findings") <(grep -v '^#' "$BASELINE" 2>/dev/null | sort -u))
if [ -n "$new" ]; then
  echo "FAIL: new shellcheck findings not in baseline:"; echo "$new"; exit 1
fi
echo "PASS: no new shellcheck findings ($(echo "$findings" | grep -c .) baselined)"
