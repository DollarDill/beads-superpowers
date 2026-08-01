#!/usr/bin/env bash
# tests/skills/test-surface-interface.sh — run: bash tests/skills/test-surface-interface.sh
#
# Exercises surface.sh against a REAL scratch bd DB, never a hand-authored fixture.
# lesson-a-retrieval-contract-test-must-exercise-the records why: the bsp.kb skim
# test used a fixture with keys at column 0 while bd indents by 2, so the shipped
# grep anchor matched nothing and the test still passed. Interface layers see
# genuine tool output or they prove nothing.
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
( cd "$TMP" && printf '%s' \
  "Worktree isolation gives each parallel plan task its own bd worktree, preventing merge conflicts between concurrent subagents." \
  | bd create "ADR-0002 per-task worktree isolation" -t decision -l kb,sdd-process \
      --defer 2099-01-01 --body-file - --silent >/dev/null )
( cd "$TMP" && printf '%s' \
  "The docs site publishes from the-factory-website repo, not from this repo." \
  | bd create "ADR-0050 docs publishing" -t decision -l kb,docs \
      --defer 2099-01-01 --body-file - --silent >/dev/null )

# ── 1. coverage line opens every result set
out="$( cd "$TMP" && bash "$SURFACE" "worktree gotchas" )"
printf '%s\n' "$out" | head -1 | grep -qE '^searched: memories\([0-9][0-9]*\) beads\([0-9][0-9]*\)' \
  || { echo "FAIL: coverage line absent or not first"; printf '%s\n' "$out"; exit 1; }

# ── 2. the count is what was SEARCHED. bd memories --json wraps the map in a
# "schema_version" envelope key; counting raw map entries reports memories(3)
# for a 2-memory store — a miscount inside the line that exists to prevent one.
printf '%s\n' "$out" | grep -q 'memories(2)' \
  || { echo "FAIL: memory count wrong (bd's schema_version envelope key counted?)"; printf '%s\n' "$out"; exit 1; }

# ── 3. a multi-word query returns its known-correct hit (bd itself returns zero
# here: it substring-matches the whole phrase)
printf '%s\n' "$out" | grep -q 'lesson-worktree-path-gotchas' \
  || { echo "FAIL: multi-word query returned no known hit"; printf '%s\n' "$out"; exit 1; }

# ── 4. unset salience renders visibly unset, never a plausible-looking number.
# SALIENCE_UNSET is -1; printing it as "s-1" reads like real data — the same
# fabrication the eo9z2.2 finding closed inside the ranker.
printf '%s\n' "$out" | grep -qE '^  lesson-worktree-path-gotchas +s[?] ' \
  || { echo "FAIL: unset salience not rendered as s?"; printf '%s\n' "$out"; exit 1; }
printf '%s\n' "$out" | grep -q 's-1' \
  && { echo "FAIL: SALIENCE_UNSET leaked to the display layer as s-1"; exit 1; }

# ── 5. a populated salience still renders its real value, with the hazard flag
haz="$( cd "$TMP" && bash "$SURFACE" "never chain open" )"
printf '%s\n' "$haz" | grep -qE '^  lesson-open-after-bd +s4 +HAZ ' \
  || { echo "FAIL: explicit salience/hazard not rendered"; printf '%s\n' "$haz"; exit 1; }

# ── 6. label filter is stage-1 recall for beads (ADR-0056), and it is disclosed
lab="$( cd "$TMP" && bash "$SURFACE" docs )"
printf '%s\n' "$lab" | head -1 | grep -qE '^searched: memories\([0-9][0-9]*\) beads\(1\) label=docs' \
  || { echo "FAIL: label filter absent or undisclosed"; printf '%s\n' "$lab"; exit 1; }

# ── 7. injection: metacharacter queries are one argument and execute nothing
# shellcheck disable=SC2016  # the un-expanded $(...) and backticks ARE the payload
for payload in 'x"; touch INJECTED; echo "' '$(touch PWNED)' '`touch BACKTICKED`'; do
  ( cd "$TMP" && bash "$SURFACE" "$payload" ) >/dev/null 2>&1 || true
done
for canary in INJECTED PWNED BACKTICKED; do
  [ -e "$TMP/$canary" ] && { echo "FAIL: query reached a shell ($canary created)"; exit 1; }
done

# ── 8. bd failing is reported, never rendered as an empty store
err="$( cd "$NODB" && bash "$SURFACE" worktree )"
printf '%s\n' "$err" | grep -q 'UNAVAILABLE' \
  || { echo "FAIL: bd error reported as an empty corpus"; printf '%s\n' "$err"; exit 1; }

# ── 9. python3 absent: visible notice, coverage line, keys only, clean exit.
# Bodies are withheld because redact() lives in rank.py — a floor with a bypass
# is not a floor (orient.sh:29-33 is the precedent for the visible notice).
mkdir -p "$TMP/nopy"
for b in bd bash grep head sed dirname; do
  p="$(command -v "$b" || true)"
  case "$p" in /*) ln -sf "$p" "$TMP/nopy/$b" ;; esac
done
set +e
deg="$( cd "$TMP" && PATH="$TMP/nopy" bash "$SURFACE" worktree )"
deg_rc=$?
set -e
[ "$deg_rc" -eq 0 ] || { echo "FAIL: degraded path exited $deg_rc, must be 0"; printf '%s\n' "$deg"; exit 1; }
printf '%s\n' "$deg" | grep -q "requires python3" \
  || { echo "FAIL: python3-absent degradation is silent"; printf '%s\n' "$deg"; exit 1; }
printf '%s\n' "$deg" | head -1 | grep -q '^searched:' \
  || { echo "FAIL: degraded path emits no coverage line"; printf '%s\n' "$deg"; exit 1; }
printf '%s\n' "$deg" | grep -q 'lesson-worktree-path-gotchas' \
  || { echo "FAIL: degraded path surfaced no matching key"; printf '%s\n' "$deg"; exit 1; }
printf '%s\n' "$deg" | grep -q '\.worktrees/name' \
  && { echo "FAIL: degraded path printed an unredacted body"; printf '%s\n' "$deg"; exit 1; }

# ── 10. no query is a usage error, not an empty search
set +e
( cd "$TMP" && bash "$SURFACE" >/dev/null 2>&1 )
usage_rc=$?
set -e
[ "$usage_rc" -eq 2 ] || { echo "FAIL: no-argument invocation exited $usage_rc, expected 2"; exit 1; }

echo "PASS: surface.sh — coverage line, counts, salience rendering, label filter, injection-inert, bd-error visible, degradation"
