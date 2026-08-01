#!/usr/bin/env bash
# run-guards.sh — every deterministic guard, one entrypoint. Tool, not gate.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit
rc=0
run() { echo "── $1"; shift; if "$@"; then echo "   PASS"; else echo "   FAIL"; rc=1; fi; }

run "todowrite gate"        bash scripts/check-todowrite.sh
run "todowrite gate (.claude)" bash scripts/check-todowrite.sh .claude/skills
run "agent bead stamp"      bash scripts/check-agent-bead-stamp.sh
run "zh docs parity"        bash scripts/check-zh-docs.sh
run "convention sync"       bash scripts/check-convention-sync.sh
run "skill count guard"     bash scripts/check-skill-count.sh
run "version sync"          bash scripts/bump-version.sh --check
run "skill frontmatter"     python3 scripts/check-skill-frontmatter.py
run "shell lint"            bash scripts/lint-shell.sh
run "askuser genericization" bash scripts/check-askuser-genericization.sh
run "askuser genericization (.claude)" bash scripts/check-askuser-genericization.sh .claude/skills
run "model genericization"  bash scripts/check-model-genericization.sh
run "model genericization (.claude)" bash scripts/check-model-genericization.sh .claude/skills
run "skill ref namespacing"  bash scripts/check-skill-ref-namespace.sh
run "skill ref namespacing (.claude)" bash scripts/check-skill-ref-namespace.sh .claude/skills
run "install hook no-fork"  bash scripts/check-install-hook-fork.sh
run "adr gitignored"        bash scripts/check-adr-gitignored.sh
run "agents symlink"        bash scripts/check-agents-symlink.sh
run "kb label vocab"        bash scripts/check-kb-labels.sh
run "kb doc reconciliation" bash scripts/check-kb-doc-reconciliation.sh
run "guardrail floor"       bash scripts/check-guardrail-floor.sh
run "doctrine floor"        bash scripts/check-doctrine-floor.sh
# knowledge-retrieval's two suites. Both SKIP visibly and exit 0 when a
# prerequisite is missing — test-rank.sh on python3, test-surface-interface.sh on
# bd or python3 — so a clone lacking those tools prints the SKIP line and the
# runner stays green. `kb label vocab` above instead exits 2 with an ERROR when bd
# is absent; that shape is a known wart, deliberately not copied here.
run "rank invariants"       bash tests/skills/test-rank.sh
run "surface interface"     bash tests/skills/test-surface-interface.sh
exit "$rc"
