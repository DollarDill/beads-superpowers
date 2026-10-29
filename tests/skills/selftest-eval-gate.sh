#!/usr/bin/env bash
# Guard-the-guards for check-eval-gate.sh. Builds a throwaway git repo with a
# base commit and a change to skills/x/, confirms the clean control passes
# (three core roles tagged), then applies one mutation per rule and confirms
# each FAILS with the expected output. Every fixture git call is hermetic:
# no global config, no signing, no hooks, fixed identity and branch name.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/scripts/check-eval-gate.sh"
fails=0

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

gitc() {
  GIT_CONFIG_GLOBAL=/dev/null git -C "$FIX" -c user.name=selftest \
    -c user.email=selftest@invalid -c commit.gpgsign=false \
    -c init.defaultBranch=main -c core.hooksPath=/dev/null "$@"
}
case_md() {  # case-dir tags-line [body]
  mkdir -p "$FIX/evals/x/$1"
  printf -- '---\ndescription: "fixture"\n%s\nruns: 3\n---\n%s\n' "$2" "${3:-Do the thing.}" \
    > "$FIX/evals/x/$1/prompt.md"
}
stage() {  # pristine repo: base commit, then a commit changing skills/x/
  rm -rf "$FIX"; FIX="$(mktemp -d)"
  mkdir -p "$FIX/skills/x"
  printf '# x\n' > "$FIX/skills/x/SKILL.md"
  gitc init -q; gitc add skills; gitc commit -qm base
  BASE="$(gitc rev-parse HEAD)"
  printf '# x\nchanged\n' > "$FIX/skills/x/SKILL.md"
  gitc add skills; gitc commit -qm change
  case_md a 'tags: [x, core-fire]'
  case_md b 'tags: [x, core-nofire]'
  case_md c 'tags: [x, core-behaviour]'
}
gate() { EVAL_GATE_BASE="${GATE_BASE:-$BASE}" bash "$GUARD" "$FIX"; }

expect_pass() {  # label output-regex
  local out
  if out="$(gate 2>&1)" && printf '%s\n' "$out" | grep -Eq -- "$2"; then
    echo "OK   clean fixture passes: $1"
  else
    echo "SELFTEST FAIL: should pass with /$2/: $1"; printf '%s\n' "$out" | sed 's/^/     /'; fails=1
  fi
}
expect_fail() {  # label output-regex [exit-code]
  local out rc
  out="$(gate 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST FAIL: mutation NOT caught: $1"; fails=1
  elif [ -n "${3:-}" ] && [ "$rc" -ne "$3" ]; then
    echo "SELFTEST FAIL: caught with exit $rc, want $3: $1"; fails=1
  elif ! printf '%s\n' "$out" | grep -Eq -- "$2"; then
    echo "SELFTEST FAIL: caught, but output lacks /$2/: $1"; printf '%s\n' "$out" | sed 's/^/     /'; fails=1
  else
    echo "OK   mutation caught: $1"
  fi
}

stage; expect_pass "clean (three roles tagged)" '^COVERED x$'

stage; GATE_BASE="$(gitc rev-parse HEAD)" expect_pass "empty gate set" '^eval-gate: no skills changed since '

stage; rm -rf "$FIX/evals/x/c"
expect_fail "missing-role" '^MISSING x: core-behaviour$' 1

stage; rm -rf "$FIX/evals/x"
expect_fail "no evals dir" '^MISSING x: core-fire,core-nofire,core-behaviour$' 1

stage; case_md d 'tags: [x, core-no-fire]'
expect_fail "unknown-core-tag" '^EVAL-GATE ERROR: evals/x/d/prompt\.md: unknown core tag core-no-fire$' 1

stage; case_md d 'tags: [x, core_fire]'
expect_fail "underscore-typo (core_fire)" '^EVAL-GATE ERROR: evals/x/d/prompt\.md: unknown core tag core_fire$' 1

stage; printf -- '---\ndescription: "fixture"\ntags: [x, core-fire]\nruns: 3\nDo the thing.\ntags: [x]\n' > "$FIX/evals/x/d.md"
mkdir -p "$FIX/evals/x/d"; mv -f "$FIX/evals/x/d.md" "$FIX/evals/x/d/prompt.md"
expect_fail "unclosed-frontmatter" '^EVAL-GATE ERROR: evals/x/d/prompt\.md: frontmatter has no closing ---$' 1

stage; case_md d 'tags: [x, core-fire]
tags: [x, core-nofire]'
expect_fail "duplicate-tags-key" '^EVAL-GATE ERROR: evals/x/d/prompt\.md: duplicate tags key$' 1

stage; case_md d 'tags:
  - core-fire'
expect_fail "block-style-tags" '^EVAL-GATE ERROR: evals/x/d/prompt\.md: unsupported tags format$' 1

stage; case_md c 'model: sonnet' 'tags: [x, core-behaviour]'
expect_fail "tag-in-body" '^MISSING x: core-behaviour$' 1

stage; GATE_BASE=no-such-ref expect_fail "base-unresolvable" 'cannot resolve base' 2

# main-moved: a commit touching skills/y/ exists only on the base side.
# Three-dot semantics diff from the merge base, so y must not be gated.
stage
gitc checkout -q -b side "$BASE"
mkdir -p "$FIX/skills/y"; printf '# y\n' > "$FIX/skills/y/SKILL.md"
gitc add skills; gitc commit -qm side
SIDE="$(gitc rev-parse HEAD)"; gitc checkout -q main
if out="$(GATE_BASE="$SIDE" gate 2>&1)" && ! printf '%s\n' "$out" | grep -q ' y'; then
  echo "OK   main-moved: base-only skill not gated"
else
  echo "SELFTEST FAIL: main-moved: base-only skill gated or run failed"; printf '%s\n' "$out" | sed 's/^/     /'; fails=1
fi

exit "$fails"
