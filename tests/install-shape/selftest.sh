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
  if ! real_ids=$(cd "$REPO_ROOT" && bd list --label kb --status all --limit 0 --json 2>/dev/null | jq -r '.[].id'); then
    echo "SELFTEST FAIL: '$label' — 'bd list --label kb --status all --limit 0 --json' failed; cannot verify no leak"; rc=1
    return
  fi
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
    # Scoped-WARN check: a bead whose metadata.doc is an OPAQUE ref (no '/',
    # e.g. a bead-id/kv-key from the kv->beads migration) must NOT emit a
    # 'warn:' line — proves the WARN loop is path-shaped-scoped, not a bare
    # `[ -f "$d" ]` that false-warns on every opaque ref.
    if ! (cd "$SB8" && bd create "opaque-ref doc bead" -t task -l kb --defer +1d \
          --metadata '{"doc":"4l5v"}' --silent >/dev/null 2>&1); then
      echo "SELFTEST FAIL: mutation-8 setup 'bd create' (opaque-ref bead) failed (rig broken, not a caught mutation)"; rc=1
    elif (cd "$SB8" && bash "$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh" 2>&1) | grep -q '^warn:'; then
      echo "SELFTEST FAIL: kb doc-reconciliation warned on an opaque (non-path) metadata.doc"; rc=1
    else
      echo "SELFTEST ok: kb doc-reconciliation: no warn on opaque (non-path) metadata.doc"
    fi
  fi
  # Leak check is artifact-scoped: the real repo legitimately HAS a populated
  # .internal/research/ (36 indexed docs post-8o3j.8), so directory existence
  # proves nothing — only the mutation's own file appearing there would.
  if [ -f "$REPO_ROOT/.internal/research/orphan.md" ]; then
    echo "SELFTEST FAIL: mutation-8 leaked orphan.md into real .internal/research (isolation broken)"; rc=1
  else
    echo "SELFTEST ok: mutation-8 orphan.md absent from real .internal/research (no leak)"
  fi
fi
rm -rf "$SB8"

# Mutation 9: check-kb-doc-reconciliation.sh's ADR loop (Task 7) — an orphan
# ADR under docs/decisions/ with no matching decision-bead must fail RED (a
# missed capture), parallel to mutation 8's research-doc check. Adding a
# matching decision-bead then passes GREEN (discrimination, not a bare
# always-fail). A third assertion proves the .kb-exclusions escape hatch
# (with a leading '# comment' line, exercising comment-line tolerance):
# listing a SEPARATE orphan's basename in .kb-exclusions suppresses the
# demand with no bead at all (used for the 2 sensitivity-parked ADRs,
# beads-superpowers-99pv). Scratch-isolated like mutation 8: mktemp -d
# OUTSIDE the repo, bd init there, a throwaway docs/decisions/ — deliberately
# WITHOUT a .internal/research/ dir at all. This is the exact scenario a
# code-review pass reproduced as broken pre-fix: the top-of-file SKIP used to
# be keyed to .internal/research alone, so a decisions-only checkout
# short-circuited to SKIP/exit-0 before the ADR loop ever ran. The corpora
# are now gated independently (each loop has its own `[ -d ]` guard); this
# rig's very setup — decisions dir present, research dir absent — is what
# proves the decoupling. Setup failures are rig breakage, NOT a caught
# mutation — never let them masquerade as red.
SB9=$(mktemp -d)
if ! (cd "$SB9" && bd init --non-interactive >/dev/null 2>&1); then
  echo "SELFTEST FAIL: mutation-9 setup 'bd init' failed (rig broken, not a caught mutation)"; rc=1
elif ! mkdir -p "$SB9/docs/decisions"; then
  echo "SELFTEST FAIL: mutation-9 setup 'mkdir docs/decisions' failed (rig broken, not a caught mutation)"; rc=1
