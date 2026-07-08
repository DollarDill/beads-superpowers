#!/usr/bin/env bash
# tests/hooks/test-kv-knowledge-base.sh — the bsp.kb. retrieval contract
set -euo pipefail
# Visible SKIP when jq is absent (matches the node/shellcheck SKIP convention) —
# run-hook-tests.sh treats a non-zero exit as FAIL, so guard rather than fail.
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Fixture mimics `bd kv list --json`: {key: value} where value is a compact JSON STRING
# (double-encoded, exactly as bd returns it).
cat > "$TMP/kv-list.json" <<'FIX'
{
  "bsp.kb.research.mem-overcrowding": "{\"type\":\"semantic:research\",\"created\":\"2026-07-08\",\"salience\":3,\"refs\":[\".internal/research/x.md\"],\"tags\":[\"memory\",\"beads\"],\"summary\":\"beads memories are kv rows\"}",
  "bsp.kb.decision.adr-0042": "{\"type\":\"semantic:decision\",\"created\":\"2026-07-07\",\"salience\":4,\"refs\":[\"ADR-0042\"],\"tags\":[\"composer\"],\"summary\":\"composer salience contract\"}",
  "memory.some-lesson": "@type=semantic:lesson @created=2026-07-01 @salience=4 a real memory"
}
FIX

# 1. tag-filter retrieval (the documented structured one-liner) finds the beads-tagged entry
hits=$(jq -r 'to_entries
  | map(select(.key|startswith("bsp.kb.")))
  | map(select(.value|fromjson|.tags|index("beads")))
  | .[].key' "$TMP/kv-list.json")
[ "$hits" = "bsp.kb.research.mem-overcrowding" ] \
  || { echo "FAIL: tag-filter retrieval wrong: [$hits]"; exit 1; }

# 2. every bsp.kb. value must parse as JSON (compact/escaped contract)
if ! jq -e 'to_entries | map(select(.key|startswith("bsp.kb."))) | all(.value|fromjson|type=="object")' \
     "$TMP/kv-list.json" >/dev/null; then
  echo "FAIL: a bsp.kb. value is not valid JSON"; exit 1
fi

# 3. skim retrieval — the documented one-liner (`grep -i '^bsp.kb' | grep -i <keyword>`) against
#    `bd kv list` TEXT output (one `key = value` per line). Positive + negative controls together
#    prove the pattern is live AND that a multi-line value is not silently retrievable.
cat > "$TMP/kv-list.txt" <<'FIX'
bsp.kb.research.mem-overcrowding = {"type":"semantic:research","created":"2026-07-08","salience":3,"refs":[".internal/research/x.md"],"tags":["memory","beads"],"summary":"beads memories are kv rows"}
bsp.kb.research.bad = {
  "type": "x"
}
memory.some-lesson = @type=semantic:lesson @created=2026-07-01 @salience=4 a real memory
FIX

# 3a. POSITIVE control: the documented skim one-liner finds the compact, well-formed beads-tagged
#     entry and nothing else. Without this, 3b below could pass on a dead pattern that never matches.
skim=$(grep -i '^bsp.kb' "$TMP/kv-list.txt" | grep -i beads)
printf '%s\n' "$skim" | grep -q '^bsp.kb.research.mem-overcrowding = .*}$' \
  || { echo "FAIL: skim one-liner did not return the compact entry: [$skim]"; exit 1; }
[ "$(printf '%s\n' "$skim" | grep -c '^bsp.kb')" -eq 1 ] \
  || { echo "FAIL: skim one-liner matched more than the one entry: [$skim]"; exit 1; }

# 3b. NEGATIVE control (single-line contract): the multi-line `bad` value must NOT present as a
#     complete `key = ...}` line — a pretty-printed value is unreachable by the skim one-liner.
lines=$(grep -c '^bsp.kb.research.bad = .*}$' "$TMP/kv-list.txt" || true)
[ "$lines" -eq 0 ] || { echo "FAIL: multi-line value should NOT be single-grep-line"; exit 1; }

echo "PASS: bsp.kb. retrieval contract"
