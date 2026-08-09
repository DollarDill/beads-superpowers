#!/usr/bin/env bash
# test-finishing-branch-cleanup.sh — behavioral guard for
# skills/finishing-a-development-branch/SKILL.md Steps 2/5/6.
#
# Regression net for two confirmed defects:
#   vctf4.2 — Step 6 called `bd worktree info --path`, which is not a real flag.
#             2>/dev/null swallowed the error, WORKTREE_PATH was always empty,
#             and automatic worktree cleanup silently no-opped 100% of the time.
#   vctf4.3 — Option 1 deleted the branch while its worktree was still live
#             (git refuses) and never left the worktree before checking out base.
#
# The snippets under test are extracted from SKILL.md and executed, so the test
# fails if the shipped artifact regresses — not merely if prose is reworded.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi
}

assert_contains() {
  if grep -Fq -- "$2" <<<"$1"; then pass "$3"; else fail "$3 (missing: $2)"; fi
}

# extract_block <heading-regex> — emit the first ```bash fence that follows the
# given heading, stopping at the next heading. awk range, never a greedy sed range.
extract_block() {
  awk -v want="$1" '
    $0 ~ want                        { inseg = 1; next }
    inseg && !infence && /^#+ /      { exit }
    inseg && /^```bash$/             { infence = 1; next }
    infence && /^```$/               { exit }
    infence                          { print }
  ' "$SKILL"
}

# A real repo with a real worktree under .worktrees/ — the exact shape the skill
# claims to handle.
MAIN="$TEST_ROOT/main"
git init -q "$MAIN"
git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$MAIN" branch -q feature
git -C "$MAIN" worktree add -q "$MAIN/.worktrees/feature" feature
WT="$MAIN/.worktrees/feature"

echo "Test: Step 2 captures a real worktree path (vctf4.2)"
STEP2="$(extract_block '^#+ Step 2')"
if [ -z "$STEP2" ]; then
  fail "could not extract the Step 2 bash block from SKILL.md"
else
  CAPTURED="$(cd "$WT" && eval "$STEP2" 2>/dev/null; printf '%s' "${WORKTREE_PATH:-}")"
  if [ -z "$CAPTURED" ]; then
    fail "Step 2 left WORKTREE_PATH empty — cleanup will silently no-op"
  else
    pass "Step 2 sets WORKTREE_PATH to a non-empty value"
    assert_eq "$(cd "$CAPTURED" && pwd -P)" "$(cd "$WT" && pwd -P)" "captured path is the worktree root"
  fi
fi

echo "Test: the non-existent flag is gone (vctf4.2)"
if grep -Fq -- 'bd worktree info --path' "$SKILL"; then
  fail "SKILL.md still calls 'bd worktree info --path' (not a real bd flag)"
else
  pass "no reference to the non-existent --path flag"
fi

echo "Test: no site routes the PR option to worktree cleanup (xlrnh)"
# Now that cleanup actually runs, a stale "clean up after PR" instruction would
# destroy the workspace the PR feedback gets fixed in. Pin the two defect strings.
BAD_ROUTING=0
for phrase in 'Options 1, 2, 4' 'merge/PR/discard'; do
  if grep -Fq -- "$phrase" "$SKILL"; then
    fail "SKILL.md still routes the PR option to cleanup via: $phrase"
    BAD_ROUTING=1
  fi
done
[ "$BAD_ROUTING" -eq 0 ] && pass "PR option preserves the worktree at every site"

echo "Test: Step 6 provenance check actually invokes removal for a .worktrees/ path (vctf4.2)"
STEP6="$(extract_block '^#+ Step 6')"
if [ -z "$STEP6" ]; then
  fail "could not extract the Step 6 bash block from SKILL.md"
else
  # Stub `bd` so the assertion is on the control flow, not on beads being present.
  mkdir -p "$TEST_ROOT/bin"
  cat > "$TEST_ROOT/bin/bd" <<'EOF'
