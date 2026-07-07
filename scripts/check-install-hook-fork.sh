#!/usr/bin/env bash
# check-install-hook-fork.sh — anti-fork guard (bead bb6x): install.sh's written
# hook is either a thin exec shim of hooks/session-start (checkout tiers) or a
# policy-free minimal fallback (npx tier). Session-start composition policy —
# bd prime capture, salience selection, the JSON memories listing — lives ONLY
# in hooks/session-start; if any of these patterns reappear in install.sh, the
# 4th fork is back.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$ROOT/install.sh}"   # override for self-testing against a fixture
rc=0
# shellcheck disable=SC2016  # '$(bd prime' is a literal forbidden pattern, not an expansion
for pat in 'salience' 'bd memories --json' '$(bd prime'; do
  if hits=$(grep -nF -- "$pat" "$TARGET"); then
    echo "install-hook-fork: FAIL — forbidden pattern '$pat' in ${TARGET##*/}:"
    echo "$hits"
    rc=1
  fi
done
[ "$rc" -eq 0 ] && echo "install-hook-fork: OK (no session-start policy forked into install.sh)"
exit "$rc"