elif ! echo "# orphan ADR" > "$SB9/docs/decisions/ADR-9999-test.md"; then
  echo "SELFTEST FAIL: mutation-9 setup 'write ADR-9999-test.md' failed (rig broken, not a caught mutation)"; rc=1
else
  expect_red "kb doc-reconciliation: orphan ADR, no decision-bead, no research dir (decoupling)" \
    bash -c "cd '$SB9' && bash '$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh'"
  if ! bead9=$(cd "$SB9" && bd create "orphan ADR control bead" -t decision -l kb --defer +1d \
        --metadata '{"doc":"docs/decisions/ADR-9999-test.md"}' --silent 2>/dev/null); then
    echo "SELFTEST FAIL: mutation-9 setup 'bd create' (control bead) failed (rig broken, not a caught mutation)"; rc=1
  else
    expect_green "kb doc-reconciliation: matching decision-bead (control)" \
      bash -c "cd '$SB9' && bash '$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh'"
    assert_scratch_bead_absent "kb doc-reconciliation: orphan ADR" "$bead9"
  fi
  if ! { printf '%s\n' "# comment line — tolerated, never matches a real basename" \
           "ADR-8888-excluded.md" > "$SB9/docs/decisions/.kb-exclusions" && \
         echo "# excluded orphan ADR" > "$SB9/docs/decisions/ADR-8888-excluded.md"; }; then
    echo "SELFTEST FAIL: mutation-9 setup 'write .kb-exclusions/ADR-8888-excluded.md' failed (rig broken, not a caught mutation)"; rc=1
  else
    expect_green "kb doc-reconciliation: exclusions-listed ADR needs no bead" \
      bash -c "cd '$SB9' && bash '$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh'"
  fi
fi
if [ -f "$REPO_ROOT/docs/decisions/ADR-9999-test.md" ] || [ -f "$REPO_ROOT/docs/decisions/ADR-8888-excluded.md" ]; then
  echo "SELFTEST FAIL: mutation-9 leaked orphan ADR into real docs/decisions (isolation broken)"; rc=1
else
  echo "SELFTEST ok: mutation-9 orphan ADRs absent from real docs/decisions (no leak)"
fi
rm -rf "$SB9"

# Mutation 10: the ADR loop's glob (docs/decisions/ADR-*.md) must
# structurally exclude INDEX.md — no denylist. A scratch decisions-dir
# containing ONLY INDEX.md, with NO .internal/research/ dir at all (the real
# docs/decisions has exactly this shape: 55 ADR-*.md + INDEX.md), must pass
# GREEN with zero decision-beads — proving both that the glob itself (not an
# incidental absence of INDEX.md content) keeps INDEX.md out of scope, AND
# that a decisions-only checkout doesn't SKIP past the ADR loop. Scratch-
# isolated like mutation 9. Setup failures are rig breakage, NOT a caught
# mutation.
SB10=$(mktemp -d)
if ! (cd "$SB10" && bd init --non-interactive >/dev/null 2>&1); then
  echo "SELFTEST FAIL: mutation-10 setup 'bd init' failed (rig broken, not a caught mutation)"; rc=1
elif ! mkdir -p "$SB10/docs/decisions"; then
  echo "SELFTEST FAIL: mutation-10 setup 'mkdir docs/decisions' failed (rig broken, not a caught mutation)"; rc=1
elif ! echo "# index" > "$SB10/docs/decisions/INDEX.md"; then
  echo "SELFTEST FAIL: mutation-10 setup 'write INDEX.md' failed (rig broken, not a caught mutation)"; rc=1
else
  expect_green "kb doc-reconciliation: INDEX.md-only dir needs no decision-bead" \
    bash -c "cd '$SB10' && bash '$REPO_ROOT/scripts/check-kb-doc-reconciliation.sh'"
fi
rm -rf "$SB10"


