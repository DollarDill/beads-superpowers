#!/usr/bin/env bash
# Guard: every doctrine-class skill carries a self-contained Production-Grade
# Doctrine floor at its own point of use (ADR-0036 / ADR-0040).
#
# WHY THIS EXISTS
#   The canonical doctrine block lives in `using-superpowers`, which is injected
#   by the SessionStart hook. That injection does not reach dispatched subagents
#   (the skill opens with SUBAGENT-STOP), does not survive compaction, and never
#   fires on the six Tier-B harnesses. A skill whose own steps perform the risky
#   operation therefore cannot rely on the bootstrap being present — it must
#   restate the floor itself. This is the fork's "kernel" pattern, a deliberate
#   divergence from upstream skill-design practice (which states a guardrail once
#   in its owning skill); the trade is duplication in exchange for reach.
#
# WHAT IT CHECKS
#   Presence, not byte-identity. ADR-0040 requires each floor to be phrased for
#   its own skill's operation ("make the code meet the test" in TDD reads nothing
#   like "surface the trade-off" in SDD), so the byte-identity machinery in
#   check-convention-sync.sh deliberately does NOT apply here. A cross-reference
#   that merely names the doctrine without stating a rule is what this guard
#   exists to catch, so presence is asserted against a rule-bearing line: the
#   match must carry the leading phrase AND at least one imperative clause.
#
# SCOPE
#   DOCTRINE_SKILLS lists the skills whose own steps take the risk — design
#   gates, implementation, and completion claims. It is an explicit allowlist,
#   not a glob: adding a skill to skills/ must not silently place it under a
#   floor requirement nobody wrote. A new skill that genuinely performs a risky
#   operation gets added here deliberately, in the same commit as its floor.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT" || exit 1

DOCTRINE_SKILLS="
brainstorming
executing-plans
stress-test
writing-plans
test-driven-development
subagent-driven-development
systematic-debugging
verification-before-completion
"

# A floor line must name the doctrine. Anchoring on the leading word alone would
# accept a bare pointer ("see the Production-Grade Doctrine"), which is the exact
# defect this guard was written for — so a rule-bearing clause is required too.
SIG='Production-Grade Doctrine'
RULE='never|Never|MUST|must|forbidden|surface|Surface|report|Report'

fail=0
checked=0
for name in $DOCTRINE_SKILLS; do
  f="skills/$name/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "FAIL: $f is listed as a doctrine-class skill but does not exist — fix the list or restore the skill"
    fail=1; continue
  fi
  checked=$((checked + 1))
  hits=$(grep -cF "$SIG" "$f" || true)
  if [ "$hits" -eq 0 ]; then
    echo "FAIL: $f has no Production-Grade Doctrine floor — the bootstrap does not reach subagents, compaction, or Tier-B harnesses, so this skill's own steps would run unfloored"
    fail=1; continue
  fi
  if ! grep -F "$SIG" "$f" | grep -qE "$RULE"; then
    echo "FAIL: $f names the Production-Grade Doctrine but states no rule — a pointer is not a floor; restate the obligation in this skill's own terms (ADR-0040)"
    fail=1; continue
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "FAIL: no doctrine-class skills were checked — the allowlist resolved to nothing, so this guard proved nothing"
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: doctrine-floor guard passed ($checked doctrine-class skills carry a rule-bearing floor)"
fi
exit "$fail"