#!/usr/bin/env bash
echo "BD_CALLED: $*"
EOF
  chmod +x "$TEST_ROOT/bin/bd"
  OUTPUT="$(PATH="$TEST_ROOT/bin:$PATH" WORKTREE_PATH="$WT" bash -c "$STEP6" 2>&1 || true)"
  assert_contains "$OUTPUT" "BD_CALLED: worktree remove" "a .worktrees/ path reaches 'bd worktree remove'"

  OUTSIDE="$(PATH="$TEST_ROOT/bin:$PATH" WORKTREE_PATH="/somewhere/else/tree" bash -c "$STEP6" 2>&1 || true)"
  if grep -Fq "BD_CALLED: worktree remove" <<<"$OUTSIDE"; then
    fail "a worktree outside .worktrees/ must NOT be auto-removed"
  else
    pass "a worktree outside .worktrees/ is left alone"
  fi
fi

echo "Test: git refuses to delete a branch whose worktree is still live (vctf4.3 premise)"
if git -C "$MAIN" branch -d feature >/dev/null 2>&1; then
  fail "expected 'git branch -d' to fail while the worktree is checked out"
else
  pass "branch deletion fails while the worktree is live"
  git -C "$MAIN" worktree remove "$WT"
  if git -C "$MAIN" branch -d feature >/dev/null 2>&1; then
    pass "branch deletion succeeds once the worktree is removed"
  else
    fail "branch deletion should succeed after worktree removal"
  fi
fi

echo "Test: Option 1 removes the worktree before deleting the branch (vctf4.3)"
OPT1_START=$(grep -nE '^#+ Option 1' "$SKILL" | head -1 | cut -d: -f1 || true)
OPT2_START=$(grep -nE '^#+ Option 2' "$SKILL" | head -1 | cut -d: -f1 || true)
if [ -z "$OPT1_START" ] || [ -z "$OPT2_START" ]; then
  fail "could not locate the Option 1 section"
else
  OPT1="$(awk -v a="$OPT1_START" -v b="$OPT2_START" 'NR>=a && NR<b' "$SKILL")"
  CLEANUP_LINE=$(printf '%s\n' "$OPT1" | grep -niE 'clean up the worktree|cleanup worktree|Step 6' | head -1 | cut -d: -f1 || true)
  DELETE_LINE=$(printf '%s\n' "$OPT1" | grep -n 'git branch -d' | head -1 | cut -d: -f1 || true)
  if [ -z "$DELETE_LINE" ]; then
    fail "Option 1 no longer deletes the feature branch"
  elif [ -z "$CLEANUP_LINE" ]; then
    fail "Option 1 never routes to worktree cleanup before deleting the branch"
  elif [ "$CLEANUP_LINE" -lt "$DELETE_LINE" ]; then
    pass "worktree cleanup is ordered before 'git branch -d'"
  else
    fail "'git branch -d' comes before worktree cleanup — git will refuse the delete"
  fi
  assert_contains "$OPT1" 'MAIN_ROOT' "Option 1 leaves the worktree for the main repo root"
fi

echo "Test: neither menu advertises discard (vctf4.13)"
MENUS="$(awk '/^#+ Step 4/,/^#+ Step 5/' "$SKILL")"
if grep -qiE 'discard (this )?work|Discard\b' <<<"$MENUS"; then
  fail "a completion menu still offers discard next to merge"
else
  pass "no menu advertises discard"
fi

echo "Test: discard ritual survives as explicit-request-only (vctf4.13)"
assert_contains "$(cat "$SKILL")" "Type 'discard' to confirm." "typed-confirmation ritual retained"

echo "Test: detached-HEAD PR path has a working push (vctf4.14)"
assert_contains "$(cat "$SKILL")" 'HEAD:refs/heads/' "explicit refspec push for detached HEAD"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All tests passed"
