#!/usr/bin/env bash
# Guard-the-guards for check-doctrine-floor.sh. Stage a synthetic fixture tree
# holding one SKILL.md per doctrine-class skill, confirm the guard PASSES clean,
# then apply one mutation per failure mode and confirm it FAILS each time. A
# check that can never fail is a blind green check (ADR-0025).
#
# The fixture is synthetic rather than a copy of skills/: this asserts the
# guard's LOGIC, so it must not go red when a real skill's wording is edited.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/scripts/check-doctrine-floor.sh"
fails=0

SKILLS="brainstorming executing-plans stress-test writing-plans
test-driven-development subagent-driven-development systematic-debugging
verification-before-completion"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

stage() {  # rebuild a pristine, fully-floored fixture
  rm -rf "$FIX"; FIX="$(mktemp -d)"
  mkdir -p "$FIX/scripts"
  cp -f "$GUARD" "$FIX/scripts/"
  for n in $SKILLS; do
    mkdir -p "$FIX/skills/$n"
    printf '# %s\n\n**Production-Grade Doctrine:** surface the trade-off, never take it silently.\n' \
      "$n" > "$FIX/skills/$n/SKILL.md"
  done
}
expect_pass() {  # label
  if ( cd "$FIX" && bash scripts/check-doctrine-floor.sh >/dev/null 2>&1 ); then
    echo "OK   clean fixture passes: $1"
  else
    echo "SELFTEST FAIL: clean fixture should pass but failed: $1"; fails=1
  fi
}
expect_fail() {  # label
  if ( cd "$FIX" && bash scripts/check-doctrine-floor.sh >/dev/null 2>&1 ); then
    echo "SELFTEST FAIL: mutation NOT caught: $1"; fails=1
  else
    echo "OK   mutation caught: $1"
  fi
}

stage
expect_pass "all doctrine-class skills carry a rule-bearing floor"

# M1 — the floor is deleted outright.
stage
printf '# tdd\n\nWrite the test first.\n' > "$FIX/skills/test-driven-development/SKILL.md"
expect_fail "M1 doctrine floor removed entirely"

# M2 — the floor decays into a bare cross-reference. This is the exact defect
# the guard was written for: the skill still NAMES the doctrine, so a
# presence-only grep would stay green while the obligation is gone.
stage
printf '# tdd\n\nSee the Production-Grade Doctrine for background.\n' \
  > "$FIX/skills/test-driven-development/SKILL.md"
expect_fail "M2 floor downgraded to a pointer with no rule"

# M3 — a listed skill vanishes from disk; the allowlist must not silently skip it.
stage
rm -f "$FIX/skills/stress-test/SKILL.md"
expect_fail "M3 doctrine-class skill listed but missing"

# M4 — the allowlist itself is emptied. Without the checked-zero gate the loop
# would run zero times and report a vacuous pass.
stage
sed -i.bak 's/^DOCTRINE_SKILLS="$/DOCTRINE_SKILLS="\n/; /^brainstorming$/,/^verification-before-completion$/d' \
  "$FIX/scripts/check-doctrine-floor.sh"
expect_fail "M4 emptied allowlist must not report a vacuous pass"

exit "$fails"
