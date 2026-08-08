#!/usr/bin/env bash
# tests/skills/test-kr-corpus-shapes.sh — run: bash tests/skills/test-kr-corpus-shapes.sh
#
# Adversarial corpus shapes from Plan C spec §6, in scratch stores only.
# NO FOREIGN DATA is read or written by this file.
#
# Grounding: rank.py's Corpus indexes the stripped BODY only and its tokenizer is
# [a-z0-9]+, so a CJK or emoji body tokenizes to NOTHING; and `bd memories`
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
# SHAPE 1 (Task 5): CJK / emoji body tokenizes to nothing under [a-z0-9]+
# ═══════════════════════════════════════════════════════════════════════════

# ── 1. a CJK-only body must not crash the ranker.
# The assertion is SURVIVAL plus DISCLOSURE, not retrievability: if the [a-z0-9]+
# tokenizer yields nothing the entry is simply unfindable, which is a defect to
# FILE, not to fix here. What is unacceptable is a traceback or a non-zero exit.
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

# PIN THE OBSERVED BEHAVIOUR (amended 2026-08-08 by the M1 audit, beads-superpowers-8tyco).
# The AC says the outcome is "recorded whichever way it goes" — record it as an ASSERTION,
# not a comment, so a future tokenizer change that makes CJK indexable turns this red and
# forces the record to be updated. `工作树 隔离` is itself CJK, so the QUERY tokenizes to
# nothing under [a-z0-9]+ and the result set is empty by construction.
#
# REPAIRED (fix round 1, beads-superpowers-gkp61): the original form (`sed '1,2d'` then grep
# for an indented hit-shaped line) assumed line 2 is always the fixed "(no hits …)" notice.
# It isn't on a hit — a single-hit result occupies the position the notice occupies today,
# so `sed '1,2d'` deletes the ONE line this assertion exists to catch, and the grep after it
# finds nothing: a blind pass on exactly the regression being pinned (proven: it only fires
# at 2+ hits, never at 1). Replaced with a positive assertion on the documented zero-hit
# marker text (verbatim from rank.py and surface.sh's degraded path) — no positional line
# arithmetic, so it can't be defeated by where in the output a hit lands.
if ! grep -q '(no hits' <<<"$cjk"; then
  echo "NOTE: CJK query now returns hits — tokenizer behaviour changed, update the shape record"; exit 1
fi

# SECRETS FLOOR UNDER AN ADVERSARIAL SHAPE (stress-test B7), REPAIRED.
#
# WHY THE ORIGINAL FORM COULD NOT FAIL: the plan shipped `grep -qF "$FAKE_SECRET" <<<"$cjk"`
# against the CJK query above, which returns ZERO hits. A negative grep over empty output
# passes no matter what redaction does — the eo9z2.8 assertion class this repo keeps
# rediscovering. Measured by the M1 audit: query `工作树 隔离` -> no hit lines; control
# query `ok` -> the entry, with `[REDACTED]`.
#
# The repair keeps the CJK shape AND makes the assertion live: a second fixture whose body
# is CJK *plus one indexable ASCII anchor*, queried by that anchor. The entry is therefore
# retrievable, so the redaction assertion has something to be wrong about.
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
# Query the ANCHOR here too — the CJK query would make this vacuous for the same reason.
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

echo "PASS: shape 1 — CJK/emoji survival (12 assertions)"

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
