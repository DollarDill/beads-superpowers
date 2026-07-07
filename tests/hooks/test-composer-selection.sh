#!/usr/bin/env bash
# tests/hooks/test-composer-selection.sh — unit-tests composer selection/ceiling
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# --- fake bd on PATH ---
mkdir -p "$TMP/bin" "$TMP/fixtures"
cat > "$TMP/bin/bd" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  memories) cat "$BSP_FIXTURES/memories.json" ;;
  recall)   cat "$BSP_FIXTURES/recall-$2.txt" 2>/dev/null || exit 1 ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/bd"
export PATH="$TMP/bin:$PATH" BSP_FIXTURES="$TMP/fixtures"

# --- fixture: JSON listing (verified real shape: one "key": "body" per line).
# long-refs-lesson is the truncation-regression case: @salience=4 sits past
# char 150 — plain-listing preview parsing would silently drop it.
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "big-lesson": "@type=semantic:lesson @created=2026-07-01 @salience=5 @tags=x big lesson full body",
  "medium-design": "@type=semantic:design @created=2026-07-02 @salience=4 @tags=y medium design full body",
  "long-refs-lesson": "@type=semantic:lesson @created=2026-07-03 @refs=aaaa,bbbb,cccc,dddd,eeee,ffff,gggg,hhhh,iiii,jjjj,kkkk,llll,mmmm,nnnn @tags=alpha,beta,gamma,delta,epsilon @salience=4 late-salience body",
  "low-note": "@type=episodic:done @created=2026-07-03 @salience=2 @tags=z low note body",
  "continuation-2026-07-06-old": "continuation old body",
  "continuation-2026-07-07-new": "continuation new body"
}
FIX
printf 'FULL BODY OF BIG LESSON (salience 5)\n' > "$TMP/fixtures/recall-big-lesson.txt"
printf 'FULL BODY OF MEDIUM DESIGN (salience 4)\n' > "$TMP/fixtures/recall-medium-design.txt"
printf 'LATE SALIENCE FULL BODY\n' > "$TMP/fixtures/recall-long-refs-lesson.txt"
printf 'CONTINUATION NEW BODY\n' > "$TMP/fixtures/recall-continuation-2026-07-07-new.txt"

# shellcheck disable=SC1090
BSP_SOURCED=1 . "$HOOK"

# 1. selection: salience 4/5 keys + latest continuation — incl. the late-@salience regression
sel=$(bd memories --json | bsp_select_memory_keys)
echo "$sel" | grep -q "5	big-lesson"        || { echo "FAIL: missing salience-5 key"; exit 1; }
echo "$sel" | grep -q "4	medium-design"     || { echo "FAIL: missing salience-4 key"; exit 1; }
echo "$sel" | grep -q "4	long-refs-lesson"  || { echo "FAIL: late-@salience key dropped (truncation regression)"; exit 1; }
cont=$(bd memories --json | bsp_latest_continuation)
[ "$cont" = "continuation-2026-07-07-new" ] || { echo "FAIL: latest continuation wrong: $cont"; exit 1; }
echo "$sel" | grep -q "low-note" && { echo "FAIL: salience-2 selected"; exit 1; }

# 2. composition order + disclosure (generous ceiling)
out=$(bsp_compose_memories 8192)
echo "$out" | grep -q "FULL BODY OF BIG LESSON"    || { echo "FAIL: s5 body absent"; exit 1; }
echo "$out" | grep -q "FULL BODY OF MEDIUM DESIGN" || { echo "FAIL: s4 body absent"; exit 1; }
[ "$(echo "$out" | grep -n 'BIG LESSON' | cut -d: -f1)" -lt "$(echo "$out" | grep -n 'MEDIUM DESIGN' | cut -d: -f1)" ] \
  || { echo "FAIL: s5 not before s4"; exit 1; }
echo "$out" | grep -q "core memories: 4 of 6 injected" || { echo "FAIL: disclosure line wrong"; exit 1; }

# 3. ceiling clip: tiny ceiling keeps continuation, clips the rest, emits tail
out=$(bsp_compose_memories 40)
echo "$out" | grep -q "CONTINUATION NEW BODY" || { echo "FAIL: continuation clipped"; exit 1; }
echo "$out" | grep -q "more core memories over budget" || { echo "FAIL: no +N tail"; exit 1; }

# 4. pre-sweep notice when no salience headers exist
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "plain-one": "some memory body without headers",
  "plain-two": "another memory body without headers"
}
FIX
out=$(bsp_compose_memories 8192)
echo "$out" | grep -q "curation sweep" || { echo "FAIL: pre-sweep notice absent"; exit 1; }

echo "PASS: composer selection/ceiling"