# Mutation 11: check-zh-docs.sh's completeness assertion (Task 8) — every
# docs/*.md page must be registered as the EN member of a pair, else it
# silently escapes zh-parity checking. Rig mirrors Mutation 1 (copy real
# artifacts into a scratch tree, run the REAL script from its copied
# location) rather than an env-var override: check-zh-docs.sh resolves its
# repo root via `cd "$(dirname "$0")/.."`, so copying the actual script to
# $SB11/scripts/ and invoking it from there makes that cd land in $SB11 with
# no code changes needed. The pairs array is hardcoded text in the copied
# script itself, so the scratch docs/ dir only needs the files under test —
# no need to replicate all 6 real doc pages. Setup failures are rig
# breakage, NOT a caught mutation — never let them masquerade as red.
SB11=$(mktemp -d)
if ! mkdir -p "$SB11/scripts" "$SB11/docs/en" "$SB11/docs/zh"; then
  echo "SELFTEST FAIL: mutation-11 setup 'mkdir scripts docs/en docs/zh' failed (rig broken, not a caught mutation)"; rc=1
elif ! cp -f "$REPO_ROOT/scripts/check-zh-docs.sh" "$SB11/scripts/check-zh-docs.sh"; then
  echo "SELFTEST FAIL: mutation-11 setup 'cp check-zh-docs.sh' failed (rig broken, not a caught mutation)"; rc=1
elif ! { printf '# readme\n' > "$SB11/README.md" && printf '# 说明\n' > "$SB11/README.zh-CN.md"; }; then
  echo "SELFTEST FAIL: mutation-11 setup 'write README fixtures' failed (rig broken, not a caught mutation)"; rc=1
elif ! echo "# orphan docs page" > "$SB11/docs/en/orphan-page.md"; then
  echo "SELFTEST FAIL: mutation-11 setup 'write orphan-page.md' failed (rig broken, not a caught mutation)"; rc=1
else
  out11=$(bash "$SB11/scripts/check-zh-docs.sh" 2>&1); ec11=$?
  if [ "$ec11" -eq 0 ]; then
    echo "SELFTEST FAIL: 'zh-parity structural: EN page without ZH twin' should have gone RED but passed"; rc=1
  elif ! printf '%s\n' "$out11" | grep -qF "docs/zh/orphan-page.md missing"; then
    echo "SELFTEST FAIL: 'zh-parity structural: EN page without ZH twin' failed for the wrong reason (no message naming docs/zh/orphan-page.md)"; rc=1
  else
    echo "SELFTEST ok: 'zh-parity structural: EN page without ZH twin' correctly fails, naming the missing twin"
  fi
  # GREEN control, same scratch dir: provide a valid ZH twin (MT frontmatter +
  # banner) — proves the structural assertion discriminates rather than
  # always-failing.
  if ! printf -- '---\nmachine_translated: true\n---\n!!! warning "机器翻译"\n\n# 孤页\n' > "$SB11/docs/zh/orphan-page.md"; then
    echo "SELFTEST FAIL: mutation-11 setup 'write ZH twin' failed (rig broken, not a caught mutation)"; rc=1
  else
    expect_green "zh-parity structural: paired page needs no fix" \
      bash "$SB11/scripts/check-zh-docs.sh"
  fi
fi
rm -rf "$SB11"

# Mutation 12: check-model-genericization.sh (bd-1f5w) — a skill file carrying
# a hardcoded Claude model name must fail RED; the same content under the
# ADR-0041 reference-file allowlist must pass GREEN (proves the allowlist
# discriminates rather than always failing). Fixture-isolated: mktemp -d,
# guard invoked with an explicit search-root arg — the real skills/ tree is
# never touched. Setup failures are rig breakage, NOT a caught mutation.
SB12=$(mktemp -d)
if ! mkdir -p "$SB12/skills/some-skill" "$SB12/skills/using-superpowers/references"; then
  echo "SELFTEST FAIL: mutation-12 setup mkdir failed (rig broken, not a caught mutation)"; rc=1
