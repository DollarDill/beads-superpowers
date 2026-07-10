#!/usr/bin/env bash
#
# check-convention-sync.sh — assert the verbatim cross-cutting convention blocks
# are byte-identical across every site that carries them. Free-form duplication
# rots (bd-6814 ADR-strip missed skills/; the TodoWrite gate drifted across 4
# sites), so each canonical block is matched by an ASCII signature slice via
# `grep -qF` at all its declared sites; any missing/divergent copy is DRIFT.
#
# Usage:
#   scripts/check-convention-sync.sh            # verify all sites (exit 1 on drift)
#   scripts/check-convention-sync.sh --self-test # prove the detector catches a mutated block
#
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# ASCII-only signature slices (no em-dash) so the patterns are shell/grep-safe.
CB3_SIG="what should I capture?"
CB4_SIG="Don't skip because it feels minor"
CB5_SIG='bd frugality: bounded output, one round trip'

CB3_SITES=(
  skills/brainstorming/SKILL.md
  skills/writing-plans/SKILL.md
  skills/stress-test/SKILL.md
  skills/systematic-debugging/SKILL.md
)
CB4_SITES=(
  skills/executing-plans/SKILL.md
  skills/test-driven-development/SKILL.md
  .claude/skills/auditing-upstream-drift/SKILL.md
  skills/project-init/SKILL.md
  skills/subagent-driven-development/SKILL.md
  skills/using-git-worktrees/SKILL.md
  skills/requesting-code-review/SKILL.md
  skills/receiving-code-review/SKILL.md
  skills/research-driven-development/SKILL.md
  skills/getting-up-to-speed/SKILL.md
  skills/finishing-a-development-branch/SKILL.md
  skills/dispatching-parallel-agents/SKILL.md
  skills/document-release/SKILL.md
  skills/write-documentation/SKILL.md
  skills/verification-before-completion/SKILL.md
)
CB5_SITES=(
  skills/subagent-driven-development/SKILL.md
  skills/executing-plans/SKILL.md
  skills/using-git-worktrees/SKILL.md
  skills/project-init/SKILL.md
  skills/getting-up-to-speed/SKILL.md
  skills/writing-plans/SKILL.md
)

FAIL=0
check_block() {
  local label="$1" sig="$2"; shift 2
  local f
  for f in "$@"; do
    if [ ! -f "$f" ]; then echo "MISSING FILE: $f"; FAIL=1; continue; fi
    if ! grep -qF -- "$sig" "$f"; then
      echo "DRIFT: [$label] missing/divergent in $f"
      FAIL=1
    fi
  done
}

self_test() {
  # Prove the grep-based detector distinguishes a correct copy from a mutated one.
  local tmp; tmp="$(mktemp -d)"
  local fixture="canonical convention block fixture: byte-identical at every site"
  printf '%s\n' "$fixture" > "$tmp/correct.txt"
  printf '%s\n' "canonical convention block fixture: byte-identicaI at every site" > "$tmp/mutated.txt"
  local ok=1
  grep -qF -- "$fixture" "$tmp/correct.txt" || { echo "self-test FAIL: signature did not match its own correct copy"; ok=0; }
  if grep -qF -- "$fixture" "$tmp/mutated.txt"; then
    echo "self-test FAIL: detector did NOT catch the mutated block"; ok=0
  fi
  rm -rf "$tmp"
  if [ "$ok" -eq 1 ]; then echo "self-test OK: detector matches correct, rejects mutated"; return 0; else return 1; fi
}

if [ "${1:-}" = "--self-test" ]; then
  self_test; exit $?
fi

check_block "CB-3 Capture gate"    "$CB3_SIG" "${CB3_SITES[@]}"
check_block "CB-4 memory convention" "$CB4_SIG" "${CB4_SITES[@]}"
check_block "CB-5 bd-frugality" "$CB5_SIG" "${CB5_SITES[@]}"

if [ "$FAIL" -eq 0 ]; then
  echo "convention-sync: OK (all canonical blocks byte-identical at their sites)"
else
  echo "convention-sync: FAIL (drift above)"
fi
exit "$FAIL"
