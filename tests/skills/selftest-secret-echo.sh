#!/usr/bin/env bash
# Guard-the-guards for check-secret-echo.sh. Stage a synthetic fixture tree,
# confirm the guard PASSES the clean controls (including the presence-only
# idioms ${NAME:-} and grep -q, which must never be flagged), then apply one
# mutation per rule and confirm it FAILS each time. Fixture text uses
# placeholder names only - no real-token-shaped literals.
# shellcheck disable=SC2016  # mutations are intentionally literal, unexpanded text
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/scripts/check-secret-echo.sh"
fails=0

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

stage() {  # rebuild a pristine fixture holding the clean controls
  rm -rf "$FIX"; FIX="$(mktemp -d)"
  mkdir -p "$FIX/skills/x" "$FIX/hooks"
  : > "$FIX/hooks/h"
  cat > "$FIX/skills/x/SKILL.md" <<'MD'
# x

[ -n "${IDENTITY:-}" ] && echo "IDENTITY: SET" || echo "IDENTITY: UNSET"
env | grep -q '^IDENTITY=' && echo "IDENTITY in environment" || echo "IDENTITY not in environment"
env | grep -q FOO
MD
}
mutate() { printf '%s\n' "$1" >> "$FIX/skills/x/SKILL.md"; }
expect_pass() {
  if bash "$GUARD" "$FIX" >/dev/null 2>&1; then
    echo "OK   clean fixture passes: $1"
  else
    echo "SELFTEST FAIL: clean fixture should pass but failed: $1"; fails=1
  fi
}
expect_fail() {
  if bash "$GUARD" "$FIX" >/dev/null 2>&1; then
    echo "SELFTEST FAIL: mutation NOT caught: $1"; fails=1
  else
    echo "OK   mutation caught: $1"
  fi
}

stage
expect_pass "clean"

stage; mutate 'env | grep TOKEN';              expect_fail "env-grep"
stage; mutate 'printenv';                      expect_fail "printenv"
stage; mutate 'echo "${API_KEY:-none}"';       expect_fail "value-fallback"
stage; mutate 'echo "$DB_PASS"';               expect_fail "echo-secret"
stage; mutate 'env | sort';                    expect_fail "env-dump"

exit "$fails"
