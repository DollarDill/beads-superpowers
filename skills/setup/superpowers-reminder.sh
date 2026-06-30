#!/usr/bin/env bash
# superpowers-reminder.sh — UserPromptSubmit hook for Claude Code, Codex, Cursor
# Injects a reminder to check superpowers skills on every user prompt.
# Matcher: "" (fires on every prompt submission)
set -euo pipefail

# Read reminder content from canonical shared file (strip full-line # comments — maintainer-only)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REMINDER="$(sed '/^[[:space:]]*#/d' "${PLUGIN_ROOT}/skills/using-superpowers/reminder-content.txt" 2>/dev/null || printf 'SUPERPOWERS REMINDER: check if a beads-superpowers skill applies.')"

# Escape string for JSON embedding using bash parameter substitution.
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

REMINDER_ESCAPED="$(escape_for_json "$REMINDER")"

if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  printf '{\n  "additional_context": "%s"\n}\n' "$REMINDER_ESCAPED"
elif { [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || [ -n "${CODEX_PLUGIN_ROOT:-}" ]; } && [ -z "${COPILOT_CLI:-}" ]; then
  printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "UserPromptSubmit",\n    "additionalContext": "%s"\n  }\n}\n' "$REMINDER_ESCAPED"
else
  printf '{\n  "additionalContext": "%s"\n}\n' "$REMINDER_ESCAPED"
fi

exit 0
