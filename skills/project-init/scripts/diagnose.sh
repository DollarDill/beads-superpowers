#!/usr/bin/env bash
# diagnose.sh — project-init read-only diagnostic battery. RAW DATA ONLY: no verdicts, no fixes.
# The diagnosis->path decision is authored by the agent from this output (never automated here).
set -uo pipefail

# Bounded, non-fatal runner. Captures "$@"'s own exit status via the assignment
# (not the trailing `head`, whose own zero exit would otherwise mask a failure
# under `pipefail` — see tests/skills/test-diagnose-script.sh for the contract).
# head reads a HERE-STRING, never a pipe: `printf '%s\n' "$out" | head -10` made
# printf take SIGPIPE the moment head hit its limit, and pipefail promoted that
# 141 into b()'s return value — so every caller's `|| echo "... UNAVAILABLE"`
# fired on a healthy store whose output simply ran long (beads-superpowers-wze77.9).
b() {
  local out
  out=$("$@" 2>/dev/null) || return 1
  head -10 <<<"$out"
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
b bd dolt remote list || echo "bd dolt remote: UNAVAILABLE"
CFG_REMOTE=$(sed -n 's/^[[:space:]]*sync.remote:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' .beads/config.yaml 2>/dev/null | head -1)
if [ -n "$CFG_REMOTE" ]; then
  # Same SIGPIPE trap as b(): `... | grep -i dolt | head -3` made grep take
  # SIGPIPE at the 3rd ref, and pipefail turned that 141 into the pipeline
  # status — so a remote with MANY dolt refs reported "no dolt refs".
  CFG_REFS=$(git ls-remote "$CFG_REMOTE" 2>/dev/null || true)
  CFG_DOLT=$(grep -i dolt <<<"$CFG_REFS" || true)
  if [ -n "$CFG_DOLT" ]; then head -3 <<<"$CFG_DOLT"; else echo "configured beads remote: unreachable or no dolt refs"; fi
else
  echo "configured beads remote: NONE (sync.remote unset)"
fi
# Capture the ref list before matching. `git ls-remote origin | grep -qi dolt`
# under pipefail is a race: grep -q exits on the first dolt ref and closes the
# pipe, git takes SIGPIPE and exits 141, pipefail promotes 141 to the pipeline
# status, and the WARNING below is then silently SKIPPED on exactly the repos
# that have the problem it exists to report (beads-superpowers-wze77.9).
ORIGIN_REFS=$(git ls-remote origin 2>/dev/null || true)
if grep -qi dolt <<<"$ORIGIN_REFS"; then
  echo "WARNING: dolt refs on git origin (code repo) - beads data belongs on the dedicated beads remote (ADR-0057)"
else
  echo "git origin: clean (no dolt refs)"
fi

exit 0