else
  echo 'dispatch with model: "haiku"' > "$SB12/skills/some-skill/SKILL.md"
  expect_red "model genericization: hardcoded model name in skill" \
    bash "$REPO_ROOT/scripts/check-model-genericization.sh" "$SB12/skills"
  rm -f "$SB12/skills/some-skill/SKILL.md"
  echo 'dispatch with model: "haiku"' > "$SB12/skills/using-superpowers/references/claude-code.md"
  expect_green "model genericization: allowlisted reference file (control)" \
    bash "$REPO_ROOT/scripts/check-model-genericization.sh" "$SB12/skills"
fi
rm -rf "$SB12"

# Mutation 13: check-convention-sync.sh (ADR-0058) — a repo copy whose
# brainstorming/SKILL.md loses the KB read-depth fragment must fail RED; the
# unmutated copy must pass GREEN (proves the KB_SITES block discriminates).
# Fixture-isolated: the tracked guard-relevant slice is copied into mktemp -d
# preserving relative paths; the real tree is never touched. Setup failures
# are rig breakage, NOT a caught mutation.
SB13=$(mktemp -d)
if ! (cd "$REPO_ROOT" && git ls-files -z skills .claude/skills hooks CLAUDE.md scripts/check-convention-sync.sh | xargs -0 -I{} cp --parents {} "$SB13"/); then
  echo "SELFTEST FAIL: mutation-13 setup copy failed (rig broken, not a caught mutation)"; rc=1
else
  grep -v -- "hits are pointers, not knowledge" "$SB13/skills/brainstorming/SKILL.md" > "$SB13/skills/brainstorming/SKILL.md.tmp" \
    && mv -f "$SB13/skills/brainstorming/SKILL.md.tmp" "$SB13/skills/brainstorming/SKILL.md"
  expect_red "convention-sync: stripped KB read-depth fragment" \
    bash "$SB13/scripts/check-convention-sync.sh"
  cp -f "$REPO_ROOT/skills/brainstorming/SKILL.md" "$SB13/skills/brainstorming/SKILL.md"
  expect_green "convention-sync: unmutated copy (control)" \
    bash "$SB13/scripts/check-convention-sync.sh"
fi
rm -rf "$SB13"

# Mutation 14: CB-4 memory-convention line — a NON-signature clause reworded at one site
# must fail RED (proves assert_line_identical catches full-line drift, not just the signature
# slice). Same fixture-isolation as Mutation 13; the real tree is never touched.
SB14=$(mktemp -d)
if ! (cd "$REPO_ROOT" && git ls-files -z skills .claude/skills hooks CLAUDE.md scripts/check-convention-sync.sh | xargs -0 -I{} cp --parents {} "$SB14"/); then
  echo "SELFTEST FAIL: mutation-14 setup copy failed (rig broken, not a caught mutation)"; rc=1
else
  # Reword the non-signature 'near-duplicate' tail of the CB-4 line at ONE site.
  sed 's/adding a near-duplicate/adding a duplicate/' \
    "$SB14/skills/test-driven-development/SKILL.md" > "$SB14/skills/test-driven-development/SKILL.md.tmp" \
    && mv -f "$SB14/skills/test-driven-development/SKILL.md.tmp" "$SB14/skills/test-driven-development/SKILL.md"
  # Rig-broken guard (stress-test P2): the sed MUST have changed the file; a stale target
  # string would silently no-op and masquerade as a guard regression.
  if cmp -s "$SB14/skills/test-driven-development/SKILL.md" "$REPO_ROOT/skills/test-driven-development/SKILL.md"; then
    echo "SELFTEST FAIL: mutation-14 changed nothing (stale fixture, not a caught mutation)"; rc=1
  fi
  expect_red "convention-sync: CB-4 non-signature clause reworded at one site" \
    bash "$SB14/scripts/check-convention-sync.sh"
  cp -f "$REPO_ROOT/skills/test-driven-development/SKILL.md" "$SB14/skills/test-driven-development/SKILL.md"
  expect_green "convention-sync: CB-4 unmutated copy (control)" \
    bash "$SB14/scripts/check-convention-sync.sh"
