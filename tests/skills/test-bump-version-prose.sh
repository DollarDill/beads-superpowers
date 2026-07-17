#!/usr/bin/env bash
# tests/skills/test-bump-version-prose.sh — repo-script behavior test (rides the
# contracts runner). Pins bump-version.sh prose-surface coverage (bd-r4bb):
#   1. .version-bump.json declares CLAUDE.md as a prose entry ({path, prefix}).
#   2. A bump rewrites the CLAUDE.md "**Version:** X.Y.Z" line (sandboxed).
#   3. --check detects prose drift (nonzero exit when prose disagrees).
#   4. .internal is audit-excluded (gitignored history must never be flagged).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="$ROOT/.version-bump.json"
fail=0
ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

command -v jq >/dev/null || { echo "SKIP: jq not available"; exit 0; }

# --- 1. config declares CLAUDE.md prose entry ---
if jq -e '.prose[] | select(.path == "CLAUDE.md" and .prefix == "**Version:** ")' "$CONFIG" >/dev/null 2>&1; then
  ok "config declares CLAUDE.md prose entry"
else
  bad "config missing prose entry for CLAUDE.md (prefix '**Version:** ')"
fi

# --- 4. .internal audit-excluded ---
if jq -e '.audit.exclude | index(".internal")' "$CONFIG" >/dev/null 2>&1; then
  ok ".internal is audit-excluded"
else
  bad ".internal missing from audit.exclude"
fi

# --- sandbox: copy script + config + all declared files into a tmp repo root ---
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts"
cp -f "$ROOT/scripts/bump-version.sh" "$TMP/scripts/"
cp -f "$CONFIG" "$TMP/"
while IFS= read -r p; do
  mkdir -p "$TMP/$(dirname "$p")"
  cp -f "$ROOT/$p" "$TMP/$p"
done < <(jq -r '(.files[].path), (.prose[]?.path)' "$CONFIG")

# --- 2. bump rewrites the CLAUDE.md Version line ---
if bash "$TMP/scripts/bump-version.sh" 9.9.9 >/dev/null 2>&1 \
   && grep -q '^\*\*Version:\*\* 9\.9\.9$' "$TMP/CLAUDE.md"; then
  ok "bump rewrites CLAUDE.md Version line"
else
  bad "bump did not rewrite CLAUDE.md Version line to 9.9.9"
fi

# --- 3. --check detects prose drift ---
# All files are at 9.9.9 now; --check must pass...
if bash "$TMP/scripts/bump-version.sh" --check >/dev/null 2>&1; then
  ok "--check passes when prose is in sync"
else
  bad "--check failed on an in-sync tree"
fi
# ...then fail once the prose line drifts.
sed -i 's/^\*\*Version:\*\* 9\.9\.9$/**Version:** 0.0.1/' "$TMP/CLAUDE.md"
if bash "$TMP/scripts/bump-version.sh" --check >/dev/null 2>&1; then
  bad "--check missed prose drift (CLAUDE.md at 0.0.1, manifests at 9.9.9)"
else
  ok "--check detects prose drift"
fi

exit "$fail"
