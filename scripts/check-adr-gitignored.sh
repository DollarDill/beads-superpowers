#!/usr/bin/env bash
# check-adr-gitignored.sh — ADRs live under docs/decisions/ (inside the mkdocs-published
# docs/ tree) but MUST stay gitignored/local-only. A .gitignore regression would commit and
# publish internal ADRs to the public docs site. This guard fails loudly on that regression.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

if git check-ignore -q docs/decisions; then
  echo "OK: docs/decisions/ is gitignored"
  exit 0
fi
echo "FAIL: docs/decisions/ is NOT gitignored — internal ADRs risk being committed and published."
echo "Fix: ensure .gitignore ignores docs/decisions/ (e.g. a line 'docs/decisions/')."
exit 1