fi
rm -rf "$SB14"

# Mutation 15: CB-3 Capture-gate block — a NON-signature line reworded at one site must fail
# RED (proves assert_block_identical catches block drift beyond the signature line).
SB15=$(mktemp -d)
if ! (cd "$REPO_ROOT" && git ls-files -z skills .claude/skills hooks CLAUDE.md scripts/check-convention-sync.sh | xargs -0 -I{} cp --parents {} "$SB15"/); then
  echo "SELFTEST FAIL: mutation-15 setup copy failed (rig broken, not a caught mutation)"; rc=1
else
  # Reword the non-signature 'Both' option description inside the Capture-gate JSON at ONE site.
  sed 's/A lasting decision and a lesson worth reusing/A lasting decision plus a reusable lesson/' \
    "$SB15/skills/writing-plans/SKILL.md" > "$SB15/skills/writing-plans/SKILL.md.tmp" \
    && mv -f "$SB15/skills/writing-plans/SKILL.md.tmp" "$SB15/skills/writing-plans/SKILL.md"
  # Rig-broken guard (stress-test P2): confirm the mutation actually landed inside the block.
  if cmp -s "$SB15/skills/writing-plans/SKILL.md" "$REPO_ROOT/skills/writing-plans/SKILL.md"; then
    echo "SELFTEST FAIL: mutation-15 changed nothing (stale fixture, not a caught mutation)"; rc=1
  fi
  expect_red "convention-sync: CB-3 non-signature line reworded at one site" \
    bash "$SB15/scripts/check-convention-sync.sh"
  cp -f "$REPO_ROOT/skills/writing-plans/SKILL.md" "$SB15/skills/writing-plans/SKILL.md"
  expect_green "convention-sync: CB-3 unmutated copy (control)" \
    bash "$SB15/scripts/check-convention-sync.sh"
fi
rm -rf "$SB15"

# Mutation 16: strip the CB-3 start-anchor line at ALL CB-3 sites — extraction yields empty at
# every site; the guard must NOT pass vacuously. Must fail RED (anti-vacuous guard).
SB16=$(mktemp -d)
if ! (cd "$REPO_ROOT" && git ls-files -z skills .claude/skills hooks CLAUDE.md scripts/check-convention-sync.sh | xargs -0 -I{} cp --parents {} "$SB16"/); then
  echo "SELFTEST FAIL: mutation-16 setup copy failed (rig broken, not a caught mutation)"; rc=1
else
  for s in brainstorming writing-plans stress-test systematic-debugging; do
    grep -v -- "present the Capture gate" "$SB16/skills/$s/SKILL.md" > "$SB16/skills/$s/SKILL.md.tmp" \
      && mv -f "$SB16/skills/$s/SKILL.md.tmp" "$SB16/skills/$s/SKILL.md"
  done
  # Rig-broken guard (stress-test P2): confirm the anchor strip actually landed at a
  # representative site; a renamed anchor would silently no-op.
  if cmp -s "$SB16/skills/brainstorming/SKILL.md" "$REPO_ROOT/skills/brainstorming/SKILL.md"; then
    echo "SELFTEST FAIL: mutation-16 changed nothing (stale anchor, not a caught mutation)"; rc=1
  fi
  expect_red "convention-sync: CB-3 anchor stripped at all sites (anti-vacuous)" \
    bash "$SB16/scripts/check-convention-sync.sh"
fi
rm -rf "$SB16"

