#!/usr/bin/env bash
# Guard: skills/ and hooks/ must never contain examples that print a secret's
# value. Presence-only idioms (${NAME:-}, grep -q) are allowed.
# Usage: check-secret-echo.sh [ROOT]   (default ROOT: this script's repo root)
# A ROOT inside a git work tree scans `git ls-files skills hooks`; otherwise
# (e.g. the selftest fixture) it scans skills/ and hooks/ by find.
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "FAIL: cannot cd to $ROOT"; exit 1; }

if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  list="$(git ls-files skills hooks)" || { echo "FAIL: git ls-files failed under $ROOT"; exit 1; }
else
  list="$(find skills hooks -type f 2>/dev/null)"
fi
files=()
while IFS= read -r f; do [ -f "$f" ] && files+=("$f"); done <<< "$list"
[ "${#files[@]}" -gt 0 ] || { echo "FAIL: no files scanned under $ROOT"; exit 1; }

CLASS='[A-Z_]*(TOKEN|SECRET|KEY|PASS|CRED|IDENTITY)[A-Z_]*'
fail=0
hit() { echo "SECRET-ECHO: $1:$2: $3"; fail=1; }
segments() { awk '{ gsub(/;|&&|\|\|/, "\n"); print }'; }  # split on ; && ||

scan() {  # rule-id regex [exclude-regex: exempts one ;/&&/|| segment, not the line]
  local f n line left
  for f in "${files[@]}"; do
    while IFS=: read -r n line; do
      [ -n "$n" ] || continue
      if [ -n "${3:-}" ]; then
        left="$(printf '%s\n' "$line" | segments | grep -E -- "$2" | grep -Ev -- "$3")"
        [ -n "$left" ] || continue
      fi
      hit "$f" "$n" "$1"
    done < <(grep -nE -- "$2" "$f" 2>/dev/null)
  done
}

scan env-grep '(env|printenv)[[:space:]]*\|[[:space:]]*grep' 'grep[[:space:]]+-[A-Za-z]*q'
scan printenv '\bprintenv\b'
scan value-fallback "\\$\\{${CLASS}:?-[^}]"
scan echo-secret "(echo|printf)[^#]*\\$\\{?${CLASS}"
scan env-dump '^[[:space:]]*(env|export -p|declare -px?|set)[[:space:]]*(\|[[:space:]]*(sort|less|more|head|tail|cat)\b.*)?$'

if [ "$fail" -ne 0 ]; then echo "FAIL"; exit 1; fi
echo "PASS: no secret-printing patterns in skills/ hooks/"
