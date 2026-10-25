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
expect_fail() {  # expect_fail <label> <expected FAIL text, fixed string>
  total=$((total + 1))
  run_guard
  if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -qF -- "$2"; then
    echo "OK   caught: $1"
  else
    echo "SELFTEST FAIL: not caught as expected (rc=$RC, wanted '$2'): $1"
    printf '%s\n' "$OUT" | sed 's/^/     | /'
    fails=$((fails + 1))
  fi
}

stage
expect_pass "pristine fixture"

stage; mkdir "$FIX/skills/new"; pad "$FIX/skills/new/SKILL.md" 20000
expect_fail "M1 unlisted skill at 20,000 B" "skills/new/SKILL.md is 20000 bytes"

stage; mkdir "$FIX/skills/new"
for _ in $(seq 1 10000); do printf 'é'; done > "$FIX/skills/new/SKILL.md"
expect_fail "M2 unlisted skill of 10,000 multibyte chars (20,000 B)" "skills/new/SKILL.md is 20000 bytes"

stage; pad "$FIX/skills/big/SKILL.md" 21001
expect_fail "M3 listed skill one byte over baseline" "skills/big/SKILL.md grew to 21001 bytes (baseline 21000)"

stage; printf 'small 500\n' >> "$FIX/scripts/skill-size-baseline.txt"
expect_fail "M4 stale baseline entry under the limit" "baseline entry small is stale (500 bytes, under 20000)"

stage; printf 'ghost 25000\n' >> "$FIX/scripts/skill-size-baseline.txt"
expect_fail "M5 baseline entry names a missing skill" "baseline entry ghost is stale (skill missing, 25000 recorded)"

# Boundaries: 19,999 B unlisted passes with a WARN; 20,000 B unlisted fails.
stage; mkdir "$FIX/skills/edge"; pad "$FIX/skills/edge/SKILL.md" 19999
expect_pass "B1 19,999 B unlisted skill"
total=$((total + 1))
if printf '%s' "$OUT" | grep -qF 'SKILL-SIZE WARN: skills/edge/SKILL.md is 19999 bytes'; then
  echo "OK   warn printed at 19,999 B"
else
  echo "SELFTEST FAIL: no SKILL-SIZE WARN for 19,999 B skill"; fails=$((fails + 1))
fi
stage; mkdir "$FIX/skills/edge"; pad "$FIX/skills/edge/SKILL.md" 20000
expect_fail "B2 20,000 B unlisted skill" "skills/edge/SKILL.md is 20000 bytes"

# Malformed recorded sizes must fail, never pass silently.
stage; printf 'a abc\n' >> "$FIX/scripts/skill-size-baseline.txt"; mkdir "$FIX/skills/a"; pad "$FIX/skills/a/SKILL.md" 25000
expect_fail "N1 non-numeric recorded size" "baseline entry a has a malformed size 'abc'"
stage; printf 'big 34,843\n' > "$FIX/scripts/skill-size-baseline.txt"
expect_fail "N2 comma in recorded size" "baseline entry big has a malformed size '34,843'"
stage; printf 'big\n' > "$FIX/scripts/skill-size-baseline.txt"
expect_fail "N3 entry with no recorded size" "baseline entry big has a malformed size ''"

# CRLF baselines: comment/blank lines ignored, entries parsed, growth caught.
stage; printf '# test baseline\r\n\r\nbig 21000\r\n' > "$FIX/scripts/skill-size-baseline.txt"
expect_pass "C1 CRLF baseline, no growth"
stage; printf '# test baseline\r\n\r\nbig 21000\r\n' > "$FIX/scripts/skill-size-baseline.txt"; pad "$FIX/skills/big/SKILL.md" 21001
expect_fail "C2 CRLF baseline entry without comment, growth" "skills/big/SKILL.md grew to 21001 bytes (baseline 21000)"

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