# Mutation 17: test-sdd-structure.sh (Task 6) — deleting the SDD skill's
# breaker-trip.md context-pointer target must fail RED (dangling pointer);
# the unmutated copy must pass GREEN (control, proves discrimination).
# Fixture-isolated by direct copy (not git ls-files, like mutations 13-16):
# the guard script tests/skills/test-sdd-structure.sh is new in this same
# task and may not be tracked yet when this selftest runs, so git ls-files
# would silently omit it and understate the fixture. Copying
# skills/subagent-driven-development/ and the guard script by explicit path
# into mktemp -d, preserving the guard's expected ROOT-relative layout
# (tests/skills/<script> + skills/<dir>), reproduces exactly what the guard
# resolves via "$(dirname "$0")/../..". The real tree is never touched.
SB17=$(mktemp -d)
if ! mkdir -p "$SB17/skills" "$SB17/tests/skills"; then
  echo "SELFTEST FAIL: mutation-17 setup mkdir failed (rig broken, not a caught mutation)"; rc=1
elif ! cp -rf "$REPO_ROOT/skills/subagent-driven-development" "$SB17/skills/subagent-driven-development"; then
  echo "SELFTEST FAIL: mutation-17 setup copy skill dir failed (rig broken, not a caught mutation)"; rc=1
elif ! cp -f "$REPO_ROOT/tests/skills/test-sdd-structure.sh" "$SB17/tests/skills/test-sdd-structure.sh"; then
  echo "SELFTEST FAIL: mutation-17 setup copy guard script failed (rig broken, not a caught mutation)"; rc=1
else
  rm -f "$SB17/skills/subagent-driven-development/references/breaker-trip.md"
  expect_red "sdd structure: dangling breaker-trip.md pointer" \
    bash "$SB17/tests/skills/test-sdd-structure.sh"
  cp -f "$REPO_ROOT/skills/subagent-driven-development/references/breaker-trip.md" \
    "$SB17/skills/subagent-driven-development/references/breaker-trip.md"
  expect_green "sdd structure: pointer target restored (control)" \
    bash "$SB17/tests/skills/test-sdd-structure.sh"
fi
rm -rf "$SB17"

# Mutation 18: test-sdd-structure.sh (Task 6) — pushing SDD's SKILL.md past
# the 500-line C1 budget must fail RED; the unmutated copy must pass GREEN
# (control). Same fixture-isolation as mutation 17.
SB18=$(mktemp -d)
if ! mkdir -p "$SB18/skills" "$SB18/tests/skills"; then
  echo "SELFTEST FAIL: mutation-18 setup mkdir failed (rig broken, not a caught mutation)"; rc=1
elif ! cp -rf "$REPO_ROOT/skills/subagent-driven-development" "$SB18/skills/subagent-driven-development"; then
  echo "SELFTEST FAIL: mutation-18 setup copy skill dir failed (rig broken, not a caught mutation)"; rc=1
elif ! cp -f "$REPO_ROOT/tests/skills/test-sdd-structure.sh" "$SB18/tests/skills/test-sdd-structure.sh"; then
  echo "SELFTEST FAIL: mutation-18 setup copy guard script failed (rig broken, not a caught mutation)"; rc=1
else
  for _ in $(seq 1 60); do echo >> "$SB18/skills/subagent-driven-development/SKILL.md"; done
  expect_red "sdd structure: SKILL.md over the 500-line budget" \
    bash "$SB18/tests/skills/test-sdd-structure.sh"
  cp -f "$REPO_ROOT/skills/subagent-driven-development/SKILL.md" \
    "$SB18/skills/subagent-driven-development/SKILL.md"
  expect_green "sdd structure: SKILL.md back under budget (control)" \
    bash "$SB18/tests/skills/test-sdd-structure.sh"
fi
rm -rf "$SB18"

