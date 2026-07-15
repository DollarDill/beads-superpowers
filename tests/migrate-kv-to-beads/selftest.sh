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
# Review-round-2 additions:
#   (f) single-case token (lowercase Slack xoxb-...) is flagged + skipped
#   (g) control (git SHA + kebab slug + prose) is MIGRATED, NOT false-flagged
#   (h) no-label-mapping entry is skipped (no bead), surfaced on stderr
#   (i) malformed TARGET-subtype value -> WARN by name, no bead, run still exits 0
#   (j) malformed OTHER-subtype value does NOT abort/block the target migration
#   (k) secret in the doc/refs[0] field (not just summary) is flagged + skipped
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

# NOTE: the fake tokens in the (e)/(f)/(k) fixtures below are assembled at runtime
# via $(printf %s <prefix>) instead of being written as literals — otherwise this
# secret-scan test's own fixtures would trip GitHub secret-scanning push protection.
# The reassembled runtime value is a normal token the migration's scanner must still
# catch, so the fixtures still work. Do NOT re-inline them as plain literals.
# (e) fake secret (GitHub PAT shape: ghp_ + 36 chars)
kv_set "bsp.kb.decision.fixture-secret" "semantic:decision" \
  "fixture-secret: leaked token $(printf %s ghp)_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 must never be written to a bead." \
  "docs/decisions/ADR-SECRET.md"

# (f) single-case (all-lowercase) Slack bot token — the exact class the old
# AND-of-three-cases entropy check missed. Must be flagged + skipped.
kv_set "bsp.kb.decision.fixture-slack" "semantic:decision" \
  "fixture-slack: leaked bot token $(printf %s xoxb)-1234567890-abcdefghijklmnopqrstuvwx must never land in a bead." \
  "docs/decisions/ADR-SLACK.md"

# (g) control: legit content that MUST NOT be false-flagged — a 40-char git SHA
# (pure hex), a kebab-case slug (>=32, has hyphens), and normal prose. Proves
# the broadened scan doesn't block real entries.
kv_set "bsp.kb.decision.fixture-control" "semantic:decision" \
  "fixture-control: see commit da39a3ee5e6b4b0d3255bfef95601890afd80709 and decision-decline-loop-engineering-2026-06-27 in normal prose." \
  "docs/decisions/ADR-CONTROL.md"

# (h) present in the target subtype but ABSENT from the labelmap -> skip (no bead).
kv_set "bsp.kb.decision.fixture-nolabel" "semantic:decision" \
  "fixture-nolabel: a decision with no reviewed label mapping." "docs/decisions/ADR-NOLABEL.md"

# (k) clean summary but a secret in refs[0] (-> metadata.doc). Must be flagged.
kv_set "bsp.kb.decision.fixture-doc-secret" "semantic:decision" \
  "fixture-doc-secret: a perfectly clean summary with the secret hidden in its doc ref." \
  "https://example.com/x?token=$(printf %s ghp)_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

# (i) malformed TARGET-subtype value (non-JSON) — must be surfaced by name, not abort.
(cd "$SB" && bd kv set "bsp.kb.decision.fixture-malformed-decision" 'this is NOT json {oops' >/dev/null)
# (j) malformed OTHER-subtype value — must not block the decision run.
(cd "$SB" && bd kv set "bsp.kb.design.fixture-malformed-design" 'also }not{ json' >/dev/null)

