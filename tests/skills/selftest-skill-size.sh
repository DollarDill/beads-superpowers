#!/usr/bin/env bash
# Guard-the-guards for check-skill-size.sh. Stage a synthetic fixture (one
# baselined 21,000 B skill, one small skill), confirm the guard passes clean,
# then apply one mutation per failure mode and confirm it fails each time.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/scripts/check-skill-size.sh"
fails=0
total=0

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

# pad <file> <bytes>: write a SKILL.md of exactly <bytes> ASCII bytes
pad() {
  head -c "$2" /dev/zero | tr '\0' 'x' > "$1"
}
stage() {  # rebuild a pristine fixture
  rm -rf "$FIX"; FIX="$(mktemp -d)"
  mkdir -p "$FIX/scripts" "$FIX/skills/big" "$FIX/skills/small"
  cp -f "$GUARD" "$FIX/scripts/" 2>/dev/null
  pad "$FIX/skills/big/SKILL.md" 21000
  pad "$FIX/skills/small/SKILL.md" 500
  printf '# test baseline\nbig 21000   # sub-project X\n' > "$FIX/scripts/skill-size-baseline.txt"
}
run_guard() {
  OUT="$(cd "$FIX" && bash scripts/check-skill-size.sh 2>&1)"
  RC=$?
}
expect_pass() {
  total=$((total + 1))
  run_guard
  if [ "$RC" -eq 0 ]; then
    echo "OK   passes: $1"
  else
    echo "SELFTEST FAIL: should pass but rc=$RC: $1"; fails=$((fails + 1))
  fi
}
expect_fail() {
  total=$((total + 1))
  run_guard
  if [ "$RC" -eq 1 ]; then
    echo "OK   caught: $1"
  else
    echo "SELFTEST FAIL: not caught (rc=$RC): $1"; fails=$((fails + 1))
  fi
}

stage
expect_pass "pristine fixture"

stage; mkdir "$FIX/skills/new"; pad "$FIX/skills/new/SKILL.md" 20000
expect_fail "M1 unlisted skill at 20,000 B"

stage; mkdir "$FIX/skills/new"
for _ in $(seq 1 10000); do printf 'é'; done > "$FIX/skills/new/SKILL.md"
expect_fail "M2 unlisted skill of 10,000 multibyte chars (20,000 B)"

stage; pad "$FIX/skills/big/SKILL.md" 21001
expect_fail "M3 listed skill one byte over baseline"

stage; printf 'small 500\n' >> "$FIX/scripts/skill-size-baseline.txt"
expect_fail "M4 stale baseline entry under the limit"

stage; printf 'ghost 25000\n' >> "$FIX/scripts/skill-size-baseline.txt"
expect_fail "M5 baseline entry names a missing skill"

stage; pad "$FIX/skills/small/SKILL.md" 19500
expect_pass "W1 19,500 B skill is warn-only"
total=$((total + 1))
if printf '%s' "$OUT" | grep -q 'SKILL-SIZE WARN'; then
  echo "OK   warn printed"
else
  echo "SELFTEST FAIL: no SKILL-SIZE WARN for 19,500 B skill"; fails=$((fails + 1))
fi

echo "selftest-skill-size: $((total - fails))/$total"
[ "$fails" -eq 0 ]
