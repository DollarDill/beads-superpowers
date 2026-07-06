#!/usr/bin/env bash
# check-askuser-genericization.sh — ADR-0041: the literal Claude Code tool name
# "AskUserQuestion" must not appear in skill content outside the per-harness
# reference files (skills/using-superpowers/references/). Skills use generic
# "structured question tool" phrasing; the universal convention lives in the
# using-superpowers "Asking the User" block. If the ADR-0041 micro-test
# fallback ever ships a name-drop in using-superpowers/SKILL.md, extend
# ALLOW_RE in the same commit.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
SEARCH_ROOT="${1:-skills}"   # override for self-testing against a fixture
ALLOW_RE='^.*skills/using-superpowers/references/'
VIOLATIONS="$(grep -rn "AskUserQuestion" "$SEARCH_ROOT/" 2>/dev/null | grep -Ev "$ALLOW_RE" || true)"
if [ -n "$VIOLATIONS" ]; then
  echo "askuser-genericization: FAIL — literal AskUserQuestion outside the reference-file allowlist (ADR-0041):"
  echo "$VIOLATIONS"
  exit 1
fi
echo "askuser-genericization: OK (no literal AskUserQuestion in skill content outside references/)"
