#!/usr/bin/env bash
# Output the SessionStart hook script content.
# Used by DCI in SKILL.md to install a verbatim copy of the canonical hook.
# Source of truth: hooks/session-start
# Search order: the CO-LOCATED copy (session-start.sh) FIRST — it is the only candidate that
# ships in the skills-only `npx skills add --copy` layout (no hooks/ sibling). It is kept
# byte-identical to hooks/session-start by scripts/check-convention-sync.sh. Repo/plugin
# layouts also expose ../../hooks/ as fallbacks.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for cand in \
  "$SCRIPT_DIR/session-start.sh" \
  "$SCRIPT_DIR/../../hooks/session-start" \
  "$SCRIPT_DIR/../../../hooks/session-start"; do
  [ -f "$cand" ] && { cat "$cand"; exit 0; }
done

echo "# ERROR: hooks/session-start not found"
echo "# Copy it manually from the beads-superpowers repository."
exit 0