# Mutations 19-21: the BM25 weight constants K1 and B, plus IDF.
# tests/skills/rank_invariants.py is what stops a later edit from quietly turning
# the ranker into a bag-of-words scorer, and the WEIGHT class is the one that has
# actually regressed here — twice. Task 3's score() wiring left B=0.0 and K1=0.5
# alive because the five bracket assertions were then read through search(), where
# the diversity halving fakes the expected order (rank_invariants.py:109-114
# records that reproduction); Task 3's boosts left idf=1.0 alive the same way. All
# three were found only by re-running a mutation matrix by hand. A header-strip
# mutation is killed too, but it has never regressed here — these three make the
# matrix mechanical for the class that has. B=0.0 is caught by the
# length-normalisation bracket, K1=0.5 by the term-frequency-saturation bracket,
# and idf=1.0 by the raw-BM25 rare-vs-ubiquitous assertion at
# rank_invariants.py:125-126, so the trio pins all three brackets rather than
# reusing one.
#
# Isolation: rank.py is copied into mktemp -d and mutated THERE, and RANK_DIR
# points rank_invariants.py's sys.path at the copy (a bare PYTHONPATH cannot beat
# that module's own sys.path.insert — which is why the override exists). The
# working tree is never written to, and the trap cleans up on every exit path. A
# mutation confined to a temp dir cannot create ambient state at all, which is
# stronger than asserting about it afterwards.
MUTR=$(mktemp -d)
trap 'rm -rf "$MUTR"' EXIT
if ! mkdir -p "$MUTR/ctl" "$MUTR/b0" "$MUTR/k1" "$MUTR/idf" \
   || ! cp -f "$REPO_ROOT/skills/knowledge-retrieval/scripts/rank.py" "$MUTR/ctl/rank.py"; then
  echo "SELFTEST FAIL: mutation-19/20/21 setup (mkdir/cp rank.py) failed (rig broken, not a caught mutation)"; rc=1
else
  sed 's/^K1, B = 1\.5, 0\.75$/K1, B = 1.5, 0.0/'  "$MUTR/ctl/rank.py" > "$MUTR/b0/rank.py"
  sed 's/^K1, B = 1\.5, 0\.75$/K1, B = 0.5, 0.75/' "$MUTR/ctl/rank.py" > "$MUTR/k1/rank.py"
  sed 's/^            idf = math\.log(1 + (self\.N - self\.df\[term\] + 0\.5) \/ (self\.df\[term\] + 0\.5))$/            idf = 1.0/' \
    "$MUTR/ctl/rank.py" > "$MUTR/idf/rank.py"
  # Rig-broken guard (stress-test P2, as in mutations 14-16): a reformatted constant
  # line, or a reformatted idf= computation line, makes the matching sed a no-op.
  # This check genuinely short-circuits the expect_red calls below (unlike the
  # cmp -s checks in mutations 14-16, which only report alongside them) — a
  # stale-fixture run reports exactly this one diagnostic, not this diagnostic
  # PLUS two or three misleading "should have gone RED but passed" lines from
  # unmutated copies passing where RED was expected.
  if cmp -s "$MUTR/b0/rank.py" "$MUTR/ctl/rank.py" \
     || cmp -s "$MUTR/k1/rank.py" "$MUTR/ctl/rank.py" \
     || cmp -s "$MUTR/idf/rank.py" "$MUTR/ctl/rank.py"; then
    echo "SELFTEST FAIL: mutation-19/20/21 changed nothing (stale 'K1, B =' or 'idf =' line, not a caught mutation)"; rc=1
  else
    # GREEN control first: the UNMUTATED copy must pass through the very same
    # RANK_DIR rig, so a RED below can only come from the mutation. Without it, a copy
    # that merely failed to import would satisfy the expect_red checks vacuously.
    expect_green "rank invariants: unmutated copy through RANK_DIR (control)" \
      env RANK_DIR="$MUTR/ctl" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
    expect_red "rank invariants: length normalisation disabled (B=0.0)" \
      env RANK_DIR="$MUTR/b0" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
    expect_red "rank invariants: term-frequency saturation crushed (K1=0.5)" \
      env RANK_DIR="$MUTR/k1" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
    expect_red "rank invariants: IDF flattened to a constant (idf=1.0)" \
      env RANK_DIR="$MUTR/idf" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
  fi
