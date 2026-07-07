#!/usr/bin/env bash
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
fail=0
# Isolated runtime dir + distinct session_id per case: Task 3's event-scoped dedup
# marker suppresses a second same-(session_id,source) event within 60s. These cases are
# ambient (no stdin, unisolated XDG_RUNTIME_DIR) and would otherwise collide on the same
# "nosid/unknown" marker key -- both with each other and with other test files that use
# the same real-/tmp fallback key (see tests/hooks/test-dedup-marker.sh).
RUNDIR=$(mktemp -d); trap 'rm -rf "$RUNDIR"' EXIT
warn_payload() { printf '{"session_id":"warn-%s","source":"startup"}' "$1"; }

# Case 1: bd absent → hint emitted, exit 0. Use a PATH that has system tools but not bd.
emptyhome=$(mktemp -d)
out=$(warn_payload 1 | PATH="/usr/bin:/bin" HOME="$emptyhome" XDG_RUNTIME_DIR="$RUNDIR" bash "$HOOK" 2>&1); rc=$?
echo "$out" | grep -qi "beads not found" || { echo "FAIL: no bd-absent hint"; fail=1; }
[ "$rc" -eq 0 ] || { echo "FAIL: hook did not exit 0 when bd absent (rc=$rc)"; fail=1; }
rm -rf "$emptyhome"

# Case 2: upstream present via REAL signal — installed_plugins.json carries the upstream handle.
tmp=$(mktemp -d); mkdir -p "$tmp/.claude/plugins"
printf '{"plugins":{"superpowers@claude-plugins-official":{"enabled":true}}}\n' > "$tmp/.claude/plugins/installed_plugins.json"
out=$(warn_payload 2 | HOME="$tmp" XDG_RUNTIME_DIR="$RUNDIR" bash "$HOOK" 2>&1)
echo "$out" | grep -qi "obra/superpowers appears installed" || { echo "FAIL: no collision warning from installed_plugins.json"; fail=1; }
rm -rf "$tmp"

# Case 2b: upstream present via second handle — superpowers@superpowers-marketplace.
tmp=$(mktemp -d); mkdir -p "$tmp/.claude/plugins"
printf '{"plugins":{"superpowers@superpowers-marketplace":{"enabled":true}}}\n' > "$tmp/.claude/plugins/installed_plugins.json"
out=$(warn_payload 2b | HOME="$tmp" XDG_RUNTIME_DIR="$RUNDIR" bash "$HOOK" 2>&1)
echo "$out" | grep -qi "obra/superpowers appears installed" || { echo "FAIL: no collision warning from superpowers-marketplace handle"; fail=1; }
rm -rf "$tmp"

# Case 3: clean HOME, bd present → NO collision warning (no false positive).
tmp=$(mktemp -d); mkdir -p "$tmp/.claude"
out=$(warn_payload 3 | HOME="$tmp" XDG_RUNTIME_DIR="$RUNDIR" bash "$HOOK" 2>&1)
echo "$out" | grep -qi "obra/superpowers appears installed" && { echo "FAIL: false-positive collision warning"; fail=1; }
rm -rf "$tmp"

# Case 4: unreadable SKILL.md → hook exits 0, valid JSON, no shell-error text in output.
tmp=$(mktemp -d)
mkdir -p "$tmp/hooks" "$tmp/skills/using-superpowers"
cp -f "$HOOK" "$tmp/hooks/session-start"
: > "$tmp/skills/using-superpowers/SKILL.md"
chmod 000 "$tmp/skills/using-superpowers/SKILL.md"
out=$(warn_payload 4 | HOME="$tmp" XDG_RUNTIME_DIR="$RUNDIR" bash "$tmp/hooks/session-start" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: hook did not exit 0 with unreadable SKILL.md (rc=$rc)"; fail=1; }
echo "$out" | jq -e '.' >/dev/null 2>&1 || { echo "FAIL: hook output is not valid JSON with unreadable SKILL.md"; fail=1; }
echo "$out" | grep -qi "Permission denied" && { echo "FAIL: hook output contains 'Permission denied'"; fail=1; }
echo "$out" | grep -qi "cat:" && { echo "FAIL: hook output contains 'cat:'"; fail=1; }
chmod 755 "$tmp/skills/using-superpowers/SKILL.md" 2>/dev/null
rm -rf "$tmp"

[ "$fail" -eq 0 ] && echo "PASS: session-start warnings" || exit 1
