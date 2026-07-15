#!/usr/bin/env bash
# migrate-kv-to-beads.sh — idempotent, two-phase kv -> deferred-bead migration
# engine (ADR-0056). Reads bsp.kb.<subtype>.* kv entries (bd kv list --json)
# and creates deferred knowledge-beads: issue_type=<subtype>,
# labels="kb,<mapped topics>", status=deferred (--defer 2099-01-01),
# metadata.kv_key + metadata.doc, description = the kv .summary (via stdin,
# --body-file -). Read-only on kv — retiring/tombstoning migrated kv entries
# is a separate, verified step (not this script).
#
# Usage: migrate-kv-to-beads.sh <subtype: decision|research|design> <labelmap.tsv>
#   labelmap.tsv: <kv_key>\t<comma-separated topic labels>   (human-reviewed)
#
# Prerequisite (NOT done by this script — a one-time runtime step against the
# target DB): custom subtypes need `bd config set types.custom "research,design"`
# ('decision' is a built-in bd type and needs no config).
set -euo pipefail

usage() { echo "Usage: $0 <subtype: decision|research|design> <labelmap.tsv>" >&2; exit 1; }

[ $# -eq 2 ] || usage
SUB="$1"
MAP="$2"
DEFER="2099-01-01"

case "$SUB" in
  decision | research | design) ;;
  *) echo "migrate-kv-to-beads: unknown subtype '$SUB' (expected decision|research|design)" >&2; exit 1 ;;
esac
[ -f "$MAP" ] || { echo "migrate-kv-to-beads: labelmap file not found: $MAP" >&2; exit 1; }

# Secret/PII scan (mandatory): flag-and-skip, never write a hit into a bead
# description OR metadata.doc — both are queryable and ride Dolt history (which
# outlives 'bd forget'), so a secret written once is effectively permanent.
looks_like_secret() {
  local text="$1" tok
  # 1) Well-known / labeled token shapes — matched against the WHOLE text so
  #    surrounding quotes or punctuation can't defeat detection. Provider
  #    prefixes are case-sensitive as issued.
  grep -Eq 'gh[pousr]_[A-Za-z0-9]{36,}' <<<"$text" && return 0                # GitHub PAT/OAuth/App/refresh
  grep -Eq 'xox[baprs]-[A-Za-z0-9-]{10,}' <<<"$text" && return 0              # Slack (lowercase, no case-mix)
  grep -Eq '(sk|pk|rk)_(live|test)_[A-Za-z0-9]{16,}' <<<"$text" && return 0   # Stripe
  grep -Eq 'sk-[A-Za-z0-9]{20,}' <<<"$text" && return 0                       # OpenAI
  grep -Eq 'AIza[A-Za-z0-9_-]{20,}' <<<"$text" && return 0                    # Google API key
  grep -Eq 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' <<<"$text" && return 0 # JWT (header.payload)
  grep -Eq 'Bearer [A-Za-z0-9._-]{20,}' <<<"$text" && return 0                # Bearer token
  grep -Eq 'AKIA[0-9A-Z]{16}' <<<"$text" && return 0                          # AWS access key id
  grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' <<<"$text" && return 0     # PEM private key
  grep -Eiq '(secret|api[_-]?key|password)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9/+_.-]{8,}' <<<"$text" && return 0
  # 2) Generic high-entropy fallback (per whitespace-delimited token >=32 chars).
  #    Flag a token that is ENTIRELY base64 alphabet ([A-Za-z0-9+/] + optional
  #    '=' padding) AND contains a digit AND is NOT pure hex. This catches
  #    base32/base62/base64 random-secret encodings of ANY case (padded or not,
  #    single-case included — the gap the reviewer flagged) while NOT
  #    false-flagging the shapes that legitimately fill these summaries: git
  #    SHAs / MD5 / SHA-256 (pure hex, excluded), file paths & URLs (carry
  #    '.'/':'/'-'/'_' so they aren't base64-alphabet-only), and lowercase
  #    slash-separated word lists like 'a/b/c/d' (no digit). Calibrated to ZERO
  #    false positives against the real 129-entry store.
  while IFS= read -r tok; do
    [ "${#tok}" -ge 32 ] || continue
    [[ $tok =~ ^[A-Za-z0-9+/]+={0,2}$ ]] || continue   # entirely base64 alphabet
    [[ $tok =~ [0-9] ]] || continue                    # has a digit (excludes word-lists)
    [[ $tok =~ ^[0-9a-fA-F]+={0,2}$ ]] && continue      # pure hex -> git SHA/MD5/SHA-256, skip
    return 0
  done < <(grep -oE '[^[:space:]]+' <<<"$text")
  return 1
}

