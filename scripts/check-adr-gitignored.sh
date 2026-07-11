#!/usr/bin/env bash
# check-adr-gitignored.sh — docs/ is consumed by the-factory-website's mkdocs build
# (exclude_docs: decisions/ lives in THEIR tenant config — ADR-0050); ADRs must stay gitignored
# here so they never publish. A .gitignore regression would commit and publish internal ADRs to
# the public docs site. This guard fails loudly on that regression.
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
