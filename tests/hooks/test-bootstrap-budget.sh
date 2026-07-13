#!/usr/bin/env bash
# test-bootstrap-budget.sh — guard the always-injected session bootstrap size (ADR-0039).
# SCOPE: SKILL.md FILE bytes only. bd prime output and conditional warnings are
# deliberately OUT of budget — they are environment-sized and dedup-guarded.
# Do not "fix" this test to measure the full injection; that makes it flaky.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/session-start"
SKILL="$ROOT/skills/using-superpowers/SKILL.md"
CEILING=6144
WRAPPER_CEILING=1024
fail=0
size=$(wc -c < "$SKILL")
if [ "$size" -gt "$CEILING" ]; then
  echo "FAIL: using-superpowers/SKILL.md is ${size} bytes (> ${CEILING})"; fail=1
fi
# Static wrapper template (the session_context_raw assignment line in the hook,
# variable names unexpanded) must stay small too.
# Renamed session_context -> session_context_raw (Task 2, raw/one-escape contract) — pattern updated to match.
wrapper=$(grep -m1 'session_context_raw=' "$ROOT/hooks/session-start" | wc -c)
if [ "$wrapper" -gt "$WRAPPER_CEILING" ]; then
  echo "FAIL: session-start wrapper template is ${wrapper} bytes (> ${WRAPPER_CEILING})"; fail=1
fi
if [ "$fail" = 0 ]; then
  echo "PASS: bootstrap ${size}B <= ${CEILING}B; wrapper ${wrapper}B <= ${WRAPPER_CEILING}B"
fi

# --- composed-mode budget + latency (Task 2: --emit-plain) ---
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/fixtures" "$TMP/home/.claude" "$TMP/run"
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
# Isolated HOME: a real dev machine's ~/.claude/settings.json may itself register a
# "bd prime" hook, tripping the dedup guard (see test-composer-assembly.sh).
export PATH="$TMP/bin:$PATH" BSP_FIXTURES="$TMP/fixtures" HOME="$TMP/home"
export XDG_RUNTIME_DIR="$TMP/run"   # marker isolation + distinct events per invocation (see test-composer-assembly.sh)

# overflow fixture: 20 salience-5 memories with ~1KB bodies — proves CLAMPING
# to the total envelope budget (ADR-0052), not just observing a small fixture
{
  echo '{'
  for i in $(seq 1 20); do
    printf '  "of-%02d": "@type=semantic:lesson @created=2026-07-12 @salience=5 body %02d",\n' "$i" "$i"
  done
  echo '  "of-tail": "plain tail"'
  echo '}'
} > "$TMP/fixtures/memories.json"
big=$(printf 'B%.0s' {1..1024})
cat > "$TMP/bin/bd" <<FAKE
#!/usr/bin/env bash
case "\$1" in
  memories) cat "\$BSP_FIXTURES/memories.json" ;;
  recall)   printf '%s\n' "$big" ;;
  config)   printf '' ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/bd"
# single sourced read: constants + pointer size from the hook's own definitions
# shellcheck disable=SC1090
read -r BUDGET WRAP PTR < <(BSP_SOURCED=1 . "$HOOK"; printf '%s %s %s\n' "$BSP_ENVELOPE_BUDGET" "$BSP_WRAP_OVERHEAD" "$(bsp_bd_pointer | wc -c)")
[ -n "${BUDGET:-}" ] || { echo "FAIL: BSP_ENVELOPE_BUDGET not defined pre-seam"; fail=1; }
sz=$(printf '{"session_id":"budget-a","source":"startup"}' | bash "$HOOK" --emit-plain | wc -c)
[ "$sz" -le "${BUDGET:-0}" ] || { echo "FAIL: composed output ${sz}B > envelope budget ${BUDGET:-unset}B under overflow fixture"; fail=1; }
# floor deadlock guard: worst-case bootstrap (SKILL.md at its 6144B ceiling) must
# still leave room for the beads wrapper + pointer (stress-test B5 arithmetic)
[ $((BUDGET - CEILING - WRAP - PTR)) -ge 0 ] || { echo "FAIL: floor deadlock — budget cannot fit max bootstrap + pointer"; fail=1; }
if [ "$fail" = 0 ]; then
  echo "PASS: composed ${sz}B <= budget ${BUDGET}B under overflow fixture; floor margin $((BUDGET - CEILING - WRAP - PTR))B"
fi

# latency budget: full composition under 5s wall-clock
t0=$(date +%s)
printf '{"session_id":"budget-b","source":"startup"}' | bash "$HOOK" --emit-plain >/dev/null
t1=$(date +%s)
[ $((t1 - t0)) -lt 5 ] || { echo "FAIL: hook took $((t1 - t0))s (>=5s budget)"; fail=1; }

if [ "$fail" = 0 ]; then
  echo "PASS: latency $((t1 - t0))s < 5s"
fi
exit "$fail"
