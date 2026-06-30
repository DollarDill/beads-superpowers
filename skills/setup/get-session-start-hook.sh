#!/usr/bin/env bash
# Output the SessionStart hook script content.
# Used by DCI in SKILL.md to install a verbatim copy of the canonical hook.
# Source of truth: hooks/session-start
# Searches candidate relative paths to handle both source-repo and installed layouts.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for cand in \
  "$SCRIPT_DIR/../../hooks/session-start" \
  "$SCRIPT_DIR/../../../hooks/session-start"; do
  [ -f "$cand" ] && { cat "$cand"; exit 0; }
done

echo "# ERROR: hooks/session-start not found"
echo "# Copy it manually from the beads-superpowers repository."
exit 0
