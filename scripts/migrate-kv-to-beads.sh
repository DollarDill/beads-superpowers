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
# description. Bead descriptions are queryable and ride Dolt history (outlives
# 'bd forget') — a secret written once is effectively permanent.
looks_like_secret() {
  local text="$1" tok
  grep -Eiq 'gh[pousr]_[A-Za-z0-9]{36,}' <<<"$text" && return 0
  grep -Eq 'AKIA[0-9A-Z]{16}' <<<"$text" && return 0
  grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' <<<"$text" && return 0
  grep -Eiq '(secret|api[_-]?key|password)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9/+_.-]{8,}' <<<"$text" && return 0
  # Heuristic for unlabeled high-entropy credentials: a whitespace-delimited
  # token >=32 chars mixing lower+upper+digit reads as a random secret, not a
  # kebab-case slug, hex hash, or URL (those stay single-case).
  while IFS= read -r tok; do
    [ "${#tok}" -ge 32 ] || continue
    if grep -q '[a-z]' <<<"$tok" && grep -q '[A-Z]' <<<"$tok" && grep -q '[0-9]' <<<"$tok"; then
      return 0
    fi
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
keys=$(jq -r --arg s "semantic:$SUB" '
    to_entries[]
    | select(.key | startswith("bsp.kb."))
    | select((.value | fromjson | .type) == $s)
    | .key
  ' <<<"$kv_json")

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

  if looks_like_secret "$summary"; then
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

echo "migrate-kv-to-beads: subtype=$SUB created=$created skip-exists=$skipped_exists skip-secret=$skipped_secret skip-no-label=$skipped_nolabel"