# labelmap: fixture-slack and fixture-doc-secret ARE given valid mappings on
# purpose — so the ONLY thing preventing their bead creation is the secret scan.
# If the scan missed, a bead would be created and (f)/(k) would fail loudly.
# fixture-nolabel is deliberately omitted. Malformed entries never reach lookup.
{
  printf 'bsp.kb.decision.fixture-normal\ttesting-guards,release\n'
  printf 'bsp.kb.decision.fixture-prefix\thooks\n'
  printf 'bsp.kb.decision.fixture-prefix-extra\tmemory,docs\n'
  printf 'bsp.kb.decision.fixture-metachars\tpositioning\n'
  printf 'bsp.kb.decision.fixture-secret\thooks\n'
  printf 'bsp.kb.decision.fixture-slack\thooks\n'
  printf 'bsp.kb.decision.fixture-control\tadr-process\n'
  printf 'bsp.kb.decision.fixture-doc-secret\thooks\n'
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

# (f) single-case Slack token: flagged + not written
if [ -z "$(get_bead "bsp.kb.decision.fixture-slack" "$after1")" ]; then
  pass "(f) single-case Slack token NOT written as a bead"
else
  fail "(f) single-case Slack token WAS written (entropy gap not closed)"
fi
if grep -q 'FLAG: bsp.kb.decision.fixture-slack' <<<"$err1"; then
  pass "(f) single-case Slack token flagged on stderr"
else
  fail "(f) no FLAG for single-case Slack token; stderr was: $err1"
fi

# (g) control: git SHA + kebab slug + prose -> MIGRATED, not false-flagged
ctrl=$(get_bead "bsp.kb.decision.fixture-control" "$after1")
if [ -n "$ctrl" ]; then
  pass "(g) control (git SHA + kebab slug + prose) migrated, NOT false-flagged"
else
  fail "(g) control entry was FALSE-FLAGGED/skipped — legit content blocked"
fi
if grep -q 'FLAG: bsp.kb.decision.fixture-control' <<<"$err1"; then
  fail "(g) control entry was flagged as a secret (false positive)"
else
  pass "(g) control entry not flagged (no false positive)"
fi

# (h) no-label-mapping: no bead + surfaced on stderr
if [ -z "$(get_bead "bsp.kb.decision.fixture-nolabel" "$after1")" ]; then
  pass "(h) no-label-mapping entry not written as a bead"
else
  fail "(h) no-label-mapping entry created a (guard-invalid) bead"
fi
if grep -q 'skip (no label mapping): bsp.kb.decision.fixture-nolabel' <<<"$err1"; then
  pass "(h) no-label-mapping surfaced on stderr"
else
  fail "(h) no-label-mapping not surfaced; stderr was: $err1"
fi

# (i) malformed TARGET-subtype: WARN by name + no bead (never a silent drop)
if grep -q 'WARN: unparseable kv value for bsp.kb.decision.fixture-malformed-decision — skipped' <<<"$err1"; then
  pass "(i) malformed target-subtype value surfaced by name (WARN)"
else
  fail "(i) malformed target-subtype value not surfaced by name; stderr was: $err1"
fi
if [ -z "$(get_bead "bsp.kb.decision.fixture-malformed-decision" "$after1")" ]; then
  pass "(i) malformed target-subtype value produced no bead"
else
  fail "(i) malformed target-subtype value produced a bead"
fi

# (j) malformed OTHER-subtype does not abort/block: run 1 exited 0 (asserted
# above) AND the normal target entries still migrated. Also surfaced by name.
if [ -n "$normal" ] && [ "$rc1" -eq 0 ]; then
  pass "(j) malformed other-subtype value did NOT abort the target migration"
else
  fail "(j) malformed other-subtype value blocked/aborted the target migration"
fi
if grep -q 'WARN: unparseable kv value for bsp.kb.design.fixture-malformed-design — skipped' <<<"$err1"; then
  pass "(j) malformed other-subtype value surfaced by name (WARN)"
else
  fail "(j) malformed other-subtype value not surfaced by name; stderr was: $err1"
fi

# (k) secret in the doc/refs[0] field: flagged + not written
if [ -z "$(get_bead "bsp.kb.decision.fixture-doc-secret" "$after1")" ]; then
  pass "(k) entry with a secret in its doc ref NOT written as a bead"
else
  fail "(k) entry with a secret in its doc ref WAS written (doc field not scanned)"
fi
if grep -q 'FLAG: bsp.kb.decision.fixture-doc-secret' <<<"$err1"; then
  pass "(k) doc-field secret flagged on stderr"
else
  fail "(k) no FLAG for doc-field secret; stderr was: $err1"
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
for k in fixture-normal fixture-prefix fixture-prefix-extra fixture-metachars fixture-control; do
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
