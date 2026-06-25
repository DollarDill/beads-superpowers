#!/usr/bin/env bash
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
fail=0

# Case 1: bd absent → hint emitted, exit 0. Use a PATH that has system tools but not bd.
emptyhome=$(mktemp -d)
out=$(PATH="/usr/bin:/bin" HOME="$emptyhome" bash "$HOOK" 2>&1); rc=$?
echo "$out" | grep -qi "beads not found" || { echo "FAIL: no bd-absent hint"; fail=1; }
[ "$rc" -eq 0 ] || { echo "FAIL: hook did not exit 0 when bd absent (rc=$rc)"; fail=1; }
rm -rf "$emptyhome"

# Case 2: upstream present via REAL signal — installed_plugins.json carries the upstream handle.
tmp=$(mktemp -d); mkdir -p "$tmp/.claude/plugins"
printf '{"plugins":{"superpowers@claude-plugins-official":{"enabled":true}}}\n' > "$tmp/.claude/plugins/installed_plugins.json"
out=$(HOME="$tmp" bash "$HOOK" 2>&1)
echo "$out" | grep -qi "obra/superpowers appears installed" || { echo "FAIL: no collision warning from installed_plugins.json"; fail=1; }
rm -rf "$tmp"

# Case 2b: upstream present via second handle — superpowers@superpowers-marketplace.
tmp=$(mktemp -d); mkdir -p "$tmp/.claude/plugins"
printf '{"plugins":{"superpowers@superpowers-marketplace":{"enabled":true}}}\n' > "$tmp/.claude/plugins/installed_plugins.json"
out=$(HOME="$tmp" bash "$HOOK" 2>&1)
echo "$out" | grep -qi "obra/superpowers appears installed" || { echo "FAIL: no collision warning from superpowers-marketplace handle"; fail=1; }
rm -rf "$tmp"

# Case 3: clean HOME, bd present → NO collision warning (no false positive).
tmp=$(mktemp -d); mkdir -p "$tmp/.claude"
out=$(HOME="$tmp" bash "$HOOK" 2>&1)
echo "$out" | grep -qi "obra/superpowers appears installed" && { echo "FAIL: false-positive collision warning"; fail=1; }
rm -rf "$tmp"

[ "$fail" -eq 0 ] && echo "PASS: session-start warnings" || exit 1
