#!/usr/bin/env bash
# Output the UserPromptSubmit hook script content.
# Used by DCI in SKILL.md to avoid hardcoding the reminder content.
# Source of truth: hooks/superpowers-reminder.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_FILE="$SCRIPT_DIR/../../hooks/superpowers-reminder.sh"

if [ -f "$HOOK_FILE" ]; then
  cat "$HOOK_FILE"
else
  echo "# ERROR: hooks/superpowers-reminder.sh not found at $HOOK_FILE"
  echo "# Copy it manually from the beads-superpowers repository."
fi
