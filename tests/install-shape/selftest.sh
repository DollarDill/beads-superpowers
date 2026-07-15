#!/usr/bin/env bash
# selftest.sh — guard-the-guards: mutations that MUST make the suite fail.
# A checker that cannot fail is decoration.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
rc=0
expect_red() {  # expect_red <label> <cmd>...
  local label="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "SELFTEST FAIL: '$label' should have gone RED but passed"; rc=1
  else
    echo "SELFTEST ok: '$label' correctly fails"
  fi
}
expect_green() {  # expect_green <label> <cmd>... — the GREEN-control counterpart to expect_red.
  local label="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "SELFTEST ok: '$label' correctly passes"
  else
    echo "SELFTEST FAIL: '$label' should have gone GREEN but failed"; rc=1
  fi
}

# Mutation 1: source copy missing one skill dir -> the REAL assert-claude.sh must fail.
# (Runs the actual assertion code path via the SHAPE_REPO_ROOT override, not an inline re-check.
#  Note: promote_staging only WARNS below 20 skills — install exits 0 with 22/23; only the
#  suite's assert_all_skills catches the gap. That is exactly what this mutation proves.
#  SHAPE_EXPECTED_ROOT pins the assert_all_skills yardstick to the real checkout — without it
#  the mutated copy would be both install source AND ground truth, a tautology that can't fail.)
MUT1=$(mktemp -d)
cp -rf "$REPO_ROOT/skills" "$REPO_ROOT/example-workflow" "$REPO_ROOT/hooks" "$REPO_ROOT/.opencode" \
      "$REPO_ROOT/install.sh" "$REPO_ROOT/package.json" "$MUT1/"
mkdir -p "$MUT1/tests"
cp -rf "$REPO_ROOT/tests/install-shape" "$MUT1/tests/install-shape"
rm -rf "$MUT1/skills/using-superpowers"
expect_red "missing skill dir (real assert-claude.sh)" \
  env SHAPE_REPO_ROOT="$MUT1" SHAPE_EXPECTED_ROOT="$REPO_ROOT" \
  bash "$REPO_ROOT/tests/install-shape/assert-claude.sh"
rm -rf "$MUT1"

# Mutation 2: SessionStart entry stripped from settings.json post-install -> claude JSON assertion fails.
# Setup failures are rig breakage, NOT a caught mutation — never let them masquerade as red.
SB2=$(mktemp -d)
if ! HOME="$SB2" BEADS_SUPERPOWERS_SKILLS_DIR="$SB2/skills" bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >/dev/null 2>&1; then
  echo "SELFTEST FAIL: mutation-2 setup install failed (rig broken, not a caught mutation)"; rc=1
elif [ ! -f "$SB2/.claude/settings.json" ]; then
  echo "SELFTEST FAIL: mutation-2 setup produced no settings.json (rig broken, not a caught mutation)"; rc=1
else
  python3 - "$SB2/.claude/settings.json" << 'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d.get('hooks', {}).pop('SessionStart', None)
json.dump(d, open(p, 'w'))
PY
  expect_red "stripped SessionStart" python3 -c "
import json,sys; d=json.load(open('$SB2/.claude/settings.json'))
sys.exit(0 if 'SessionStart' in d.get('hooks',{}) else 1)"
fi
rm -rf "$SB2"

# Mutation 3: corrupted manifest JSON -> manifest assertion fails.
MUT3=$(mktemp -d)
echo '{ not json' > "$MUT3/plugin.json"
expect_red "corrupt manifest" python3 -c "import json; json.load(open('$MUT3/plugin.json'))"
rm -rf "$MUT3"

# Mutation 4: file planted after uninstall -> round-trip residue assertion fails.
# Setup failures are rig breakage, NOT a caught mutation — never let them masquerade as red.
SB4=$(mktemp -d)
if ! HOME="$SB4" BEADS_SUPERPOWERS_SKILLS_DIR="$SB4/skills" bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >/dev/null 2>&1; then
  echo "SELFTEST FAIL: mutation-4 setup install failed (rig broken, not a caught mutation)"; rc=1
