#!/usr/bin/env bash
# run-guards.sh — every deterministic guard, one entrypoint. Tool, not gate.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit
rc=0
run() { echo "── $1"; shift; if "$@"; then echo "   PASS"; else echo "   FAIL"; rc=1; fi; }

run "todowrite gate"        bash scripts/check-todowrite.sh
run "agent bead stamp"      bash scripts/check-agent-bead-stamp.sh
run "zh docs parity"        bash scripts/check-zh-docs.sh
run "convention sync"       bash scripts/check-convention-sync.sh
run "skill count guard"     bash scripts/check-skill-count.sh
run "version sync"          bash scripts/bump-version.sh --check
run "skill frontmatter"     python3 scripts/check-skill-frontmatter.py
run "shell lint"            bash scripts/lint-shell.sh
run "askuser genericization" bash scripts/check-askuser-genericization.sh
exit "$rc"
