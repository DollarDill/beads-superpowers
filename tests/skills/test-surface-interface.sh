#!/usr/bin/env bash
# tests/skills/test-surface-interface.sh — run: bash tests/skills/test-surface-interface.sh
#
# Exercises surface.sh against a REAL scratch bd DB, never a hand-authored fixture.
# lesson-a-retrieval-contract-test-must-exercise-the records why: the bsp.kb skim
# test used a fixture with keys at column 0 while bd indents by 2, so the shipped
# grep anchor matched nothing and the test still passed. Interface layers see
# genuine tool output or they prove nothing.
#
# Assertions read captured output from HERE-STRINGS, never `printf … | grep -q`:
# under `set -o pipefail` an early-exiting consumer SIGPIPEs the producer and the
# pipeline returns 141, flipping a passing assertion to a spurious FAIL.
#
# Inputs are chosen to be the HARDEST shape the interface accepts, not the one
# that happens to work: the degraded path is exercised with a multi-word phrase,
# the label filter with a hyphenated label, and the key column with a key longer
# than its pad width. Four defects shipped because earlier assertions picked the
# single easy shape in each of those three classes.
set -euo pipefail
command -v bd >/dev/null 2>&1 || { echo "SKIP: test-surface-interface (bd absent)"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: test-surface-interface (python3 absent)"; exit 0; }

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SURFACE="$REPO/skills/knowledge-retrieval/scripts/surface.sh"
[ -f "$SURFACE" ] || { echo "FAIL: $SURFACE missing"; exit 1; }

# The test owns its DB via cwd; an inherited BEADS_DIR would silently redirect
# every bd call in here at the caller's store.
unset BEADS_DIR
TMP="$(mktemp -d)"
NODB="$(mktemp -d)"          # sibling of TMP, so no .beads is reachable by walking up
trap 'rm -rf "$TMP" "$NODB"' EXIT

# 64 chars — longer than the 42-column key pad. 61% of the live store's keys
# exceed 42, and a cut key does not resolve through `bd recall`.
LONGKEY=lesson-a-retrieval-contract-test-must-exercise-the-real-interface

# ── read-only guard: the retriever never mutates a store (design: "Reads only")
grep -nE 'bd (create|close|update|remember|forget|init|delete|import)|bd dolt (push|pull)' "$SURFACE" \
  && { echo "FAIL: mutating bd command in surface.sh"; exit 1; }

# ── scratch corpus: real bd writes, real bd JSON
( cd "$TMP" && bd init --non-interactive --prefix probe --skip-agents --skip-hooks >/dev/null 2>&1 )
# No @salience header — 66% of the real store looks like this.
( cd "$TMP" && bd remember \
  "bd worktree create makes ./name not .worktrees/name — pass the full path" \
  --key lesson-worktree-path-gotchas >/dev/null )
# Explicit @salience=4, plus hazard phrasing.
( cd "$TMP" && bd remember "@type=lesson @salience=4
Never chain open after bd commands in one invocation — it hangs." \
  --key lesson-open-after-bd >/dev/null )
# Over-length key: the printed key is the agent's next command, so it must survive.
( cd "$TMP" && bd remember \
  "retrieval contract tests must exercise the real interface, never a hand-authored fixture" \
  --key "$LONGKEY" >/dev/null )
( cd "$TMP" && printf '%s' \
  "Worktree isolation gives each parallel plan task its own bd worktree, preventing merge conflicts between concurrent subagents." \
  | bd create "ADR-0002 per-task worktree isolation" -t decision -l kb,sdd-process \
      --defer 2099-01-01 --body-file - --silent >/dev/null )
( cd "$TMP" && printf '%s' \
  "The docs site publishes from the-factory-website repo, not from this repo." \
  | bd create "ADR-0050 docs publishing" -t decision -l kb,docs \
      --defer 2099-01-01 --body-file - --silent >/dev/null )
# Title carries the ONLY occurrence of "xenolith" — the description below never
# repeats it. Beads index title+description together (FR4, beads-superpowers-
# eo9z2): a title-only term must still be retrievable, not silently dropped
# the way `description or title` drops the title whenever description is
# non-empty (the real live store: all 232 kb beads have a description, so no
# bead title was ever searchable before this fix). Labelled adr-process, NOT
# docs/sdd-process, so it doesn't shift the label-count assertions below.
( cd "$TMP" && printf '%s' \
  "This decision covers an unrelated labelling convention with no repeated marker word." \
  | bd create "ADR-0099 xenolith retrieval marker decision" -t decision -l kb,adr-process \
      --defer 2099-01-01 --body-file - --silent >/dev/null )
# A NON-ASCII topic label. Labels tokenize through tokenize_label(), not
# tokenize(): it emits no CJK unigrams and fails closed on any CJK run shorter
# than two characters, so a bare single-character label like this one can never
# form a bigram and tokenizes to the EMPTY set — and in Python `set() <= anything`
# is True, so a subset matcher without a truthiness guard fires this label on
# EVERY query and narrows the whole bead corpus to its bucket
# (beads-superpowers-eo9z2.7). This repo ships Chinese docs, so the label set is
# one contributor away from this. LOAD-BEARING: the label below must stay a
# SINGLE CJK character — a two-or-more-character CJK label (e.g. 中文) keeps its
# own bigram under tokenize_label() and is no longer empty, which makes this
# assertion pass identically whether or not the truthiness guard exists (the
# vacuity 7a279cc fixed).
( cd "$TMP" && printf '%s' \
  "A decision carrying a non-ASCII topic label, used to prove the label matcher ignores empty-tokenizing labels." \
  | bd create "ADR-0100 non-ascii label guard" -t decision -l kb,库 \
      --defer 2099-01-01 --body-file - --silent >/dev/null )

# ── 1. coverage line opens every result set
out="$( cd "$TMP" && bash "$SURFACE" "worktree gotchas" )"
grep -qE '^searched: memories\([0-9][0-9]*\) kb-beads\([0-9][0-9]*\)' <<<"${out%%$'\n'*}" \
  || { echo "FAIL: coverage line absent or not first"; printf '%s\n' "$out"; exit 1; }

# ── 2. the count is what was SEARCHED. bd memories --json wraps the map in a
# "schema_version" envelope key; counting raw map entries reports memories(4)
# for a 3-memory store — a miscount inside the line that exists to prevent one.
grep -q 'memories(3)' <<<"$out" \
  || { echo "FAIL: memory count wrong (bd's schema_version envelope key counted?)"; printf '%s\n' "$out"; exit 1; }

# ── 3. a multi-word query returns its known-correct hit (bd itself returns zero
# here: it substring-matches the whole phrase)
grep -q 'lesson-worktree-path-gotchas' <<<"$out" \
  || { echo "FAIL: multi-word query returned no known hit"; printf '%s\n' "$out"; exit 1; }

# ── 4. unset salience renders visibly unset, never a plausible-looking number.
# SALIENCE_UNSET is -1; printing it as "s-1" reads like real data — the same
# fabrication the eo9z2.2 finding closed inside the ranker.
grep -qE '^  lesson-worktree-path-gotchas +s[?] ' <<<"$out" \
  || { echo "FAIL: unset salience not rendered as s?"; printf '%s\n' "$out"; exit 1; }
grep -q 's-1' <<<"$out" \
  && { echo "FAIL: SALIENCE_UNSET leaked to the display layer as s-1"; exit 1; }

# ── 5. a populated salience still renders its real value, with the hazard flag
haz="$( cd "$TMP" && bash "$SURFACE" "never chain open" )"
grep -qE '^  lesson-open-after-bd +s4 +HAZ ' <<<"$haz" \
  || { echo "FAIL: explicit salience/hazard not rendered"; printf '%s\n' "$haz"; exit 1; }

# ── 6. the printed key is the ACTIONABLE PAYLOAD — `bd recall <key>` is the
# agent's next move, so the key column pads but never truncates. Asserted by
# round-tripping whatever was printed back through bd: a cut key resolves to
# nothing, which no text assertion on a short key would ever catch.
lng="$( cd "$TMP" && bash "$SURFACE" "retrieval contract" )"
lkey="$(awk '$1 ~ /^lesson-a-retrieval-contract/ {print $1; exit}' <<<"$lng")"
[ -n "$lkey" ] || { echo "FAIL: over-length-key memory not returned at all"; printf '%s\n' "$lng"; exit 1; }
rec="$( cd "$TMP" && bd recall "$lkey" 2>&1 )" || true   # an unresolvable key exits non-zero
grep -q 'hand-authored fixture' <<<"$rec" \
  || { echo "FAIL: printed key does not resolve (truncated?): bd recall '$lkey' -> $rec"; exit 1; }

# ── 7. label filter is stage-1 recall for beads (ADR-0056), and it is disclosed
lab="$( cd "$TMP" && bash "$SURFACE" docs )"
grep -qE '^searched: memories\([0-9][0-9]*\) kb-beads\(1\) label=docs' <<<"${lab%%$'\n'*}" \
  || { echo "FAIL: label filter absent or undisclosed"; printf '%s\n' "$lab"; exit 1; }

# ── 8. …including HYPHENATED labels, in both the hyphenated and the spaced form.
# tokenize() splits on hyphens, so a whole-string label comparison can never fire
# for these — 10 of the live store's 19 labels, its four largest buckets included.
for q in sdd-process "sdd process"; do
  hyp="$( cd "$TMP" && bash "$SURFACE" "$q" )"
  grep -qE '^searched: memories\([0-9][0-9]*\) kb-beads\(1\) label=sdd-process' <<<"${hyp%%$'\n'*}" \
    || { echo "FAIL: hyphenated label filter never fires for query '$q'"; printf '%s\n' "$hyp"; exit 1; }
done

# ── 8b. an EMPTY-TOKENIZING label never fires (beads-superpowers-eo9z2.7).
# `set() <= qtok` is True for any query, so without a truthiness guard the
# non-ASCII label above joins `named` on every search and its bucket is unioned
# into the results — silently changing what was searched. This check asserts
# through the real __main__ path, which the predicate-level invariants in
# rank_invariants.py do not cover — those exercise label_narrows() directly,
# never surface.sh's end-to-end wiring of it into the CLI.
nas="$( cd "$TMP" && bash "$SURFACE" docs )"
# The trailing `$` is LOAD-BEARING: it proves `label=docs` is the COMPLETE label
# list, i.e. the non-ASCII label did NOT union in (beads-superpowers-eo9z2.7).
# eo9z2.27 appended the boundary clause after the label, so the anchor moved to
# the end of that clause — it was NOT dropped. Dropping it would let
# `label=docs,库` pass and silently defang this guard.
grep -qE '^searched: memories\([0-9][0-9]*\) kb-beads\(1\) label=docs — open backlog not indexed \(doing-moment scope\)$' <<<"${nas%%$'\n'*}" \
  || { echo "FAIL: empty-tokenizing label leaked into the label filter"; printf '%s\n' "$nas"; exit 1; }

# ── 9. injection: metacharacter queries are one argument and execute nothing
# shellcheck disable=SC2016  # the un-expanded $(...) and backticks ARE the payload
for payload in 'x"; touch INJECTED; echo "' '$(touch PWNED)' '`touch BACKTICKED`'; do
  ( cd "$TMP" && bash "$SURFACE" "$payload" ) >/dev/null 2>&1 || true
done
for canary in INJECTED PWNED BACKTICKED; do
  [ -e "$TMP/$canary" ] && { echo "FAIL: query reached a shell ($canary created)"; exit 1; }
done

# ── 10. bd failing is reported, never rendered as an empty store
err="$( cd "$NODB" && bash "$SURFACE" worktree )"
grep -q 'UNAVAILABLE' <<<"$err" \
  || { echo "FAIL: bd error reported as an empty corpus"; printf '%s\n' "$err"; exit 1; }

# ── 11. python3 absent: visible notice, coverage line, keys only, clean exit —
# driven by the MULTI-WORD phrase SKILL.md documents, because bd substring-matches
# the whole argument and that is the shape that returns nothing when unhandled.
# Bodies are withheld because redact() lives in rank.py — a floor with a bypass
# is not a floor (orient.sh:29-33 is the precedent for the visible notice).
mkdir -p "$TMP/nopy"
for b in bd bash grep head sed sort dirname; do
  p="$(command -v "$b" || true)"
  case "$p" in /*) ln -sf "$p" "$TMP/nopy/$b" ;; esac
done
set +e
deg="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" "worktree hangs" )"
deg_rc=$?
set -e
[ "$deg_rc" -eq 0 ] || { echo "FAIL: degraded path exited $deg_rc, must be 0"; printf '%s\n' "$deg"; exit 1; }
grep -q "requires python3" <<<"$deg" \
  || { echo "FAIL: python3-absent degradation is silent"; printf '%s\n' "$deg"; exit 1; }
grep -q '^searched:' <<<"${deg%%$'\n'*}" \
  || { echo "FAIL: degraded path emits no coverage line"; printf '%s\n' "$deg"; exit 1; }
# The query is "worktree hangs", and that choice IS the assertion: "worktree"
# finds ONLY lesson-worktree-path-gotchas, "hangs" finds ONLY lesson-open-after-bd,
# so BOTH keys appear only if the per-term results are genuinely unioned. The old
# query "worktree gotchas" had either term alone finding the single asserted key,
# so a loop that disclosed every term while searching only terms[0] still passed —
# the assertion could not fail (beads-superpowers-eo9z2.8). Verified 2026-08-02:
# that exact mutation left the old fixture GREEN and turns this one RED.
grep -q 'lesson-worktree-path-gotchas' <<<"$deg" \
  || { echo "FAIL: degraded path term-1 hit missing — per-term union broken"; printf '%s\n' "$deg"; exit 1; }
grep -q 'lesson-open-after-bd' <<<"$deg" \
  || { echo "FAIL: degraded path term-2 hit missing — per-term union broken"; printf '%s\n' "$deg"; exit 1; }
grep -q 'terms=worktree,hangs' <<<"$deg" \
  || { echo "FAIL: degraded path does not disclose which terms it searched"; printf '%s\n' "$deg"; exit 1; }
grep -q '\.worktrees/name' <<<"$deg" \
  && { echo "FAIL: degraded path printed an unredacted body"; printf '%s\n' "$deg"; exit 1; }

# ── 11b. degraded path: a KEY containing uppercase, underscore, or a dot must
# not be silently dropped by the withholding anchor — the real live-store shape
# (lesson-grep-E-alternation-bug) has an uppercase letter, and the anchor's
# charset was [a-z0-9-] only (FR1, beads-superpowers-eo9z2). The security floor
# this touches — full-line anchor, 2-space indent, bodies withheld without
# python3 — must still hold: the multi-word body below must NOT appear.
( cd "$TMP" && bd remember \
  "an unredacted alternation pattern must never leak across a truncation boundary in this body" \
  --key "lesson-Grep_E.alternation-bug" >/dev/null )
set +e
deg2="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" "alternation" )"
deg2_rc=$?
set -e
[ "$deg2_rc" -eq 0 ] || { echo "FAIL: degraded path (mixed-charset key) exited $deg2_rc, must be 0"; printf '%s\n' "$deg2"; exit 1; }
grep -q 'lesson-Grep_E.alternation-bug' <<<"$deg2" \
  || { echo "FAIL: degraded path drops a key containing uppercase/underscore/dot"; printf '%s\n' "$deg2"; exit 1; }
grep -q 'unredacted alternation pattern' <<<"$deg2" \
  && { echo "FAIL: degraded path printed body text for a mixed-charset key (security floor breach)"; printf '%s\n' "$deg2"; exit 1; }

# ── 11c. the PER-TERM bd exit status is constrained (beads-superpowers-eo9z2.8).
# Assertion 12 below cannot constrain it: when bd is broken for EVERY call, the
# `bd memories --json` corpus fetch at the top of surface.sh has already set
# degraded=memories before the per-term loop runs, so the loop's else-branch is
# redundant and reverting it to `|| true` leaves the suite green (verified
# 2026-08-02). Only a bd that fails for ONE term can prove the per-term record.
# This is failure INJECTION, not a hand-authored fixture: every other call
# delegates to the real binary, so the success path still sees genuine output.
mkdir -p "$TMP/onefail"
REALBD="$(command -v bd)"
cat > "$TMP/onefail/bd" <<EOF
#!/bin/sh
if [ "\$1" = "memories" ] && [ "\$2" = "hangs" ]; then exit 1; fi
exec "$REALBD" "\$@"
EOF
chmod 755 "$TMP/onefail/bd"
set +e
onefail="$( cd "$TMP" && PATH="$TMP/onefail:$TMP/nopy" bash "$SURFACE" "worktree hangs" )"
onefail_rc=$?
set -e
[ "$onefail_rc" -eq 0 ] || { echo "FAIL: per-term-failure path exited $onefail_rc, must be 0"; printf '%s\n' "$onefail"; exit 1; }
# The distinction is the whole point: "memories(DEGRADED)" means python3 was
# absent but the memory source answered, whereas "memories UNAVAILABLE(bd error)"
# means the source itself failed. Without the per-term record this run reports
# the former and the failed term vanishes silently.
grep -q 'memories UNAVAILABLE' <<<"$onefail" \
  || { echo "FAIL: a per-term bd failure is not recorded on the coverage line"; printf '%s\n' "$onefail"; exit 1; }

# ── 11d. a BROKEN degraded pipeline is DISCLOSED, never rendered as zero hits
# (beads-superpowers-eo9z2.23). surface.sh runs under `set -o pipefail`, so a
# missing/erroring grep genuinely propagates — the old `|| true` was what
# swallowed it, leaving output byte-identical to a real empty result. The
# reviewer hit this by accident while building a restricted PATH.
mkdir -p "$TMP/nogrep"
printf '#!/bin/sh\nexit 127\n' > "$TMP/nogrep/grep"; chmod 755 "$TMP/nogrep/grep"
set +e
brk="$( cd "$TMP" && PATH="$TMP/nogrep:$TMP/nopy" bash "$SURFACE" "worktree hangs" )"
brk_rc=$?
set -e
[ "$brk_rc" -eq 0 ] || { echo "FAIL: broken-pipeline path exited $brk_rc, must be 0"; printf '%s\n' "$brk"; exit 1; }
grep -q 'pipeline error' <<<"$brk" \
  || { echo "FAIL: broken degraded pipeline rendered as a genuine zero-hit result"; printf '%s\n' "$brk"; exit 1; }

# ── 12. python3 absent AND bd broken: the coverage line NAMES the dead source.
# Rendering it as a fixed "memories(DEGRADED)" makes "bd is broken" and "nothing
# matched" identical — the silent partial the coverage line exists to prevent.
set +e
degerr="$( cd "$NODB" && PATH="$TMP/nopy" bash "$SURFACE" worktree )"
degerr_rc=$?
set -e
[ "$degerr_rc" -eq 0 ] || { echo "FAIL: degraded+bd-error path exited $degerr_rc, must be 0"; printf '%s\n' "$degerr"; exit 1; }
grep -q 'UNAVAILABLE' <<<"${degerr%%$'\n'*}" \
  || { echo "FAIL: degraded coverage line hides the bd failure"; printf '%s\n' "$degerr"; exit 1; }

# ── 13. no query is a usage error, not an empty search
set +e
( cd "$TMP" && bash "$SURFACE" >/dev/null 2>&1 )
usage_rc=$?
set -e
[ "$usage_rc" -eq 2 ] || { echo "FAIL: no-argument invocation exited $usage_rc, expected 2"; exit 1; }

# ── 14. a term appearing ONLY in a bead's TITLE (never its description) must
# still be retrievable — FR4, beads-superpowers-eo9z2. Query has no label match
# (adr-process isn't a token of "xenolith"), so this exercises the docs.update()
# title/description combine directly, not the label-recall stage.
title_only="$( cd "$TMP" && bash "$SURFACE" xenolith )"
grep -qi 'xenolith' <<<"$title_only" \
  || { echo "FAIL: title-only term not retrievable (bead title not indexed)"; printf '%s\n' "$title_only"; exit 1; }

# ── 15. the degraded path DISCLOSES truncation (beads-superpowers-eo9z2.9).
# 20 keys shown out of a larger set must say so; a silent cut is the exact
# "visible degradation, never a silent partial" violation the coverage line prevents.
#
# Seed past the cut IN THE SCRATCH STORE — the base corpus is 8 entries, so without
# this the >20 branch is unreachable and the assertion could never fail.
#
# THE KEY PREFIX IS LOAD-BEARING, NOT COSMETIC. Keys are `sort -u`'d then cut at 20.
# A prefix sorting BEFORE "lesson-" (e.g. "fixture-") fills all 20 slots and pushes
# every security-floor fixture out of the window, leaving assertions 11/11b passing
# VACUOUSLY — a body cannot leak from a key that was never rendered. Measured:
# "fixture-*" => 0 of 3 floor fixtures survive; "zz-*" => 3 of 3. This block also runs
# AFTER assertions 11/11b for the same reason.
for i in $(seq -w 1 21); do   # 21 = minimum to exceed the 20-key cut; each bd write costs ~1s
  ( cd "$TMP" && bd remember "degraded truncation fixture number $i" \
      --key "zz-truncation-$i" >/dev/null )
done

deg_trunc="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" "zz truncation" 2>&1 )"
grep -qF -e 'showing 20 of' <<<"$deg_trunc" \
  || { echo "FAIL: degraded path truncated to 20 keys without disclosing the total"; printf '%s\n' "$deg_trunc"; exit 1; }
disclosed="$( grep -oE 'showing 20 of [0-9]+ keys' <<<"$deg_trunc" | grep -oE '[0-9]+ keys' | grep -oE '[0-9]+' )"
[ "${disclosed:-0}" -ge 21 ] \
  || { echo "FAIL: disclosed total ${disclosed:-0} is below the 21 seeded fixtures"; exit 1; }

# FLOOR LIVENESS: prove the seeding did not displace the floor fixtures. Without this,
# a future change to the key prefix silently re-defangs the two body-leak assertions.
deg_floor="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" "worktree hangs" 2>&1 )"
grep -q 'lesson-worktree-path-gotchas' <<<"$deg_floor" \
  || { echo "FAIL: seeding displaced the floor fixture from the degraded window — the body-leak assertions are now vacuous"; printf '%s\n' "$deg_floor"; exit 1; }

# ── 16. a HEALTHY EMPTY result is not a pipeline error (beads-superpowers-eo9z2.28).
# grep exits 1 on no-match, which is normal; under pipefail a bare `if !` conflated
# that with real breakage, so an empty store read as a broken toolchain — eo9z2.23's
# fix inverted. Query a term the scratch corpus cannot contain.
deg_empty="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" "zzzznomatchzzzz" 2>&1 )"
grep -q 'keys UNAVAILABLE(pipeline error)' <<<"$deg_empty" \
  && { echo "FAIL: healthy-but-empty degraded result reported as a pipeline error"; printf '%s\n' "$deg_empty"; exit 1; }

# ── 17. the coverage line names its BOUNDARY (beads-superpowers-eo9z2.27).
# "beads(N)" read as "all beads"; in fact only kb-labelled knowledge beads are indexed
# and the open backlog is out of scope BY DESIGN (spec D5: knowledge-retrieval serves
# the doing moment, backlog query serves the choosing moment). Disclosed, not widened.
cov="$( cd "$TMP" && bash "$SURFACE" "lesson" 2>&1 | head -1 )"
grep -q 'kb-beads(' <<<"$cov" \
  || { echo "FAIL: coverage line does not name the bead source as the knowledge store: $cov"; exit 1; }
grep -q 'backlog not indexed' <<<"$cov" \
  || { echo "FAIL: coverage line does not disclose the open-backlog exclusion: $cov"; exit 1; }
# The disclosure is deliberate SCOPE, never a degraded source — a reader must not
# confuse it with 'beads UNAVAILABLE'.
grep -qE 'UNAVAILABLE|DEGRADED|SKIPPED' <<<"$cov" \
  && { echo "FAIL: boundary disclosure must not read as a degraded source: $cov"; exit 1; }

# ── 18. the too-many-hits branch exists where the pointer promises it
# (beads-superpowers-eo9z2.12). SKILL.md's closing pointer offers help when a query
# "returns more than you can disposition", but the target file only ever handled the
# zero-result case — a pointer promising a branch that is not there.
QS="$REPO/skills/knowledge-retrieval/references/query-strategy.md"
grep -qF -e 'narrow the query, never triage truncated titles' "$QS" \
  || { echo "FAIL: query-strategy.md promises a too-many-hits branch it does not deliver"; exit 1; }
# The degraded path is where the bound matters most: with no ranker, nothing bounds
# the returned set except the query itself.
grep -qF -e 'narrow the query, never triage truncated titles' \
     "$REPO/skills/knowledge-retrieval/SKILL.md" \
  || { echo "FAIL: SKILL.md carries no narrowing clause for the degraded path"; exit 1; }

# ── 19. a secret in the memory KEY is redacted (beads-superpowers-wze77.7).
# redact() only ever reached the body, so an entry printed "[REDACTED]" in its
# excerpt column beside a key spelling the credential out. bd derives the key from
# the body's leading words and LOWERCASES it; AWS access key ids are
# uppercase-alphanumeric only, so that mangling is losslessly reversible — upcase
# the key column and you have the credential back.
#
# Written against a REAL bd write on purpose: rank_invariants.py pins the pattern
# against transcribed spellings, and only this can prove the transcription still
# matches what bd actually derives. A hand-authored key would test my model of the
# mangling, which is the failure mode this file's header warns about.
#
# Runs LAST so the memory it seeds cannot move the memories(3) count assertion 2
# pins, nor the 20-key degraded window assertion 15 measures.
#
# Token assembled at runtime — a contiguous AKIA literal in a committed file trips
# GH013 push protection (same idiom as rank_invariants.py's fixtures).
FAKE_AKIA="AKIA$(printf 'FAKE%.0s' 1 2 3 4)"
( cd "$TMP" && bd remember "$FAKE_AKIA appeared in the deploy log during rollout" >/dev/null )
keyleak="$( cd "$TMP" && bash "$SURFACE" deploy rollout )"
# LIVENESS FIRST. The leak check below is a NEGATIVE grep, and a negative grep over
# a result set that does not contain the entry passes for the wrong reason. The
# surviving tail of the redacted key proves the hit came back AND that only the
# credential span was cut.
grep -q 'appeared-in-the-deploy-log' <<<"$keyleak" \
  || { echo "FAIL: poisoned entry absent from the result set — the key-leak assertion would be vacuous"; printf '%s\n' "$keyleak"; exit 1; }
# -i, because bd's own lowercasing is the whole defect: a case-sensitive grep here
# would pass against the exact leak this assertion exists to catch.
grep -qi "$FAKE_AKIA" <<<"$keyleak" \
  && { echo "FAIL: a secret in the memory KEY printed in the clear"; printf '%s\n' "$keyleak"; exit 1; }

# ── 20. DEGRADED PATH: a secret-shaped KEY is WITHHELD (beads-superpowers-wze77.8).
# wze77.7 closed the key leak inside rank.py. The degraded path never reaches
# rank.py — surface.sh greps keys straight out of `bd memories` and prints them —
# so redact_key() cannot run there BY CONSTRUCTION, and every shape it catches
# printed in the clear on the one path whose own banner says "redaction
# unavailable". The AWS shape is the sharp one: bd lowercases the key and AWS
# access key ids are uppercase-alphanumeric only, so upcasing the printed column
# hands back the credential.
#
# ALL FOUR shapes _SECRET_KEY knows are exercised, not just the reported one.
# The PEM shape is the trap: bd DELETES the `-----` fences outright
# (`begin-rsa-private-key-mii…`), so a fence-anchored pattern misses it however
# case-insensitive it is.
#
# Tokens are assembled at runtime — a contiguous credential literal in a
# committed file trips GH013 push protection (same idiom as assertion 19).
FAKE_SK="sk-$(printf 'FAKEsk%.0s' 1 2 3 4)"
FAKE_GHP="ghp_$(printf 'FAKEghp%.0s' 1 2 3 4)"
FAKE_PEM="-----BEGIN RSA PRIVATE KEY-----MII$(printf 'FAKEpem%.0s' 1 2 3 4)"
# `--` is mandatory for the PEM body: it starts with `-----`, which bd's flag
# parser would otherwise consume as options.
for tok in "$FAKE_SK" "$FAKE_GHP" "$FAKE_AKIA" "$FAKE_PEM"; do
  ( cd "$TMP" && bd remember -- "$tok xylophone marker for the degraded key filter" >/dev/null )
done
set +e
degkey="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" xylophone )"
degkey_rc=$?
set -e
[ "$degkey_rc" -eq 0 ] || { echo "FAIL: degraded key-filter path exited $degkey_rc, must be 0"; printf '%s\n' "$degkey"; exit 1; }
# LIVENESS FIRST, as in assertion 19: every check below is a NEGATIVE grep, and a
# negative grep over an empty result set passes for the wrong reason. The
# withheld notice is the positive proof that all four poisoned entries were
# genuinely retrieved and then suppressed — not that the query missed them.
withheld_n="$( grep -oE '\(([0-9]+) secret-shaped key' <<<"$degkey" | grep -oE '[0-9]+' || true )"
[ "${withheld_n:-0}" -ge 4 ] \
  || { echo "FAIL: degraded path discloses ${withheld_n:-0} withheld keys, expected >=4 — the leak checks below would be vacuous"; printf '%s\n' "$degkey"; exit 1; }
# EVERY hit for this query is secret-shaped, so NO key line may survive. This is
# what makes the fail-closed contract falsifiable: redacting a span instead of
# dropping the line would still print a key here.
grep -qE '^  [A-Za-z0-9._-]+$' <<<"$degkey" \
  && { echo "FAIL: a key line survived a query whose every hit is secret-shaped"; printf '%s\n' "$degkey"; exit 1; }
# Per-vector: the raw token AND the bd-mangled fragment bd actually derives from
# it. Checking only the raw token would pass against the reported leak, because
# bd never writes the raw token into a key — it writes the mangled one.
vec_names="sk ghp akia pem"
vec_toks=( "$FAKE_SK" "$FAKE_GHP" "$FAKE_AKIA" "$FAKE_PEM" )
vec_frags=( "sk-fakesk" "ghp-fakeghp" "akiafake" "miifakepem" )
i=0
for name in $vec_names; do
  # -i throughout: bd's lowercasing is the whole defect, so a case-sensitive
  # grep here would pass against the exact leak this assertion exists to catch.
  grep -qiF -e "${vec_toks[$i]}" <<<"$degkey" \
    && { echo "FAIL: degraded path printed the raw $name credential"; printf '%s\n' "$degkey"; exit 1; }
  grep -qiF -e "${vec_frags[$i]}" <<<"$degkey" \
    && { echo "FAIL: degraded path printed the bd-mangled $name credential"; printf '%s\n' "$degkey"; exit 1; }
  i=$((i + 1))
done

# ── 20b. the SAME four vectors are covered on the python3-PRESENT path too.
# Two paths, two implementations of one rule: this runs one fixture set through
# both, so a vector closed on one side and open on the other is a red suite
# rather than a discovery.
heal="$( cd "$TMP" && bash "$SURFACE" xylophone )"
red_n="$( grep -cF '[REDACTED]' <<<"$heal" || true )"
[ "${red_n:-0}" -ge 4 ] \
  || { echo "FAIL: ranked path redacted ${red_n:-0} of 4 poisoned entries — the leak checks below would be vacuous"; printf '%s\n' "$heal"; exit 1; }
i=0
for name in $vec_names; do
  grep -qiF -e "${vec_toks[$i]}" <<<"$heal" \
    && { echo "FAIL: ranked path printed the raw $name credential"; printf '%s\n' "$heal"; exit 1; }
  grep -qiF -e "${vec_frags[$i]}" <<<"$heal" \
    && { echo "FAIL: ranked path printed the bd-mangled $name credential"; printf '%s\n' "$heal"; exit 1; }
  i=$((i + 1))
done

# ── 20c. a DEAD key filter fails closed and stays quiet on stderr.
# Assertion 11d kills grep outright, which takes the body-withholding anchor down
# with it — so the filter's own error branch is never reached there. Only a grep
# that answers the anchor and dies on the filter can reach it. Two properties:
# no key survives a filter that did not run (fail closed, not fail open), and the
# suppressed count is reset to an integer rather than left as grep's empty output,
# which would turn the later `-gt 0` into a shell error on a security path.
mkdir -p "$TMP/badfilter"
REALGREP="$(command -v grep)"
cat > "$TMP/badfilter/grep" <<EOF
#!/bin/sh
for a in "\$@"; do
  case "\$a" in *PRIVATE*) exit 2 ;; esac
done
exec "$REALGREP" "\$@"
EOF
chmod 755 "$TMP/badfilter/grep"
set +e
badf="$( cd "$TMP" && PATH="$TMP/badfilter:$TMP/nopy" bash "$SURFACE" xylophone 2>&1 )"
badf_rc=$?
set -e
[ "$badf_rc" -eq 0 ] || { echo "FAIL: dead-key-filter path exited $badf_rc, must be 0"; printf '%s\n' "$badf"; exit 1; }
grep -q 'pipeline error' <<<"$badf" \
  || { echo "FAIL: a key filter that could not run is not disclosed"; printf '%s\n' "$badf"; exit 1; }
grep -qE '^  [A-Za-z0-9._-]+$' <<<"$badf" \
  && { echo "FAIL: keys printed although the secret filter never ran (fails open)"; printf '%s\n' "$badf"; exit 1; }
grep -qi 'integer expression expected' <<<"$badf" \
  && { echo "FAIL: suppressed count left non-numeric — shell error on the security path"; printf '%s\n' "$badf"; exit 1; }

# ── 21. DRIFT CONTROL: the shell key filter mirrors rank.py's _SECRET_KEY.
# The degraded path cannot call rank.py, so the shapes are necessarily spelled
# twice, in two languages. This is the mechanism that keeps them in sync: every
# alternation in _SECRET_KEY must contribute its literal prefix to surface.sh's
# ERE, so adding a sixth shape to the ranker without teaching the shell filter
# about it turns this suite red. Extraction is mechanical — a hand-listed set of
# prefixes here would drift exactly the way the patterns do.
RANKPY="$REPO/skills/knowledge-retrieval/scripts/rank.py"
pyre="$( sed -n '/_SECRET_KEY = re\.compile(/,/re\.S | re\.I)/p' "$RANKPY" \
         | grep -oE 'r"[^"]*"' | sed 's/^r"//; s/"$//' | tr -d '\n' )"
[ -n "$pyre" ] || { echo "FAIL: could not extract _SECRET_KEY from rank.py (drift guard is vacuous)"; exit 1; }
IFS='|' read -ra pyalts <<<"$pyre"
[ "${#pyalts[@]}" -ge 4 ] \
  || { echo "FAIL: _SECRET_KEY parsed into ${#pyalts[@]} alternations, expected >=4 (drift guard is vacuous)"; exit 1; }
for alt in "${pyalts[@]}"; do
  # Literal prefix = everything before the first character class. "sk[-_]…" -> "sk",
  # "-*BEGIN[ -]…" -> "-*BEGIN", "AKIA[0-9A-Za-z]{16})" -> "AKIA".
  lit="$( printf '%s' "$alt" | sed 's/^(//; s/\[.*//; s/)$//' )"
  [ -n "$lit" ] || continue
  grep -qF -e "$lit" "$SURFACE" \
    || { echo "FAIL: _SECRET_KEY alternation '$lit' has no counterpart in surface.sh's key filter (patterns have drifted)"; exit 1; }
done

echo "PASS: surface.sh — coverage line, counts, salience rendering, untruncated keys, hyphenated label filter, injection-inert, bd-error visible, degradation, truncation disclosure, empty-vs-error, boundary disclosure, too-many-hits branch, key redaction, degraded-path key withholding (4 vectors, both paths), dead-filter fail-closed, pattern-drift guard"
