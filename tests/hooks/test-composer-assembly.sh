#!/usr/bin/env bash
# tests/hooks/test-composer-assembly.sh
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/fixtures" "$TMP/ws" "$TMP/run"
cat > "$TMP/bin/bd" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  memories) cat "$BSP_FIXTURES/memories.json" ;;
  recall)   printf 'RECALLED BODY %s\n' "$2" ;;
  config)   printf '' ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/bd"
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "key-a": "@type=semantic:lesson @created=2026-07-01 @salience=5 preview body"
}
FIX
mkdir -p "$TMP/home/.claude"   # isolated HOME: a real dev machine's ~/.claude/settings.json may
                               # itself register a "bd prime" hook (e.g. via `bd setup claude`),
                               # which would trip the dedup guard and suppress <beads-context>
                               # (same isolation pattern as test-bd-prime-dedup.sh / test-session-start-warnings.sh)
export PATH="$TMP/bin:$PATH" BSP_FIXTURES="$TMP/fixtures" HOME="$TMP/home"
export XDG_RUNTIME_DIR="$TMP/run"   # marker isolation (Task 3 adds a dedup marker; this test must never touch real markers)
cd "$TMP/ws"   # no .beads here; no settings files

# distinct stdin per invocation: each run its own event (dedup-marker-safe once Task 3 lands)
out=$(printf '{"session_id":"t2-a","source":"startup"}' | bash "$HOOK" --emit-plain)
grep -q "hookSpecificOutput" <<<"$out" && { echo "FAIL: JSON envelope in plain mode"; exit 1; }
grep -q "RECALLED BODY key-a" <<<"$out" || { echo "FAIL: composed memory absent"; exit 1; }
grep -q "bd ready" <<<"$out" || { echo "FAIL: bd pointer block absent"; exit 1; }
grep -q "Persistent Memories (1)" <<<"$out" && { echo "FAIL: raw prime dump leaked"; exit 1; }

# JSON mode still emits envelope (distinct session id → distinct event)
outj=$(printf '{"session_id":"t2-b","source":"startup"}' | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
grep -q '"hookSpecificOutput"' <<<"$outj" || { echo "FAIL: JSON envelope missing"; exit 1; }
grep -q 'RECALLED BODY key-a' <<<"$outj" || { echo "FAIL: composed memory absent from JSON mode"; exit 1; }

echo "PASS: composer assembly"