elif ! HOME="$SB4" BEADS_SUPERPOWERS_SKILLS_DIR="$SB4/skills" bash "$REPO_ROOT/install.sh" --yes --uninstall >/dev/null 2>&1; then
  echo "SELFTEST FAIL: mutation-4 setup uninstall failed (rig broken, not a caught mutation)"; rc=1
else
  mkdir -p "$SB4/skills/using-superpowers" && touch "$SB4/skills/using-superpowers/SKILL.md"
  expect_red "planted residue" bash -c "[ ! -e '$SB4/skills/using-superpowers/SKILL.md' ]"
fi
rm -rf "$SB4"

# Mutations 5-7: check-kb-labels.sh (the KB label guard) actually fails on each
# of its 3 invariants. Each mutation creates its violation bead in a THROWAWAY
# scratch bd DB (mktemp -d OUTSIDE the repo tree, `bd init` there) — NEVER the
# real, Dolt-synced store. The idiom needs no db-flag plumbing: the guard
# resolves its vocab file from $0 (this repo's scripts/ dir, always an
# absolute path here), while `bd list` auto-discovers whatever .beads is
# above the CALLER's CWD. Running the guard with CWD = the scratch dir (via
# `bash -c "cd '$SBx' && bash '$REPO_ROOT/scripts/check-kb-labels.sh'"`) makes
# it see ONLY the scratch DB. After each mutation we assert THIS mutation's
# scratch bead id is absent from the real store — keyed on the specific id,
# NOT global emptiness, so it stays green after T4 migrates real kb-beads in.
# Setup failures (bd init) are rig breakage, NOT a caught mutation — never let
# them masquerade as red.
assert_scratch_bead_absent() {  # assert_scratch_bead_absent <mutation-label> <scratch-bead-id>
  local label="$1" bead_id="$2" real_ids
  real_ids=$(cd "$REPO_ROOT" && bd list --label kb --status all --limit 0 --json 2>/dev/null | jq -r '.[].id')
  if printf '%s\n' "$real_ids" | grep -qxF "$bead_id"; then
    echo "SELFTEST FAIL: '$label' leaked scratch bead '$bead_id' into the real store"; rc=1
  else
    echo "SELFTEST ok: '$label' scratch bead '$bead_id' absent from real store (no leak)"
  fi
}

# Mutation 5: label outside the vocab file -> vocab-membership invariant fails.
SB5=$(mktemp -d)
if ! (cd "$SB5" && bd init --non-interactive >/dev/null 2>&1); then
  echo "SELFTEST FAIL: mutation-5 setup 'bd init' failed (rig broken, not a caught mutation)"; rc=1
elif ! bead5=$(cd "$SB5" && bd create "bad vocab word" -t task -l "kb,notavocabword" --defer +1d --silent 2>/dev/null); then
  echo "SELFTEST FAIL: mutation-5 setup 'bd create' failed (rig broken, not a caught mutation)"; rc=1
else
  expect_red "kb guard: label not in vocab" bash -c "cd '$SB5' && bash '$REPO_ROOT/scripts/check-kb-labels.sh'"
  assert_scratch_bead_absent "kb guard: label not in vocab" "$bead5"
fi
rm -rf "$SB5"

# Mutation 6: 'kb' with zero topic labels -> min-topic invariant fails.
SB6=$(mktemp -d)
if ! (cd "$SB6" && bd init --non-interactive >/dev/null 2>&1); then
  echo "SELFTEST FAIL: mutation-6 setup 'bd init' failed (rig broken, not a caught mutation)"; rc=1
elif ! bead6=$(cd "$SB6" && bd create "no topic label" -t task -l "kb" --defer +1d --silent 2>/dev/null); then
  echo "SELFTEST FAIL: mutation-6 setup 'bd create' failed (rig broken, not a caught mutation)"; rc=1
