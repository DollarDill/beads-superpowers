#!/usr/bin/env bash
# tests/skills/test-kr-corpus-shapes.sh — run: bash tests/skills/test-kr-corpus-shapes.sh
#
# Adversarial corpus shapes from Plan C spec §6, in scratch stores only.
# NO FOREIGN DATA is read or written by this file.
#
# Grounding: rank.py's Corpus indexes the stripped BODY only. Its tokenizer is
# [a-z0-9]+ PLUS, since Task 2 (2026-08-09), CJK unigrams and overlapping
# bigrams — so a CJK body IS retrievable now. Emoji are still outside the
# tokenizer and an emoji-only body still tokenizes to NOTHING. `bd memories`
# truncates previews at ~120 chars, leaving header-heavy entries under two tokens
# after @k=v stripping (root-cause-rank-py-indexes-bodies-never-keys).
set -euo pipefail
command -v bd      >/dev/null 2>&1 || { echo "SKIP: test-kr-corpus-shapes (bd absent)"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: test-kr-corpus-shapes (python3 absent)"; exit 0; }

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SURFACE="$REPO/skills/knowledge-retrieval/scripts/surface.sh"
[ -f "$SURFACE" ] || { echo "FAIL: $SURFACE missing"; exit 1; }

unset BEADS_DIR
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
( cd "$TMP" && bd init --non-interactive --prefix shapes >/dev/null 2>&1 ) \
  || { echo "FAIL: scratch bd init failed"; exit 1; }
# bd auto-discovers .beads/ UP the tree, so prove the store is local BEFORE writing:
# "no foreign store is touched" is load-bearing for this whole plan, and this task
# writes (remember/create). Same guard Task 1 and Task 2's tests both carry.
[ -d "$TMP/.beads" ] || { echo "FAIL: scratch store not created in \$TMP"; exit 1; }

# ═══════════════════════════════════════════════════════════════════════════
# SHAPE 1 (Task 5, flipped Task 2 2026-08-09): CJK body is retrievable; emoji
# body still tokenizes to nothing under the tokenizer — neither [a-z0-9]+ nor
# the CJK ranges match emoji
# ═══════════════════════════════════════════════════════════════════════════

# ── 1. a CJK-only body must not crash the ranker.
# CJK is tokenized (unigrams + overlapping bigrams, Task 2 2026-08-09) and
# retrievable — the block below asserts liveness AND redaction on it. Emoji is
# the separate case further down: the tokenizer does not cover emoji, so an
# emoji-only body is asserted for SURVIVAL plus DISCLOSURE only, not
# retrievability — the entry is simply unfindable, which is a defect to FILE,
# not to fix here. What is unacceptable, for either shape, is a traceback or a
# non-zero exit.
# The fake secret is ASSEMBLED AT RUNTIME (stress-test B7). A contiguous fake-token
# literal in a committed file trips GitHub push-protection GH013 even though it is fake
# (lesson-a-secret-scanner-s-own-test-fixtures); printf keeps the runtime value intact
# for the assertion while committing no matchable literal.
FAKE_SECRET="$(printf 'sk-%s%s' 'liveDUMMY0123456789' 'abcdefghijKLMNOP')"
( cd "$TMP" && bd remember "工作树隔离与并行执行的注意事项 $FAKE_SECRET" --key shape-cjk >/dev/null )
set +e
cjk="$( cd "$TMP" && bash "$SURFACE" 工作树 隔离 2>&1 )"; cjk_rc=$?
set -e
[ "$cjk_rc" -eq 0 ] \
  || { echo "FAIL: CJK query exited $cjk_rc — ranker does not survive a CJK corpus"; printf '%s\n' "$cjk"; exit 1; }
grep -q '^searched:' <<<"${cjk%%$'\n'*}" \
  || { echo "FAIL: CJK run emitted no coverage line"; printf '%s\n' "$cjk"; exit 1; }
# `if ... then`, not a trailing `grep && { … }`: a bare `cmd && { …; exit 1; }` as a
# standalone statement leaves the block's own exit status resting on cmd's, which is
# exactly the ambiguity the hard constraint on this file rules out — `if`/`then` makes
# the FAIL path the only path that can set a nonzero status here.
if grep -qiE 'traceback|unicodedecodeerror' <<<"$cjk"; then
  echo "FAIL: CJK run produced a python traceback"; printf '%s\n' "$cjk"; exit 1
fi
# FIXTURE LIVENESS (stress-test B6). Without this, every assertion above holds on an
# EMPTY store — the seeded CJK entry contributes nothing and the test proves only that
# surface.sh runs, not that it survives CJK. Requiring the searched set to include the
# seeded entry makes a silently-unseeded fixture fail here instead of going green.
mem_n="$(sed -n 's/^searched: memories(\([0-9]*\)).*/\1/p' <<<"${cjk%%$'\n'*}")"
# `if`/`then`, not `A && B || C`: that chained form is the exact shape SC2015
# flags ("A && B || C is not if-then-else"), and pre-commit runs the linter at
# default severity via `-x`, so the chained form would block the commit outright.
if [ -z "$mem_n" ] || [ "$mem_n" -lt 1 ]; then
  echo "FAIL: coverage line reports no memories searched — the CJK fixture never seeded"; printf '%s\n' "$cjk"; exit 1
fi

# FLIPPED 2026-08-09 (spec §4.2). This block previously pinned CJK as UNFINDABLE,
# deliberately, so that a tokenizer change would force this record to be updated
# rather than drift silently. That change has now landed: tokenize() emits CJK
# unigrams + overlapping bigrams, so a CJK query matches.
# LIVENESS FIRST — without it the assertion below is vacuous, which is the defect
# class this file has already hit twice (see the repaired pin in fix round 1).
grep -q 'shape-cjk' <<<"$cjk" \
  || { echo "FAIL: CJK query returned no hit for the seeded fixture — CJK retrieval regressed"; printf '%s\n' "$cjk"; exit 1; }
if grep -q '(no hits' <<<"$cjk"; then
  echo "FAIL: CJK query reports '(no hits)' — the tokenizer's CJK path regressed"; printf '%s\n' "$cjk"; exit 1
fi

# SECRETS FLOOR, NEWLY LIVE ON THIS PATH (added 2026-08-09, Task 2 pre-flight).
# shape-cjk's body is "工作树隔离与并行执行的注意事项 $FAKE_SECRET". BEFORE this flip the
# CJK query returned zero hits, so that body was never rendered and the original
# `grep -qF "$FAKE_SECRET" <<<"$cjk"` was removed as vacuous (see the SECRETS FLOOR block
# below, which moved the assertion onto the ASCII-anchored fixture instead).
# The flip makes shape-cjk retrievable, so this path now renders a secret-bearing body for
# the first time and the floor MUST be asserted here as well — a floor in one code path is
# bypassed by every other path (lesson-a-floor-in-one-code-path-is-bypassed-by-every-fallback).
grep -q '\[REDACTED\]' <<<"$cjk" \
  || { echo "FAIL: CJK hit rendered without a [REDACTED] marker"; printf '%s\n' "$cjk"; exit 1; }
if grep -qF "$FAKE_SECRET" <<<"$cjk"; then
  echo "FAIL: secret leaked from a CJK body on the newly-live CJK query path"; exit 1
fi

# SECRETS FLOOR UNDER AN ADVERSARIAL SHAPE (stress-test B7), REPAIRED.
#
# WHY THE ORIGINAL FORM COULD NOT FAIL (HISTORICAL — pre-Task-2): the plan shipped
# `grep -qF "$FAKE_SECRET" <<<"$cjk"` against the CJK query above, which at the time
# returned ZERO hits under the [a-z0-9]+-only tokenizer. A negative grep over empty
# output passes no matter what redaction does — the eo9z2.8 assertion class this repo
# keeps rediscovering. Measured by the M1 audit: query `工作树 隔离` -> no hit lines;
# control query `ok` -> the entry, with `[REDACTED]`. Since Task 2 (2026-08-09) the CJK
# query above DOES return the shape-cjk hit and carries its own redaction assertion on
# the RANKED path.
#
# WHY THIS ANCHORED FIXTURE STILL EARNS ITS KEEP (corrected in review round 2 — the
# original claim below was checked against surface.sh and found false): it is NOT
# that a raw CJK query "cannot exercise" the degraded path — verified 2026-08-09 that
# it can: `bd memories` does its own substring match on CJK text, independent of
# python3, so the shape-cjk query above would hit on the degraded path too. The real
# reason is simpler — the shape-cjk block above never runs surface.sh with python3
# stripped from PATH, so nothing above tests the degraded RENDERING path (keys-only,
# bodies-withheld) for a secret-bearing CJK body. This fixture, queried by its ASCII
# anchor for consistency with its own ranked-path assertion just above, is what
# supplies that second rendering path's coverage — the entry is retrievable on both
# the main and degraded paths, so the redaction assertion has something to be wrong
# about on both.
CJK_ANCHOR="zhcorpusanchor"
( cd "$TMP" && bd remember "并行执行 $CJK_ANCHOR 的注意事项 $FAKE_SECRET" --key shape-cjk-anchored >/dev/null )
set +e
cjk_hit="$( cd "$TMP" && bash "$SURFACE" "$CJK_ANCHOR" 2>&1 )"; cjk_hit_rc=$?
set -e
[ "$cjk_hit_rc" -eq 0 ] \
  || { echo "FAIL: anchored CJK query exited $cjk_hit_rc"; printf '%s\n' "$cjk_hit"; exit 1; }
# LIVENESS FIRST — without this the redaction check below is vacuous again.
grep -q 'shape-cjk-anchored' <<<"$cjk_hit" \
  || { echo "FAIL: anchored fixture not returned — redaction assertion would be vacuous"; printf '%s\n' "$cjk_hit"; exit 1; }
grep -q '\[REDACTED\]' <<<"$cjk_hit" \
  || { echo "FAIL: anchored CJK hit shows no [REDACTED] marker"; printf '%s\n' "$cjk_hit"; exit 1; }
# `if ... then`, not `grep && { exit 1; }`: a trailing conditional makes the block's
# status the script's (bug-nosp-task-8-trailing-cond-info-as).
if grep -qF "$FAKE_SECRET" <<<"$cjk_hit"; then
  echo "FAIL: secret leaked from a CJK body on the ranked path"; exit 1
fi
# …and on the degraded (python3-absent) path, where bodies must be withheld entirely.
# This is the only place in the file exercising that rendering path for a
# secret-bearing CJK body (see the corrected note above — the raw shape-cjk query is
# not vacuous here either, it is simply never run against a python3-stripped PATH).
# Queried by the ANCHOR here for consistency with the ranked-path block above.
mkdir -p "$TMP/nopy_cjk"
for b in bd bash grep head sed sort dirname cut tr awk cat wc; do
  p="$(env -i PATH="$PATH" /bin/bash -c "command -v $b" 2>/dev/null || true)"
  case "$p" in /*) ln -sf "$p" "$TMP/nopy_cjk/$b" ;; esac
done
set +e
cjk_deg="$( cd "$TMP" && PATH="$TMP/nopy_cjk" bash "$SURFACE" "$CJK_ANCHOR" 2>&1 )"
set -e
# Liveness on the degraded path too: it must have actually taken the degraded branch,
# otherwise a PATH that still resolved python3 would make the grep below meaningless.
grep -q 'requires python3' <<<"$cjk_deg" \
  || { echo "FAIL: degraded branch not taken — python3 still resolvable, assertion vacuous"; printf '%s\n' "$cjk_deg"; exit 1; }
if grep -qF "$FAKE_SECRET" <<<"$cjk_deg"; then
  echo "FAIL: secret leaked from a CJK body on the DEGRADED path"; printf '%s\n' "$cjk_deg"; exit 1
fi

# An emoji-only body is the same class and must also survive.
( cd "$TMP" && bd remember "🔐🧭🚀" --key shape-emoji >/dev/null )
set +e
emo="$( cd "$TMP" && bash "$SURFACE" worktree 2>&1 )"; emo_rc=$?
set -e
[ "$emo_rc" -eq 0 ] \
  || { echo "FAIL: emoji-bearing corpus exited $emo_rc"; printf '%s\n' "$emo"; exit 1; }

echo "PASS: shape 1 — CJK retrievability + emoji survival (15 assertions)"

# ═══════════════════════════════════════════════════════════════════════════
# SHAPE 2 (Task 6): header-heavy body truncated below two tokens
# ═══════════════════════════════════════════════════════════════════════════

# ── 2. a header-heavy body leaves <2 tokens after @k=v stripping.
# `bd memories` truncates previews at ~120 chars; 50 of 180 entries on the live
# store were measured in this class. The ranker must survive and disclose.
# $FAKE_SECRET is defined in shape 1's block earlier in this same file (Task 5).
( cd "$TMP" && bd remember "@type=semantic:lesson @created=2026-08-08 @salience=3 @tags=a,b,c,d,e,f @refs=x,y,z ok $FAKE_SECRET" --key shape-headerheavy >/dev/null )
set +e
hh="$( cd "$TMP" && bash "$SURFACE" semantic lesson 2>&1 )"; hh_rc=$?
set -e
[ "$hh_rc" -eq 0 ] \
  || { echo "FAIL: header-heavy corpus exited $hh_rc"; printf '%s\n' "$hh"; exit 1; }
grep -q '^searched:' <<<"${hh%%$'\n'*}" \
  || { echo "FAIL: header-heavy run emitted no coverage line"; printf '%s\n' "$hh"; exit 1; }
# PIN THE OBSERVED BEHAVIOUR (amended 2026-08-08 by the M1 audit, beads-superpowers-8tyco).
# `semantic` and `lesson` live ONLY inside the @k=v header, which strip_header removes
# before indexing — so this query matches nothing by construction. Assert that outcome
# on the documented zero-hit marker rather than by line arithmetic (fix round 1 of Task 5
# showed a positional form is blind to the single-hit case it exists to catch).
grep -q '(no hits' <<<"$hh" \
  || { echo "NOTE: header terms now match — strip_header behaviour changed, update the shape record"; printf '%s\n' "$hh"; exit 1; }

# SECRETS FLOOR UNDER TRUNCATION-SHAPED INPUT (stress-test B7), REPAIRED.
#
# WHY THE ORIGINAL FORM COULD NOT FAIL: the plan grepped for the fake token in the output
# of `$SURFACE semantic lesson` — a query whose terms are stripped before indexing, so the
# result set is empty and a negative grep over it passes regardless of what redaction does.
# Measured by the M1 audit: query `semantic lesson` -> zero hits; control query `ok` -> the
# entry, showing [REDACTED].
#
# `ok` is the one token in this body that SURVIVES strip_header, so it is the anchor that
# makes the assertion live. No new fixture is needed — the body already carries it.
set +e
hh_hit="$( cd "$TMP" && bash "$SURFACE" ok 2>&1 )"; hh_hit_rc=$?
set -e
[ "$hh_hit_rc" -eq 0 ] \
  || { echo "FAIL: anchored header-heavy query exited $hh_hit_rc"; printf '%s\n' "$hh_hit"; exit 1; }
# LIVENESS FIRST — without this the redaction check below is vacuous again.
grep -q 'shape-headerheavy' <<<"$hh_hit" \
  || { echo "FAIL: header-heavy fixture not returned — redaction assertion would be vacuous"; printf '%s\n' "$hh_hit"; exit 1; }
grep -q '\[REDACTED\]' <<<"$hh_hit" \
  || { echo "FAIL: header-heavy hit shows no [REDACTED] marker"; printf '%s\n' "$hh_hit"; exit 1; }
if grep -qF "$FAKE_SECRET" <<<"$hh_hit"; then
  echo "FAIL: secret leaked from a header-heavy body"; printf '%s\n' "$hh_hit"; exit 1
fi
echo "PASS: shape 2 — header-heavy body under two tokens"

# ═══════════════════════════════════════════════════════════════════════════
# SHAPE 3 (Task 7): a query word collides with a LABEL name
# ═══════════════════════════════════════════════════════════════════════════

# ── 3. a query word that collides with a LABEL name must not narrow the corpus
# silently. Observed live 2026-08-08 on a foreign store: `surface.sh scoring routing`
# emitted `label=routing,scoring`. Narrowing may be intended; SILENT narrowing is not.
( cd "$TMP" && bd create "labelled bead" -t task -p 2 -l kb,routing --description "a bead that carries the routing label" >/dev/null )
( cd "$TMP" && bd create "unlabelled bead" -t task -p 2 -l kb --description "this body discusses routing decisions in depth but carries no routing label" >/dev/null )
set +e
col="$( cd "$TMP" && bash "$SURFACE" routing 2>&1 )"; col_rc=$?
set -e
[ "$col_rc" -eq 0 ] || { echo "FAIL: label-collision query exited $col_rc"; printf '%s\n' "$col"; exit 1; }
cov="${col%%$'\n'*}"
# AMENDED 2026-08-08 (pre-flight, controller). The plan shipped ONLY the `if label=`
# branch, disclosing it as "record-only, not a guarantee". That framing is wrong, and
# the gap is not benign: the AC's stated FAIL condition is "a filter that silently
# narrows the searched corpus WITHOUT disclosing it". In the shipped form, silent
# narrowing makes `grep -q 'label='` FALSE, so the block is skipped and the test PASSES.
# It was blind to precisely the failure it exists to catch — the same class as Task 5's
# `sed '1,2d'` pin and the Task 5/6 vacuous redaction greps.
#
# BOTH branches must now assert. The fixture is built for exactly this: `unlabelled bead`
# matches the query in its BODY and carries no `routing` label, so it is the probe for
# whether the corpus was narrowed.
if grep -q 'label=' <<<"$cov"; then
  # Narrowing happened and was disclosed — check it names the label.
  grep -q 'label=routing' <<<"$cov" \
    || { echo "FAIL: a label filter engaged but did not name the label"; printf '%s\n' "$cov"; exit 1; }
  narrowing="disclosed"
else
  # No disclosure — then the corpus must NOT have been narrowed. Prove it by requiring
  # the body-relevant unlabelled bead to still be reachable. If it is missing here, the
  # corpus was narrowed silently: the AC's FAIL condition, now detectable.
  grep -q 'carries no routing label' <<<"$col" \
    || { echo "FAIL: no label= disclosure, yet the unlabelled body-relevant bead is absent — SILENT NARROWING"; printf '%s\n' "$col"; exit 1; }
  narrowing="none"
fi
# Record the exclusion question literally (AC: "recorded literally"), whichever branch ran.
if grep -q 'carries no routing label' <<<"$col"; then
  excluded="no — the unlabelled body-relevant bead was returned"
else
  excluded="YES — the unlabelled body-relevant bead was excluded"
fi
printf 'OBSERVED label-collision coverage line: %s\n' "$cov"
printf 'OBSERVED narrowing: %s; unlabelled-bead excluded: %s\n' "$narrowing" "$excluded"

# ═══════════════════════════════════════════════════════════════════════════
# SHAPE 4 (Task 8): bd ABSENT — restricted-PATH symlink farm, never a stub
# ═══════════════════════════════════════════════════════════════════════════

# ── 4. bd ABSENT (surface.sh:11). Built as a restricted-PATH symlink farm, NOT a
# stub: a stub that exists and exits 127 PASSES `command -v`, so the degraded
# branch never runs, the stub dies, and set -e yields EMPTY output instead of the
# path under test (lesson-stubbed-binary-is-not-absent-binary).
#
# Real binaries are resolved through BASH (not the caller's shell) because under
# zsh `command -v grep` returns a shell FUNCTION name, not /usr/bin/grep, and a
# farm built from that silently loses grep.
#
# PATH IS PRESERVED (stress-test B3). A bare `env -i` clears PATH, so bash falls
# back to a compiled-in default that finds /usr/bin tools but MISSES everything
# mise- or brew-managed. Measured 2026-08-08 on this host:
#   env -i            -> python3=/usr/bin/python3            bd=NOT FOUND
#   env -i PATH=$PATH -> python3=<mise>/python/latest/bin/python3  bd=<brew>/bin/bd
# Linking the system python3 would silently test a DIFFERENT interpreter than the
# suites run under (lesson-sandboxed-test-paths-shims-usr-bin-bin).
mkdir -p "$TMP/nobd"
FARM_BINS="bash grep head sed sort dirname python3 cut tr"
for b in $FARM_BINS; do
  p="$(env -i PATH="$PATH" /bin/bash -c "command -v $b" 2>/dev/null || true)"
  case "$p" in /*) ln -sf "$p" "$TMP/nobd/$b" ;; esac
done
# COMPLETENESS ASSERTION: the `case /*)` guard SILENTLY SKIPS anything that fails
# to resolve — the same silent-escape class as an unguarded allowlist. A missing
# binary must fail here, loudly, rather than surface downstream as a mysterious
# ranker "defect".
for b in $FARM_BINS; do
  [ -e "$TMP/nobd/$b" ] \
    || { echo "FAIL: farm incomplete — '$b' did not resolve; the bd-absent result would be an ENVIRONMENT artifact, not a finding"; exit 1; }
done
set +e
nobd="$( cd "$TMP" && PATH="$TMP/nobd" bash "$SURFACE" worktree 2>&1 )"; nobd_rc=$?
set -e
[ "$nobd_rc" -eq 0 ] || { echo "FAIL: bd-absent path exited $nobd_rc, must be 0"; printf '%s\n' "$nobd"; exit 1; }
grep -q 'bd absent' <<<"$nobd" \
  || { echo "FAIL: bd-absent path does not disclose the absence"; printf '%s\n' "$nobd"; exit 1; }
echo "PASS: shape 4 — bd absent, disclosed via symlink farm (4 assertions)"

# ═══════════════════════════════════════════════════════════════════════════
# SHAPE 5 (Task 8): whitespace-only query must not trip set -u
# ═══════════════════════════════════════════════════════════════════════════

# ── 5a. MAIN path (bd + python3 both present): a whitespace-only query must
# survive end to end. rank.py's tokenize() reduces "   " to zero query terms and
# ranks nothing — a python-side empty list, not a bash array — so this leg proves
# the overall command survives whitespace input via the path most callers take.
set +e
ws="$( cd "$TMP" && bash "$SURFACE" "   " 2>&1 )"; ws_rc=$?
set -e
if grep -qiE 'unbound variable' <<<"$ws"; then
  echo "FAIL: whitespace-only query hit an unbound variable on the main path"; printf '%s\n' "$ws"; exit 1
fi
[ "$ws_rc" -eq 0 ] || [ "$ws_rc" -eq 2 ] \
  || { echo "FAIL: whitespace-only query exited $ws_rc (expected 0 or usage-error 2)"; printf '%s\n' "$ws"; exit 1; }

# ── 5b. DEGRADED (python3-absent) path. surface.sh:45's own comment names the
# guard this shape exists to pin: "${terms[@]}" would be unbound under `set -u`
# on bash 3.2 when a whitespace-only query leaves `read -ra terms` with zero
# elements. That line lives ENTIRELY inside the `command -v python3` branch
# (surface.sh:31-165) — 5a runs with python3 present and NEVER reaches it, so a
# regression that deleted the guard would leave 5a green. This leg is the only
# one that can go red for a regression on surface.sh:45 itself. Farm built the
# same way as shape 4's, minus python3 (to force the degraded branch), plus bd
# (bd must be PRESENT so the script reaches line 31 at all rather than exiting
# at line 11's bd-absent check first).
mkdir -p "$TMP/nopy_ws"
WS_FARM_BINS="bd bash grep head sed sort dirname cut tr"
for b in $WS_FARM_BINS; do
  p="$(env -i PATH="$PATH" /bin/bash -c "command -v $b" 2>/dev/null || true)"
  case "$p" in /*) ln -sf "$p" "$TMP/nopy_ws/$b" ;; esac
done
for b in $WS_FARM_BINS; do
  [ -e "$TMP/nopy_ws/$b" ] \
    || { echo "FAIL: nopy_ws farm incomplete — '$b' did not resolve; the degraded whitespace result would be an ENVIRONMENT artifact"; exit 1; }
done
set +e
ws_deg="$( cd "$TMP" && PATH="$TMP/nopy_ws" bash "$SURFACE" "   " 2>&1 )"; ws_deg_rc=$?
set -e
# LIVENESS FIRST: must have actually taken the degraded branch, else the checks
# below are vacuous — the same class Task 5/6's first-round redaction greps got
# wrong (asserting on a query that returned zero hits).
grep -q 'requires python3' <<<"$ws_deg" \
  || { echo "FAIL: degraded branch not taken for whitespace query — assertion vacuous"; printf '%s\n' "$ws_deg"; exit 1; }
if grep -qiE 'unbound variable' <<<"$ws_deg"; then
  echo "FAIL: whitespace-only query hit an unbound variable on the DEGRADED path"; printf '%s\n' "$ws_deg"; exit 1
fi
[ "$ws_deg_rc" -eq 0 ] || [ "$ws_deg_rc" -eq 2 ] \
  || { echo "FAIL: degraded whitespace query exited $ws_deg_rc (expected 0 or usage-error 2)"; printf '%s\n' "$ws_deg"; exit 1; }
echo "PASS: shape 5 — whitespace-only query survives main and degraded paths (6 assertions)"

# ═══════════════════════════════════════════════════════════════════════════
# SHAPE 6 (Task 8): near-empty store is a HEALTHY empty, never a pipeline error
# ═══════════════════════════════════════════════════════════════════════════

# ── 6. a store with zero memories and zero kb beads must report as such — not
# as a degraded or errored result. $EMPTY is folded into the EXIT trap (not left
# to a standalone `rm -rf` alone) so it cannot leak if any assertion between its
# creation and its cleanup fires `exit 1` first; $TMP already had this coverage,
# $EMPTY previously did not.
EMPTY="$(mktemp -d)"
trap 'rm -rf "$TMP" "$EMPTY"' EXIT
( cd "$EMPTY" && bd init --non-interactive --prefix emptystore >/dev/null 2>&1 )
set +e
mt="$( cd "$EMPTY" && bash "$SURFACE" worktree 2>&1 )"; mt_rc=$?
set -e
[ "$mt_rc" -eq 0 ] || { echo "FAIL: empty store exited $mt_rc"; printf '%s\n' "$mt"; exit 1; }
mt_cov="${mt%%$'\n'*}"
grep -q '^searched:' <<<"$mt_cov" \
  || { echo "FAIL: empty store emitted no coverage line"; printf '%s\n' "$mt"; exit 1; }
if grep -qiE 'UNAVAILABLE|pipeline error' <<<"$mt"; then
  echo "FAIL: healthy empty store reported as a pipeline error"; printf '%s\n' "$mt"; exit 1
fi
# Pin the AC's LITERAL wording, not just "no error string appeared" — a store
# that silently mis-counts (e.g. counting the `bd memories --json` schema-version
# envelope key as a memory, or a stale label filter narrowing an empty bead list
# to something non-zero) would pass the two checks above while failing these.
grep -q 'memories(0)' <<<"$mt_cov" \
  || { echo "FAIL: empty store coverage line does not report memories(0)"; printf '%s\n' "$mt_cov"; exit 1; }
grep -q 'kb-beads(0)' <<<"$mt_cov" \
  || { echo "FAIL: empty store coverage line does not report kb-beads(0)"; printf '%s\n' "$mt_cov"; exit 1; }
echo "PASS: shape 6 — near-empty store reports a healthy memories(0)/kb-beads(0) (4 assertions)"

echo "PASS: test-kr-corpus-shapes — shapes 1-6"