fi
# Both the trap AND this rm, deliberately: a mutation-22 appended below with its own
# EXIT trap would silently replace this one, and only the explicit rm — which has
# already run by then — would still clean up. Keep both when extending this file.
rm -rf "$MUTR"

# Mutations 22-24: the boost-wiring line in Corpus.search() (rank.py:118-120)
# — salience/hazard/recency are computed AND asserted individually elsewhere,
# but nothing pinned that `score += 0.5*(salience>=4) + 0.5*hazard +
# _recency(...)` is actually reached. All three below left the pre-existing
# 25/25 rank_invariants.py suite at exit 0 (beads-superpowers-eo9z2, FR3b) —
# found only by hand-running a mutation matrix, same as 19-21 above. Same
# RANK_DIR isolation as 19-21: rank.py copied into mktemp -d and mutated
# THERE; the working tree is never written to.
MUTR2=$(mktemp -d)
trap 'rm -rf "$MUTR2"' EXIT
if ! mkdir -p "$MUTR2/ctl" "$MUTR2/score0" "$MUTR2/hazF" "$MUTR2/salU" \
   || ! cp -f "$REPO_ROOT/skills/knowledge-retrieval/scripts/rank.py" "$MUTR2/ctl/rank.py"; then
  echo "SELFTEST FAIL: mutation-22/23/24 setup (mkdir/cp rank.py) failed (rig broken, not a caught mutation)"; rc=1
else
  # Anchor tracks rank.py: the per-call `today or datetime.date.today()` became
  # `today or self.today` when the date was frozen at construction
  # (beads-superpowers-eo9z2.4). A task that edits a mutation-anchored line MUST
  # re-anchor its sed in the same commit, or the mutation silently stops testing
  # anything — caught here by the `changed nothing` guard below.
  sed 's/^            score += 0\.5 \* (salience >= 4) + 0\.5 \* hazard + _recency(header, today or self\.today)$/            score += 0.0/' \
    "$MUTR2/ctl/rank.py" > "$MUTR2/score0/rank.py"
  sed 's/^            hazard = bool(_HAZARD\.search(self\.bodies\[key\]))$/            hazard = False/' \
    "$MUTR2/ctl/rank.py" > "$MUTR2/hazF/rank.py"
  sed 's/^            salience = int(m\.group(1)) if m else SALIENCE_UNSET$/            salience = SALIENCE_UNSET/' \
    "$MUTR2/ctl/rank.py" > "$MUTR2/salU/rank.py"
  # Rig-broken guard (stress-test P2, as in mutations 14-16/19-21): a
  # reformatted line makes the matching sed a silent no-op — this check
  # genuinely short-circuits the expect_red calls below rather than merely
  # reporting alongside a misleading "should have gone RED but passed".
  if cmp -s "$MUTR2/score0/rank.py" "$MUTR2/ctl/rank.py" \
     || cmp -s "$MUTR2/hazF/rank.py" "$MUTR2/ctl/rank.py" \
     || cmp -s "$MUTR2/salU/rank.py" "$MUTR2/ctl/rank.py"; then
    echo "SELFTEST FAIL: mutation-22/23/24 changed nothing (stale 'score +=' / 'hazard =' / 'salience =' line, not a caught mutation)"; rc=1
  else
    expect_green "rank invariants: boost-wiring unmutated copy through RANK_DIR (control)" \
      env RANK_DIR="$MUTR2/ctl" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
    expect_red "rank invariants: boost line zeroed (score += 0.0)" \
      env RANK_DIR="$MUTR2/score0" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
    expect_red "rank invariants: hazard forced False" \
      env RANK_DIR="$MUTR2/hazF" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
    expect_red "rank invariants: salience forced SALIENCE_UNSET" \
      env RANK_DIR="$MUTR2/salU" python3 "$REPO_ROOT/tests/skills/rank_invariants.py"
  fi
fi
rm -rf "$MUTR2"

exit "$rc"