else
  expect_red "kb guard: no topic label beyond kb" bash -c "cd '$SB6' && bash '$REPO_ROOT/scripts/check-kb-labels.sh'"
  assert_scratch_bead_absent "kb guard: no topic label beyond kb" "$bead6"
fi
rm -rf "$SB6"

# Mutation 7: 4 topic labels, ALL valid vocab words -> max-cap invariant fails
# in isolation (a mix of valid+invalid labels would false-green by tripping
# the vocab check instead of the cap check).
SB7=$(mktemp -d)
if ! (cd "$SB7" && bd init --non-interactive >/dev/null 2>&1); then
  echo "SELFTEST FAIL: mutation-7 setup 'bd init' failed (rig broken, not a caught mutation)"; rc=1
elif ! bead7=$(cd "$SB7" && bd create "too many topics" -t task -l "kb,memory,hooks,positioning,skills-arch" --defer +1d --silent 2>/dev/null); then
  echo "SELFTEST FAIL: mutation-7 setup 'bd create' failed (rig broken, not a caught mutation)"; rc=1
else
  expect_red "kb guard: >3 topic labels" bash -c "cd '$SB7' && bash '$REPO_ROOT/scripts/check-kb-labels.sh'"
  assert_scratch_bead_absent "kb guard: >3 topic labels" "$bead7"
fi
rm -rf "$SB7"

# Mutation 8: check-kb-doc-reconciliation.sh (Task 8's doc<->bead guard) —
# a local research doc with no matching knowledge-bead must fail RED (a
# skipped capture); adding a bead whose metadata.doc matches the file must
# then pass GREEN, proving the guard discriminates rather than always
# failing. Scratch-isolated exactly like mutations 5-7: mktemp -d OUTSIDE the
# repo, `bd init` there, own throwaway .internal/research/ dir. Running the
# guard with CWD = the scratch dir makes BOTH its `bd list` auto-discovery
# AND its relative DIR=".internal/research" resolve entirely inside the
# scratch tree — the real store and the real .internal/research (which
# doesn't exist pre-Task-9) are never touched. Setup failures (bd init /
# mkdir / write) are rig breakage, NOT a caught mutation — never let them
# masquerade as red.
SB8=$(mktemp -d)
if ! (cd "$SB8" && bd init --non-interactive >/dev/null 2>&1); then
  echo "SELFTEST FAIL: mutation-8 setup 'bd init' failed (rig broken, not a caught mutation)"; rc=1
elif ! mkdir -p "$SB8/.internal/research"; then
  echo "SELFTEST FAIL: mutation-8 setup 'mkdir .internal/research' failed (rig broken, not a caught mutation)"; rc=1
elif ! echo "# orphan research doc" > "$SB8/.internal/research/orphan.md"; then
  echo "SELFTEST FAIL: mutation-8 setup 'write orphan.md' failed (rig broken, not a caught mutation)"; rc=1
else
  expect_red "kb doc-reconciliation: orphan doc, no bead" \
    bash -c "cd '$SB8' && bash '$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh'"
  if ! bead8=$(cd "$SB8" && bd create "orphan doc control bead" -t task -l kb --defer +1d \
        --metadata '{"doc":".internal/research/orphan.md"}' --silent 2>/dev/null); then
    echo "SELFTEST FAIL: mutation-8 setup 'bd create' (control bead) failed (rig broken, not a caught mutation)"; rc=1
  else
    expect_green "kb doc-reconciliation: matching bead (control)" \
      bash -c "cd '$SB8' && bash '$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh'"
    assert_scratch_bead_absent "kb doc-reconciliation: orphan doc" "$bead8"
  fi
  if [ -d "$REPO_ROOT/.internal/research" ]; then
    echo "SELFTEST FAIL: mutation-8 leaked into real .internal/research (isolation broken)"; rc=1
  else
    echo "SELFTEST ok: mutation-8 real .internal/research still absent (no leak)"
  fi
fi
rm -rf "$SB8"

exit "$rc"
