#!/usr/bin/env bash
# selftest.sh — TDD harness for scripts/migrate-kv-to-beads.sh (bd-8o3j / ADR-0056).
# Builds a scratch bd DB (mktemp -d OUTSIDE the repo tree — NEVER the real,
# Dolt-synced store) with fabricated bsp.kb.* kv fixtures, then exercises the
# migration engine against every load-bearing property from task-3-brief.md:
#   (a) normal entry -> 1 deferred bead, correct type/labels/metadata
#   (b) idempotency: 2nd run creates 0 new beads, prints skip-exists per entry
#   (c) exact-key labelmap lookup (prefix-collision fixture: fixture-prefix is
#       a literal string-prefix of fixture-prefix-extra)
#   (d) metachar/newline summary round-trips into the bead description intact
#   (e) secret-bearing summary is skipped + flagged, never written
# Also confirms: deferred beads are hidden from `bd ready`, the created set is
# guard-valid (scripts/check-kb-labels.sh), kv is untouched (read-only), and
# the REAL repo's kb-bead set is unchanged before/after (read-only checks
# against the real store; no write ever targets it).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATE="$REPO_ROOT/scripts/migrate-kv-to-beads.sh"
GUARD="$REPO_ROOT/scripts/check-kb-labels.sh"
rc=0

pass() { echo "SELFTEST ok: $1"; }
fail() { echo "SELFTEST FAIL: $1"; rc=1; }

# --- snapshot the REAL store's kb-bead set before touching anything (read-only) ---
real_before=$(cd "$REPO_ROOT" && bd list --label kb --status all --limit 0 --json 2>/dev/null)

SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
MAP="$SB/labelmap.tsv"

if ! (cd "$SB" && bd init --non-interactive -p kbmig >/dev/null 2>&1); then
  fail "setup: bd init failed (rig broken, not a script bug)"; exit "$rc"
fi
if ! (cd "$SB" && bd config set types.custom "research,design" >/dev/null 2>&1); then
  fail "setup: bd config set types.custom failed"; exit "$rc"
fi

# --- fixtures ---------------------------------------------------------------
kv_set() { # kv_set <key> <type> <summary> <doc>
  local key="$1" type="$2" summary="$3" doc="$4" val
  val=$(jq -nc --arg t "$type" --arg s "$summary" --arg d "$doc" --arg c "2026-07-15" \
    '{type:$t, created:$c, salience:3, refs:(if $d=="" then [] else [$d] end), tags:[], summary:$s}')
  (cd "$SB" && bd kv set "$key" "$val" >/dev/null)
}

# (a) normal entry
kv_set "bsp.kb.decision.fixture-normal" "semantic:decision" \
  "fixture-normal: a plain one-line decision summary for migration testing." \
  "docs/decisions/ADR-9999-fixture.md"

# (c) exact-key prefix collision: fixture-prefix is a literal prefix of
# fixture-prefix-extra's key. A substring lookup (grep -F) would bleed both
# rows into whichever key is queried; an exact-key lookup must not.
kv_set "bsp.kb.decision.fixture-prefix" "semantic:decision" \
  "fixture-prefix: short decision A." "docs/decisions/ADR-A.md"
kv_set "bsp.kb.decision.fixture-prefix-extra" "semantic:decision" \
  "fixture-prefix-extra: short decision B, a different key that has A's key as a literal string prefix." \
  "docs/decisions/ADR-B.md"

# (d) metachars + embedded newline
# shellcheck disable=SC2016  # $VAR and `cmd` are literal fixture text, not expansions
METACHAR_SUMMARY='Line one with $VAR and `cmd` and "double" and '"'"'single'"'"' quotes; pipe | amp & percent %.
Line two after a literal newline.'
kv_set "bsp.kb.decision.fixture-metachars" "semantic:decision" "$METACHAR_SUMMARY" "docs/decisions/ADR-META.md"

# (e) fake secret (GitHub PAT shape: ghp_ + 36 chars)
kv_set "bsp.kb.decision.fixture-secret" "semantic:decision" \
  "fixture-secret: leaked token $(printf %s ghp)_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 must never be written to a bead." \
  "docs/decisions/ADR-SECRET.md"

{
  printf 'bsp.kb.decision.fixture-normal\ttesting-guards,release\n'
  printf 'bsp.kb.decision.fixture-prefix\thooks\n'
  printf 'bsp.kb.decision.fixture-prefix-extra\tmemory,docs\n'
  printf 'bsp.kb.decision.fixture-metachars\tpositioning\n'
  printf 'bsp.kb.decision.fixture-secret\thooks\n'
} >"$MAP"

get_bead() { # get_bead <kv_key> <json>
  jq -c --arg k "$1" '.[] | select(.metadata.kv_key==$k)' <<<"$2"
}

# --- run 1 -------------------------------------------------------------------
(cd "$SB" && bash "$MIGRATE" decision "$MAP" >"$SB/run1.out" 2>"$SB/run1.err")
rc1=$?
err1=$(cat "$SB/run1.err")

# shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
[ "$rc1" -eq 0 ] && pass "run 1 exits 0" || fail "run 1 exited $rc1 (stderr: $err1)"

after1=$(cd "$SB" && bd list --label kb --status all --limit 0 --json)

