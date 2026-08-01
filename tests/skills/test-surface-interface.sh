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

# ── 1. coverage line opens every result set
out="$( cd "$TMP" && bash "$SURFACE" "worktree gotchas" )"
grep -qE '^searched: memories\([0-9][0-9]*\) beads\([0-9][0-9]*\)' <<<"${out%%$'\n'*}" \
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
grep -qE '^searched: memories\([0-9][0-9]*\) beads\(1\) label=docs' <<<"${lab%%$'\n'*}" \
  || { echo "FAIL: label filter absent or undisclosed"; printf '%s\n' "$lab"; exit 1; }

# ── 8. …including HYPHENATED labels, in both the hyphenated and the spaced form.
# tokenize() splits on hyphens, so a whole-string label comparison can never fire
# for these — 10 of the live store's 19 labels, its four largest buckets included.
for q in sdd-process "sdd process"; do
  hyp="$( cd "$TMP" && bash "$SURFACE" "$q" )"
  grep -qE '^searched: memories\([0-9][0-9]*\) beads\(1\) label=sdd-process' <<<"${hyp%%$'\n'*}" \
    || { echo "FAIL: hyphenated label filter never fires for query '$q'"; printf '%s\n' "$hyp"; exit 1; }
done

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
deg="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" "worktree gotchas" )"
deg_rc=$?
set -e
[ "$deg_rc" -eq 0 ] || { echo "FAIL: degraded path exited $deg_rc, must be 0"; printf '%s\n' "$deg"; exit 1; }
grep -q "requires python3" <<<"$deg" \
  || { echo "FAIL: python3-absent degradation is silent"; printf '%s\n' "$deg"; exit 1; }
grep -q '^searched:' <<<"${deg%%$'\n'*}" \
  || { echo "FAIL: degraded path emits no coverage line"; printf '%s\n' "$deg"; exit 1; }
grep -q 'lesson-worktree-path-gotchas' <<<"$deg" \
  || { echo "FAIL: degraded path surfaced no matching key for a multi-word query"; printf '%s\n' "$deg"; exit 1; }
grep -q 'terms=worktree,gotchas' <<<"$deg" \
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

echo "PASS: surface.sh — coverage line, counts, salience rendering, untruncated keys, hyphenated label filter, injection-inert, bd-error visible, degradation"
