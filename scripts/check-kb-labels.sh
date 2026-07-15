#!/usr/bin/env bash
# check-kb-labels.sh — every deferred knowledge-bead (label 'kb') obeys the
# closed-vocabulary contract (ADR-0056): (1) every label is in
# kb-label-vocab.txt, (2) >=1 topic label beyond 'kb', (3) <=3 topic labels.
# Vocab path resolves from $0 (this script's own dir) so a caller can run this
# guard with CWD pointed at a scratch bd DB (selftest isolation) while the
# vocab file still resolves to the real repo copy.
set -euo pipefail
VOCAB="$(dirname "$0")/kb-label-vocab.txt"
fail=0
# Query up front so we can distinguish a genuine 'bd' failure (corrupt/locked/
# unavailable DB) from a genuinely empty store — swallowing stderr into an
# empty read loop would print a false "OK". --limit 0 = unlimited: the default
# --limit 50 would silently skip violations in the 51st+ knowledge-bead, and
# this store is designed to hold ~129.
if ! rows=$(bd list --label kb --status all --limit 0 --json); then
  echo "kb-labels: ERROR — 'bd list' query failed; cannot verify knowledge-bead labels" >&2
  exit 2
fi
# CRITICAL: process substitution (NOT a pipe) so 'fail' lives in THIS shell and exit propagates.
# A `... | while read ...` pipe would run the loop body in a subshell, losing fail=1.
while read -r row; do
  id=$(jq -r '.id' <<<"$row")
  mapfile -t labels < <(jq -r '.labels[]?' <<<"$row")
  topic=0
  for l in "${labels[@]}"; do
    grep -qxF "$l" "$VOCAB" || { echo "FAIL $id: label '$l' not in vocab"; fail=1; }
    [ "$l" != "kb" ] && topic=$((topic+1))
  done
  [ "$topic" -ge 1 ] || { echo "FAIL $id: no topic label beyond 'kb'"; fail=1; }
  [ "$topic" -le 3 ] || { echo "FAIL $id: >3 topic labels"; fail=1; }
done < <(jq -c '.[] | {id, labels}' <<<"$rows")
[ "$fail" -eq 0 ] && echo "kb-labels: OK (all knowledge-beads obey the vocab contract)"
exit "$fail"
