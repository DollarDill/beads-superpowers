#!/usr/bin/env bash
# Guard-the-guards for check-secret-echo.sh. Stage a synthetic fixture tree,
# confirm the guard PASSES the clean controls (including the presence-only
# idioms ${NAME:-} and grep -q, which must never be flagged), then apply one
# mutation per rule and confirm it FAILS each time, naming that rule's id.
# Also covers hooks/, an empty tree, the no-ROOT git ls-files path, and a
# failing git ls-files. Fixture text uses placeholder names only - no
# real-token-shaped literals.
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
mutate() { printf '%s\n' "$1" >> "$FIX/${2:-skills/x/SKILL.md}"; }
rule() { printf '^SECRET-ECHO: .*:[0-9]+: %s$' "$1"; }  # output line naming a rule id

expect_pass() {  # label [cmd...]   (default cmd: guard on $FIX)
  local label="$1"; shift
  [ $# -gt 0 ] || set -- bash "$GUARD" "$FIX"
  if "$@" >/dev/null 2>&1; then
    echo "OK   clean fixture passes: $label"
  else
    echo "SELFTEST FAIL: clean fixture should pass but failed: $label"; fails=1
  fi
}
expect_fail() {  # label output-regex [cmd...]   (default cmd: guard on $FIX)
  local label="$1" want="$2" out; shift 2
  [ $# -gt 0 ] || set -- bash "$GUARD" "$FIX"
  if out="$("$@" 2>&1)"; then
    echo "SELFTEST FAIL: mutation NOT caught: $label"; fails=1
  elif ! printf '%s\n' "$out" | grep -Eq -- "$want"; then
    echo "SELFTEST FAIL: caught, but output lacks /$want/: $label"; fails=1
  else
    echo "OK   mutation caught: $label"
  fi
}

stage
expect_pass "clean"

stage; mutate 'env | grep TOKEN';                   expect_fail "env-grep"        "$(rule env-grep)"
stage; mutate 'env | grep -q X; env | grep TOKEN';  expect_fail "env-grep (-q exempts its own segment only)" "$(rule env-grep)"
stage; mutate 'printenv';                           expect_fail "printenv"        "$(rule printenv)"
stage
# shellcheck disable=SC2016  # literal fixture text, never expanded
mutate 'echo "${API_KEY:-none}"'
expect_fail "value-fallback (echo)" "$(rule value-fallback)"
stage
# shellcheck disable=SC2016  # literal fixture text, never expanded
mutate 'curl -H "X-Api: ${API_KEY:-none}" https://example.invalid'
expect_fail "value-fallback (no echo)" "$(rule value-fallback)"
stage
# shellcheck disable=SC2016  # literal fixture text, never expanded
mutate 'echo "$DB_PASS"'
expect_fail "echo-secret"     "$(rule echo-secret)"
stage; mutate 'env | sort';                         expect_fail "env-dump"        "$(rule env-dump)"
stage; mutate 'printenv' hooks/h;                   expect_fail "hooks/ is scanned" '^SECRET-ECHO: hooks/h:[0-9]+: printenv$'

# Empty tree: zero files scanned must never be a PASS.
rm -rf "$FIX"; FIX="$(mktemp -d)"
expect_fail "empty tree" '^FAIL: no files scanned under '

# Production path: a git repo, guard run with no ROOT from inside skills/.
# The guard must anchor to its own repo root and scan tracked files.
# shellcheck disable=SC2317,SC2329  # invoked indirectly, as a command word of expect_*
in_skills() { (cd "$G/skills" && bash ../scripts/check-secret-echo.sh); }
gitc() { git -C "$G" -c user.name=t -c user.email=t@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
stage; G="$FIX"
mkdir -p "$G/scripts"; cp -f "$GUARD" "$G/scripts/check-secret-echo.sh"
gitc init -q; gitc add skills scripts; gitc commit -qm init
expect_pass "git repo, no ROOT, run from skills/" in_skills
# shellcheck disable=SC2016  # literal fixture text, never expanded
mutate 'echo "$DB_PASS"'
expect_fail "git repo: tracked dirty file" "$(rule echo-secret)" in_skills
printf 'garbage' > "$G/.git/index"
expect_fail "git ls-files error" '^FAIL: git ls-files failed' in_skills

exit "$fails"
