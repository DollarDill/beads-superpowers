#!/usr/bin/env bash
# check-skill-ref-namespace.sh — ADR-0043: Skill() cross-references in live skill
# content use the canonical namespaced form Skill(beads-superpowers:<skill>).
# Bare refs resolve only on some install channels; the using-superpowers
# "Skill Name Resolution" rule handles runtime mapping — this guard keeps the
# source form canonical. Occurrence-based (grep -o) so a line holding both a
# good and a bad ref still fails. Deliberately NO-SPACE 'Skill(' only: prose
# like "Skill (64 characters maximum)" is a natural English parenthetical and
# false-positives under 'Skill ?\(' (seen in since-removed skill docs);
# a space-form *invocation* has never occurred in this repo.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
SEARCH_ROOT="${1:-skills}"   # override for self-testing against a fixture
VIOLATIONS="$(grep -rno 'Skill([^)]*)' "$SEARCH_ROOT/" 2>/dev/null | grep -v 'Skill(beads-superpowers:' || true)"
if [ -n "$VIOLATIONS" ]; then
  echo "skill-ref-namespace: FAIL — bare Skill() reference(s); use Skill(beads-superpowers:<skill>) (ADR-0043):"
  echo "$VIOLATIONS"
  exit 1
fi
echo "skill-ref-namespace: OK (all Skill() refs use the beads-superpowers: namespace)"
