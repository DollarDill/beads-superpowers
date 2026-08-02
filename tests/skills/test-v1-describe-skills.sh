#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GEN="$REPO/tests/skills/helpers/v1-describe-skills.sh"
[ -x "$GEN" ] || { echo "FAIL: $GEN missing or not executable"; exit 1; }

out="$(cd "$REPO" && bash "$GEN")"

# 1. knowledge-retrieval is present (the skill under eval must be reachable by the router)
grep -q '^- knowledge-retrieval: ' <<<"$out" \
  || { echo "FAIL: knowledge-retrieval absent from description list"; exit 1; }

# 2. session-handoff is absent (disable-model-invocation: true -> router cannot see it)
grep -q '^- session-handoff: ' <<<"$out" \
  && { echo "FAIL: user-invoked session-handoff leaked into the model-invoked list"; exit 1; }

# 3. every emitted line carries a non-empty description
while IFS= read -r line; do
  [[ "$line" =~ ^-\ [a-z0-9-]+:\ .+$ ]] \
    || { echo "FAIL: malformed or description-less line: $line"; exit 1; }
done <<<"$out"

# 4. the generator hardcodes no skill count
grep -qE '\b(2[0-9]|1[0-9])\b' "$GEN" \
  && { echo "FAIL: generator contains a hardcoded count"; exit 1; }

echo "PASS: v1-describe-skills ($(grep -c '' <<<"$out") model-invoked skills)"
