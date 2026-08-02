#!/usr/bin/env bash
# Emit the model-invoked skill description list for V1 trigger-eval probes.
# DERIVED, never hardcoded: a stale count silently weakens the probe, and
# scripts/check-skill-count.sh forbids hardcoded counts repo-wide.
#
# Lives under helpers/ because scripts/run-contracts.sh globs tests/skills/*.sh
# and runs each as a contract test. This is a generator, not a test; globbed, it
# would report PASS while asserting nothing.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
[ -d "$REPO/skills" ] || { echo "ERROR: $REPO/skills missing" >&2; exit 1; }

for d in "$REPO"/skills/*/; do
  f="$d/SKILL.md"
  [ -f "$f" ] || continue
  # Frontmatter only: the closing --- ends the block. A body mention of
  # disable-model-invocation must not exclude a skill.
  fm="$(awk 'NR==1 && $0=="---"{inb=1;next} inb && $0=="---"{exit} inb{print}' "$f")"
  grep -qE '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' <<<"$fm" && continue
  name="$(sed -n 's/^name:[[:space:]]*//p' <<<"$fm" | head -1)"
  desc="$(sed -n 's/^description:[[:space:]]*//p' <<<"$fm" | head -1)"
  # An `if` rather than a trailing `[ cond ] && printf`: the loop is this
  # script's last command, so a false trailing conditional on the final
  # iteration would exit non-zero with the output already correct.
  if [ -n "$name" ] && [ -n "$desc" ]; then
    printf -- '- %s: %s\n' "$name" "$desc"
  fi
done
