#!/usr/bin/env bash
# tests/skills/test-writing-plans-contract.sh — run: bash tests/skills/test-writing-plans-contract.sh
set -euo pipefail
F="$(cd "$(dirname "$0")/../.." && pwd)/skills/writing-plans/SKILL.md"
fail=0
pin() { grep -qF -- "$1" "$F" || { echo "FAIL: missing: $1"; fail=1; }; }
# CHANGE-DETECTOR (convert: plugin-eval plan-quality case, s9xyx) — template + self-review
pin '## Review Focus'
pin '**4. Review Focus:**'
# CHANGE-DETECTOR (convert: plugin-eval handoff case, s9xyx) — recommendation heuristics
pin 'more than about eight tasks'
pin 'auth, secrets, permissions, input validation or data deletion'
pin 'names an execution method'
# CHANGE-DETECTOR (convert: plugin-eval handoff case, s9xyx) — option descriptions state the real trade
pin 'one final whole-branch review'
pin 'fresh implementer and a fresh reviewer per task'
# CHANGE-DETECTOR (convert: plugin-eval plan-quality case, s9xyx) — v6.4.2 adoption (0.17.0 A1)
pin '## Step Granularity'
pin '**Each step is one action with a checkable result:**'
pin '## What a Step Contains'
pin '**2. Step scan:**'
pin '**5. Proportion:**'
pin 'An empty section means you checked and found none, not that you skipped the check.'
pin 'once they know the exact interface and the exact test'
# CHANGE-DETECTOR (convert: plugin-eval plan-quality case, s9xyx) — ADR-0049 rationalization phrases survive the rewrite verbatim
pin '"TODO"'
pin '"implement later"'
pin '"fill in details"'
pin '"Similar to Task N"'
pin '"add appropriate error handling"'
pin '"add validation"'
# CHANGE-DETECTOR (convert: plugin-eval plan-quality case, s9xyx) — beads adaptation (stress-test B6)
pin 'For a prose or Markdown edit, the decisions are the target file and anchor'
# bright line at the point of decision — urgency never skips the plan or its gate (beads-superpowers-sdeg7;
# behaviour pinned by evals/writing-plans/fires-on-approved-spec)
pin '**Never** skip the plan or its review gate'
pin 'urgency is pressure, not permission'
# absence-of-defect — superseded upstream text gone
absent() { if grep -qF -- "$1" "$F"; then echo "FAIL: still present: $1"; fail=1; fi; }
absent '## No Placeholders'
absent '2-5 minutes'
absent 'questionable taste'
# absence-of-defect — a template header that pre-selects a method disables the handoff heuristics
absent 'subagent-driven-development (recommended)'
# CHANGE-DETECTOR (convert: plugin-eval handoff case, s9xyx) — the template header defers the method to the handoff
pin 'chosen at the Execution Handoff'
# CHANGE-DETECTOR (convert: plugin-eval handoff case, s9xyx) — only a header naming ONE method pre-selects it
pin 'a plan header naming only one method'
[ "$fail" -eq 0 ] && echo "PASS: writing-plans contract" || exit 1