# (a) normal entry
normal=$(get_bead "bsp.kb.decision.fixture-normal" "$after1")
if [ -n "$normal" ]; then
  # shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
  [ "$(jq -r '.issue_type' <<<"$normal")" = "decision" ] && pass "(a) issue_type=decision" \
    || fail "(a) wrong issue_type: $(jq -r '.issue_type' <<<"$normal")"
  # shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
  [ "$(jq -r '.status' <<<"$normal")" = "deferred" ] && pass "(a) status=deferred" \
    || fail "(a) wrong status: $(jq -r '.status' <<<"$normal")"
  nlabels=$(jq -r '.labels | sort | join(",")' <<<"$normal")
  # shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
  [ "$nlabels" = "kb,release,testing-guards" ] && pass "(a) labels=$nlabels" \
    || fail "(a) wrong labels: $nlabels"
  # shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
  [ "$(jq -r '.metadata.doc' <<<"$normal")" = "docs/decisions/ADR-9999-fixture.md" ] && pass "(a) metadata.doc correct" \
    || fail "(a) wrong metadata.doc: $(jq -r '.metadata.doc' <<<"$normal")"
else
  fail "(a) no bead created for fixture-normal"
fi

# (c) exact-key labelmap lookup
p1=$(get_bead "bsp.kb.decision.fixture-prefix" "$after1")
p2=$(get_bead "bsp.kb.decision.fixture-prefix-extra" "$after1")
if [ -n "$p1" ] && [ -n "$p2" ]; then
  l1=$(jq -r '.labels | sort | join(",")' <<<"$p1")
  l2=$(jq -r '.labels | sort | join(",")' <<<"$p2")
  # shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
  [ "$l1" = "hooks,kb" ] && pass "(c) exact-key: fixture-prefix labels=$l1" \
    || fail "(c) fixture-prefix got wrong labels (substring bleed?): $l1"
  # shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
  [ "$l2" = "docs,kb,memory" ] && pass "(c) exact-key: fixture-prefix-extra labels=$l2" \
    || fail "(c) fixture-prefix-extra got wrong labels (substring bleed?): $l2"
else
  fail "(c) prefix-collision beads missing (p1 present=$([ -n "$p1" ] && echo y || echo n), p2 present=$([ -n "$p2" ] && echo y || echo n))"
fi

# (d) metachar/newline round-trip
mc=$(get_bead "bsp.kb.decision.fixture-metachars" "$after1")
if [ -n "$mc" ]; then
  desc=$(jq -r '.description' <<<"$mc")
  if [ "$desc" = "$METACHAR_SUMMARY" ]; then
    pass "(d) metachar/newline summary round-trips intact"
  else
    fail "(d) description mismatch (metachar round-trip broken). got: $desc"
  fi
else
  fail "(d) no bead created for fixture-metachars"
fi

# (e) secret scan: skip + flag, never write
sec=$(get_bead "bsp.kb.decision.fixture-secret" "$after1")
if [ -z "$sec" ]; then
  pass "(e) secret-bearing entry NOT written as a bead"
else
  fail "(e) secret-bearing entry WAS written as a bead: $(jq -r '.id' <<<"$sec")"
fi
if grep -q 'FLAG: bsp.kb.decision.fixture-secret' <<<"$err1"; then
  pass "(e) secret flagged on stderr"
else
  fail "(e) no FLAG printed for secret entry; stderr was: $err1"
fi

# --- run 2: idempotency -------------------------------------------------------
out2=$(cd "$SB" && bash "$MIGRATE" decision "$MAP" 2>"$SB/run2.err")
after2=$(cd "$SB" && bd list --label kb --status all --limit 0 --json)
count1=$(jq 'length' <<<"$after1")
count2=$(jq 'length' <<<"$after2")
# shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
[ "$count1" = "$count2" ] && pass "(b) idempotency: bead count stable ($count1 -> $count2)" \
  || fail "(b) idempotency: bead count changed ($count1 -> $count2)"
# shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
grep -q 'created=0 ' <<<"$out2" && pass "(b) 2nd run summary reports created=0" \
  || fail "(b) 2nd run summary did not report created=0: $out2"
for k in fixture-normal fixture-prefix fixture-prefix-extra fixture-metachars; do
  if grep -q "skip (exists): bsp.kb.decision.$k ->" <<<"$out2"; then
    pass "(b) 2nd run: skip-exists printed for $k"
  else
    fail "(b) 2nd run: no skip-exists line for $k (out2: $out2)"
  fi
done

# --- deferred beads hidden from bd ready --------------------------------------
ready_ids=$(cd "$SB" && bd ready --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)
created_ids=$(jq -r '.[].id' <<<"$after1")
leaked=0
for id in $created_ids; do
  grep -qxF "$id" <<<"$ready_ids" && leaked=1
done
# shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
[ "$leaked" -eq 0 ] && pass "created beads are hidden from bd ready" || fail "a migrated bead leaked into bd ready"

# --- guard-valid ---------------------------------------------------------------
if (cd "$SB" && bash "$GUARD" >/dev/null 2>&1); then
  pass "check-kb-labels.sh passes against the scratch DB"
else
  fail "check-kb-labels.sh FAILED against the scratch DB"
fi

# --- kv is untouched (read-only) ------------------------------------------------
kv_after=$(cd "$SB" && bd kv get "bsp.kb.decision.fixture-normal" 2>/dev/null)
# shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
[ -n "$kv_after" ] && pass "kv entry for fixture-normal still present (script is read-only on kv)" \
  || fail "kv entry for fixture-normal disappeared — script must not touch kv"

# --- real store unchanged --------------------------------------------------------
real_after=$(cd "$REPO_ROOT" && bd list --label kb --status all --limit 0 --json 2>/dev/null)
# shellcheck disable=SC2015  # pass/fail always succeed, so A && B || C can't misfire
[ "$real_before" = "$real_after" ] && pass "REAL store kb-bead set unchanged before/after" \
  || fail "REAL store kb-bead set CHANGED — investigate immediately"

exit "$rc"
