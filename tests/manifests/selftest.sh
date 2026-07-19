#!/usr/bin/env bash
# Guard-the-guards for test-manifest-validation.sh. Stage a clean fixture copy
# of every manifest the validator touches, confirm it PASSES clean, then apply
# one mutation per NEW check and confirm the validator FAILS each time. A check
# that can never fail is a blind green check (ADR-0025).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST="$ROOT/tests/manifests/test-manifest-validation.sh"
fails=0

FILES=(
  package.json
  .claude-plugin/plugin.json .claude-plugin/marketplace.json
  .codex-plugin/plugin.json  .codex-plugin/marketplace.json
  .cursor-plugin/plugin.json
  .kimi-plugin/plugin.json
  .agents/plugins/marketplace.json
  hooks/hooks-cursor.json hooks/run-hook.cmd
  skills/using-superpowers/SKILL.md
  .pi/extensions/superpowers.ts
)

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
# Re-stage a pristine fixture (fresh temp dir) before each mutation.
stage() {
  rm -rf "$FIX"; FIX="$(mktemp -d)"
  ( cd "$ROOT" && cp --parents "${FILES[@]}" "$FIX"/ )
}
expect_pass() {  # label
  if MANIFEST_ROOT="$FIX" bash "$TEST" >/dev/null 2>&1; then
    echo "OK   clean fixture passes: $1"
  else
    echo "SELFTEST FAIL: clean fixture should pass but failed: $1"; fails=1
  fi
}
expect_fail() {  # label
  if MANIFEST_ROOT="$FIX" bash "$TEST" >/dev/null 2>&1; then
    echo "SELFTEST FAIL: mutation NOT caught: $1"; fails=1
  else
    echo "OK   mutation caught: $1"
  fi
}
jq_set() {  # file, filter
  jq "$2" "$1" > "$1.tmp" && mv -f "$1.tmp" "$1"
}

# Baseline: the validator must pass on a clean copy.
stage; expect_pass "baseline"

# M1 — bad JSON in a marketplace manifest -> JSON-validation loop.
stage; printf '\n{bad' >> "$FIX/.agents/plugins/marketplace.json"
expect_fail "M1 bad JSON in .agents marketplace"

# M2 — .codex marketplace version drift -> ver_match.
stage; jq_set "$FIX/.codex-plugin/marketplace.json" '.plugins[0].version="9.9.9"'
expect_fail "M2 .codex marketplace version drift"

# M3 — .agents source manifest given a version -> role: must be version-less.
stage; jq_set "$FIX/.agents/plugins/marketplace.json" '.plugins[0].version="0.14.0"'
expect_fail "M3 .agents marketplace given a version"

# M4 — .pi extension loses its export default -> structural grep.
stage; sed -i 's/export default //' "$FIX/.pi/extensions/superpowers.ts"
expect_fail "M4 .pi missing export default"

exit $fails
