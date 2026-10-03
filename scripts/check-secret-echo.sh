#!/usr/bin/env bash
# Guard: skills/ and hooks/ must never contain examples that print a secret's
# value. Presence-only idioms (${NAME:-}, grep -q) are allowed.
# Usage: check-secret-echo.sh [ROOT]   (ROOT without a git repo: scans by find)
set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" || { echo "FAIL: cannot cd to $ROOT"; exit 1; }

if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ "$ROOT" = "." ]; then
  files="$(git ls-files skills hooks)"
else
  files="$(find skills hooks -type f 2>/dev/null)"
fi

CLASS='[A-Z_]*(TOKEN|SECRET|KEY|PASS|CRED|IDENTITY)[A-Z_]*'
fail=0
hit() { echo "SECRET-ECHO: $1:$2: $3"; fail=1; }

scan() {  # rule-id regex [exclude-regex]
  local f n
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS=: read -r n line; do
      [ -n "$n" ] || continue
      if [ -n "${3:-}" ] && printf '%s\n' "$line" | grep -Eq -- "$3"; then continue; fi
      hit "$f" "$n" "$1"
    done < <(grep -nE -- "$2" "$f" 2>/dev/null)
  done <<< "$files"
}

scan env-grep '(env|printenv)[[:space:]]*\|[[:space:]]*grep' 'grep[[:space:]]+-[A-Za-z]*q'
scan printenv '\bprintenv\b'
scan value-fallback "\\$\\{${CLASS}:?-[^}]"
scan echo-secret "(echo|printf)[^#]*\\$\\{?${CLASS}"
scan env-dump '^[[:space:]]*(env|export -p|declare -px?|set)[[:space:]]*(\|[[:space:]]*(sort|less|more|head|tail|cat)\b.*)?$'

if [ "$fail" -ne 0 ]; then echo "FAIL"; exit 1; fi
echo "PASS: no secret-printing patterns in skills/ hooks/"
