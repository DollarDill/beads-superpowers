#!/usr/bin/env bash
# Contract test for skills/requesting-code-review/code-reviewer.md.
# Pins are labelled: CHANGE-DETECTOR (convert to a plugin-eval review-output case,
# s9xyx, then delete) or security-floor (must survive verbatim).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT/skills/requesting-code-review/code-reviewer.md"
fail=0

check_exact() {  # fixed-string, must be present
  if grep -Fq -- "$1" "$FILE"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi
}

# CHANGE-DETECTOR (convert: plugin-eval review-output case, s9xyx)
check_exact "## The spec is a vision document"
# CHANGE-DETECTOR (convert: plugin-eval review-output case, s9xyx)
# Whole-line match: a substring pin is also satisfied by the template's '### Declined to judge'.
if grep -qx -- "## Declined to judge" "$FILE"; then echo "PASS: ## Declined to judge (whole line)"; else echo "FAIL: missing whole line — ## Declined to judge"; fail=1; fi

# CHANGE-DETECTOR (convert: plugin-eval review-output case, s9xyx)
# The Output Format template must carry a '### Declined to judge' slot before its '### Assessment'.
if awk '/^## Output Format/{o=1;next} o&&/^### Declined to judge/{d=1} o&&/^### Assessment/{exit !d}' "$FILE"; then
  echo "PASS: Output Format template has Declined to judge slot before Assessment"
else
  echo "FAIL: Output Format template lacks '### Declined to judge' before '### Assessment'"; fail=1
fi

# security-floor
check_exact "Security floor (blocking)"

if [ "$fail" -eq 0 ]; then echo "PASS: code-reviewer contract"; else exit 1; fi
