#!/usr/bin/env bash
# Contract test for session-handoff — pins INVARIANTS, not prose (ADR-0049 slice2 T1a).
# KEEP: behavioral strings only — announce text, output-path convention, continuation-memory
# key format, secret-scan token list, own-operation guardrails, model-trigger-surface absence.
# Never add prose-structure assertions (section headings, narrative wording).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/session-handoff/SKILL.md"
fail=0

check_exact() {  # fixed-string, must be present
  if grep -Fq "$1" "$2"; then echo "PASS: $1"; else echo "FAIL: missing — $1 ($2)"; fail=1; fi
}

# --- Announce line (behavioral output contract) ---
check_exact "I'm using the session-handoff skill to write a session handoff." "$SKILL"

# --- Output-path convention ---
check_exact ".internal/handoff/YYYY-MM-DD[-HHMMSS]-<topic>-handoff.md" "$SKILL"

# --- Continuation-memory key format ---
check_exact "continuation-<date>-<topic>" "$SKILL"

# --- Secret-scan token list (own-operation guardrail) ---
check_exact "\`sk-\`" "$SKILL"
check_exact "\`ghp_\`" "$SKILL"
check_exact "\`AKIA\`" "$SKILL"
check_exact "\`-----BEGIN\`" "$SKILL"
check_exact "\`password=\`" "$SKILL"

# --- Gitignore-safety check (own-operation guardrail) ---
check_exact "git check-ignore" "$SKILL"

# --- Absence of model-trigger surfaces (frontmatter mechanism) ---
check_exact "disable-model-invocation: true" "$SKILL"

[ "$fail" -eq 0 ] && echo "PASS: session-handoff contract" || exit 1