# Exact-key labelmap lookup. NOT grep -F: a substring match would bleed labels
# from a key that is a literal prefix of a longer key (e.g. bsp.kb.design.foo
# matching inside bsp.kb.design.foobar).
lookup_labels() {
  awk -F'\t' -v k="$1" '$1==k{print $2; exit}' "$MAP"
}

# Idempotency existence-check: fetch the existing knowledge-bead set ONCE
# up front (not per-entry — kv keys are unique within one run, so one query
# suffices). --limit 0 = unlimited: the bd list default of 50 would miss
# beads past the 50th on a re-run and create duplicates. Scoped to --label kb
# so we scan only knowledge-beads, not the whole store. Query up front (not
# inline in a pipe) so a genuine 'bd' failure is distinguishable from a
# genuinely empty store.
if ! existing_json=$(bd list --label kb --status all --limit 0 --json); then
  echo "migrate-kv-to-beads: ERROR — 'bd list' (idempotency check) failed" >&2
  exit 2
fi

if ! kv_json=$(bd kv list --json); then
  echo "migrate-kv-to-beads: ERROR — 'bd kv list' failed" >&2
  exit 2
fi

# Classify every bsp.kb.* entry with a PER-ENTRY defensive parse (try/catch), so
# one malformed .value cannot abort the whole run. The pre-fix single filter ran
# `.value|fromjson` on every bsp.kb.* entry BEFORE the subtype test, so a bad
# value under ANY subtype aborted every subtype's migration with a raw jq dump.
# Here each entry becomes exactly one TSV record: "target\t<key>" (parses to an
# object whose .type == semantic:<SUB>) or "malformed\t<key>" (unparseable, or
# not a JSON object). Non-object / other-subtype parseable entries emit nothing.
classified=$(jq -r --arg s "semantic:$SUB" '
    to_entries[]
    | select(.key | startswith("bsp.kb."))
    | . as $e
    | (try ($e.value | fromjson) catch null) as $p
    | if ($p | type) != "object" then "malformed\t\($e.key)"
      elif ($p.type == $s)       then "target\t\($e.key)"
      else empty end
  ' <<<"$kv_json")

malformed=0
keys=""
while IFS=$'\t' read -r status key; do
  [ -n "$status" ] || continue
  if [ "$status" = "malformed" ]; then
    # Surface by name (never a silent drop, never a raw jq dump). A malformed
    # entry keeps its expected-count auditable across the per-subtype runs.
    echo "WARN: unparseable kv value for $key — skipped" >&2
    malformed=$((malformed + 1))
  else
    keys+="$key"$'\n'
  fi
done <<<"$classified"

created=0
skipped_exists=0
skipped_secret=0
skipped_nolabel=0

while IFS= read -r key; do
  [ -n "$key" ] || continue

  existing_id=$(jq -r --arg k "$key" '.[] | select(.metadata.kv_key==$k) | .id' <<<"$existing_json" | head -1)
  if [ -n "$existing_id" ]; then
    echo "skip (exists): $key -> $existing_id"
    skipped_exists=$((skipped_exists + 1))
    continue
  fi

  val=$(bd kv get "$key")
  summary=$(jq -r '.summary' <<<"$val")
  doc=$(jq -r '.refs[0] // ""' <<<"$val")

  # Scan BOTH the summary (-> description) and doc (-> metadata.doc): both land
  # in the bead and ride Dolt history.
  if looks_like_secret "$summary" || looks_like_secret "$doc"; then
    echo "FLAG: $key — possible secret, skipped for human review" >&2
    skipped_secret=$((skipped_secret + 1))
    continue
  fi

  labels=$(lookup_labels "$key")
  if [ -z "$labels" ]; then
    echo "skip (no label mapping): $key" >&2
    skipped_nolabel=$((skipped_nolabel + 1))
    continue
  fi

  title=$(printf '%s\n' "$summary" | head -1 | cut -c1-100)
  [ -n "$title" ] || title="$key"

  metadata=$(jq -nc --arg k "$key" --arg d "$doc" '{kv_key:$k, doc:$d}')

  new_id=$(printf '%s' "$summary" | bd create --title "$title" -t "$SUB" -l "kb,$labels" \
    --defer "$DEFER" --metadata "$metadata" --body-file - --silent)
  echo "created: $key -> $new_id"
  created=$((created + 1))
done <<<"$keys"

echo "migrate-kv-to-beads: subtype=$SUB created=$created skip-exists=$skipped_exists skip-secret=$skipped_secret skip-no-label=$skipped_nolabel malformed=$malformed"
