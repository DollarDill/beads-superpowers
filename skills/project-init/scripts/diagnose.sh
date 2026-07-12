#!/usr/bin/env bash
# diagnose.sh — project-init read-only diagnostic battery. RAW DATA ONLY: no verdicts, no fixes.
# The diagnosis->path decision is authored by the agent from this output (never automated here).
set -uo pipefail

# Bounded, non-fatal runner. Captures "$@"'s own exit status via the assignment
# (not the trailing `| head`, whose own zero exit would otherwise mask a failure
# under `pipefail` — see tests/skills/test-diagnose-script.sh for the contract).
b() {
  local out
  out=$("$@" 2>/dev/null) || return 1
  printf '%s\n' "$out" | head -10
}

echo "== versions =="
b bd version   || echo "bd: UNAVAILABLE (install: https://github.com/gastownhall/beads)"
b dolt version || echo "dolt: UNAVAILABLE (embedded mode needs no separate dolt binary)"

echo "== beads-dir =="
if [ -d .beads ]; then b ls -la .beads/; else echo ".beads/: ABSENT"; fi

echo "== config =="
b cat .beads/config.yaml   || echo "config.yaml: UNAVAILABLE"
b cat .beads/metadata.json || echo "metadata.json: UNAVAILABLE"

echo "== db =="
b bd list -n 5 || echo "bd list: UNAVAILABLE (db unreadable or absent)"
b bd vc status || echo "bd vc status: UNAVAILABLE"

echo "== dolt-remote =="
git ls-remote origin 2>/dev/null | grep -i dolt | head -5 || echo "git origin dolt refs: NONE FOUND"
b bd dolt remote list || echo "bd dolt remote: UNAVAILABLE"

exit 0
