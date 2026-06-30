#!/usr/bin/env bash
# Output the UserPromptSubmit hook script content.
# Used by DCI in SKILL.md to avoid hardcoding the reminder content.
# Source of truth: hooks/superpowers-reminder.sh
# Searches candidate relative paths to handle both source-repo and installed layouts.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for cand in \
  "$SCRIPT_DIR/../../hooks/superpowers-reminder.sh" \
  "$SCRIPT_DIR/../../../hooks/superpowers-reminder.sh"; do
  [ -f "$cand" ] && { cat "$cand"; exit 0; }
done

echo "# ERROR: hooks/superpowers-reminder.sh not found"
echo "# Copy it manually from the beads-superpowers repository."
exit 0
