#!/usr/bin/env bash
# run.sh [all|<harness>] — install-shape suite driver.
# Tier A (claude codex opencode): full artifact assertions + uninstall round-trip.
# Tier B (cursor copilot kimi antigravity droid pi): hint-text + manifest assertions.
# Banner: proves artifacts LAND — does NOT prove hooks FIRE. See MANUAL-VERIFICATION.md.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-all}"
TIER_A="claude codex opencode"
TIER_B="cursor copilot kimi antigravity droid pi"
total_rc=0

echo "install-shape: proves artifacts land where each harness expects — does NOT prove hooks fire."
echo "Live/auth-gated verification: tests/install-shape/MANUAL-VERIFICATION.md"
echo

run_case() {
  local h="$1" script="$HERE/assert-$1.sh"
  case " $TIER_B " in *" $h "*) script="$HERE/assert-tier-b.sh" ;; esac
  echo "═══ $h"
  if bash "$script" "$h"; then echo "═══ $h PASS"; else echo "═══ $h FAIL"; total_rc=1; fi
  echo
}

if [ "$TARGET" = "all" ]; then
  # --source contract test first (every other case depends on it)
  echo "═══ source-flag"
  if bash "$HERE/test-source-flag.sh"; then echo "═══ source-flag PASS"; else echo "═══ source-flag FAIL"; total_rc=1; fi
  echo
  for h in $TIER_A $TIER_B combo; do run_case "$h"; done
else
  run_case "$TARGET"
fi
exit "$total_rc"
