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

# 3. ceiling clip: ceiling 90 fits the continuation SECTION (### header + 21B body
#    + scaffolding ≈ 55B), clips the rest, emits tail. Ceiling 40 does NOT fit the
#    section -> continuation degrades to a pointer line (ADR-0052: no bypass).
out=$(bsp_compose_memories 90)
echo "$out" | grep -q "CONTINUATION NEW BODY" || { echo "FAIL: continuation clipped at 90"; exit 1; }
echo "$out" | grep -q "more core memories over budget" || { echo "FAIL: no +N tail"; exit 1; }
out=$(bsp_compose_memories 40)
echo "$out" | grep -q "CONTINUATION NEW BODY" && { echo "FAIL: continuation body injected over allowance (bypass not removed)"; exit 1; }
# shellcheck disable=SC2016  # backticks are literal markdown in the asserted output, not expansions
echo "$out" | grep -q 'continuation over budget — `bd recall continuation-2026-07-07-new`' || { echo "FAIL: degraded continuation pointer line absent"; exit 1; }

# 4. pre-sweep notice when no salience headers exist
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "plain-one": "some memory body without headers",
  "plain-two": "another memory body without headers"
}
FIX
out=$(bsp_compose_memories 8192)
echo "$out" | grep -q "curation sweep" || { echo "FAIL: pre-sweep notice absent"; exit 1; }

# 5. ceiling counts BYTES, not chars: em-dash body is 30 chars but 90 bytes.
# Ceiling 60: continuation (20B, exempt) + 90B = 110 > 60 -> must be clipped
# with the +N tail (1 of 2 injected). Char-counting (20+30=50 <= 60) would
# wrongly keep it and emit no tail.
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "utf8-lesson": "@type=semantic:lesson @created=2026-07-07 @salience=5 multi-byte body",
  "continuation-2026-07-07-x": "continuation x body"
}
FIX
{ printf '—%.0s' {1..30}; echo; } > "$TMP/fixtures/recall-utf8-lesson.txt"
printf 'SHORT CONT BODY XXXX\n' > "$TMP/fixtures/recall-continuation-2026-07-07-x.txt"
out=$(bsp_compose_memories 60)
echo "$out" | grep -q "SHORT CONT BODY" || { echo "FAIL: continuation clipped in byte-ceiling test"; exit 1; }
echo "$out" | grep -q "more core memories over budget" || { echo "FAIL: multi-byte body not clipped — ceiling counted chars, not bytes"; exit 1; }
echo "$out" | grep -q "core memories: 1 of 2 injected" || { echo "FAIL: byte-test disclosure wrong"; exit 1; }

# 6. large-store pipefail regression: listing > 64KB pipe buffer with an EARLY
# @salience match. A `printf | grep -q` probe under pipefail takes SIGPIPE
# (grep -q exits at first match, printf keeps writing) -> pipeline exit 141 ->
# pre-sweep branch misfires despite curated entries. Fixture: ~246KB (2000
# filler lines of ~120B), @salience=5 on line 2 — reproduces reliably.
{
    echo '{'
    echo '  "salient-early": "@type=semantic:lesson @created=2026-07-07 @salience=5 early salient body",'
    pad=$(printf 'x%.0s' {1..80})
    for i in $(seq 1 2000); do
        printf '  "filler-%04d": "plain filler body %04d %s",\n' "$i" "$i" "$pad"
    done
    echo '  "filler-last": "plain tail body"'
    echo '}'
} > "$TMP/fixtures/memories.json"
printf 'EARLY SALIENT FULL BODY\n' > "$TMP/fixtures/recall-salient-early.txt"
out=$(bsp_compose_memories 8192)
echo "$out" | grep -q "curation sweep" && { echo "FAIL: pre-sweep misfired on large store (pipefail SIGPIPE)"; exit 1; }
echo "$out" | grep -q "EARLY SALIENT FULL BODY" || { echo "FAIL: salient body absent from large-store composition"; exit 1; }

# 7. false-match regression: a body mention of @salience must NOT drive selection —
# only the @type=… header run counts. The `\n` in the fixture is the two-char escape
# bd uses to encode the header/body newline.
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "hdr3-body5": "@type=semantic:design @created=2026-07-08 @salience=3 header\nthis body discusses @salience=5 in prose",
  "hdr4-body2": "@type=semantic:lesson @created=2026-07-08 @salience=4 header\nbody mentions @salience=2 only"
}
FIX
sel=$(bd memories --json | bsp_select_memory_keys)
echo "$sel" | grep -q "hdr3-body5" && { echo "FAIL: body @salience=5 false-selected a salience-3 header"; exit 1; }
echo "$sel" | grep -q "4	hdr4-body2" || { echo "FAIL: salience-4 header not selected when body mentions salience=2"; exit 1; }

# 8. graduated nudge: curated store above BSP_MEM_NUDGE_AT emits a curator nudge
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "keep-lesson": "@type=semantic:lesson @created=2026-07-08 @salience=5 body"
}
FIX
printf 'KEEP\n' > "$TMP/fixtures/recall-keep-lesson.txt"
out=$(BSP_MEM_NUDGE_AT=1 bsp_compose_memories 8192)   # total_count=1 >= 1 -> nudge
echo "$out" | grep -qi "memory-curator" || { echo "FAIL: size-nudge absent above threshold"; exit 1; }
out=$(BSP_MEM_NUDGE_AT=999 bsp_compose_memories 8192)  # below threshold -> no nudge
echo "$out" | grep -qi "run the memory-curator" && { echo "FAIL: nudged below threshold"; exit 1; }

# 8b. escalation tier: count >= BSP_MEM_ESCALATE_AT -> file-a-bead directive,
#     tier-1 line suppressed (tiers never stack — ADR-0052)
out=$(BSP_MEM_NUDGE_AT=1 BSP_MEM_ESCALATE_AT=1 bsp_compose_memories 8192)
echo "$out" | grep -q "file ONE chore bead" || { echo "FAIL: escalation directive absent at threshold"; exit 1; }
echo "$out" | grep -q "consolidate/route" && { echo "FAIL: tiers stacked"; exit 1; }
out=$(BSP_MEM_NUDGE_AT=1 BSP_MEM_ESCALATE_AT=999 bsp_compose_memories 8192)
echo "$out" | grep -q "file ONE chore bead" && { echo "FAIL: directive fired below escalate threshold"; exit 1; }
echo "$out" | grep -q "consolidate/route" || { echo "FAIL: tier-1 nudge lost"; exit 1; }

# 10. escalation fires on the uncurated (pre-sweep) path too — backlog is backlog
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "plain-a": "uncurated body a",
  "plain-b": "uncurated body b"
}
FIX
out=$(BSP_MEM_ESCALATE_AT=2 bsp_compose_memories 8192)
echo "$out" | grep -q "file ONE chore bead" || { echo "FAIL: directive absent on pre-sweep path"; exit 1; }

# 9. scaffolding-accurate accounting: body alone fits the ceiling, full section
#    "### pad-lesson\n"(15) + 49 + "\n\n"(2) = 66B (command substitution strips the
#    file's trailing newline -> body is 49B). Ceiling 60: body-only accounting
#    (49 <= 60) would wrongly inject; section accounting (66 > 60) clips.
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "pad-lesson": "@type=semantic:lesson @created=2026-07-09 @salience=5 pad body"
}
FIX
{ printf 'y%.0s' {1..49}; echo; } > "$TMP/fixtures/recall-pad-lesson.txt"
out=$(bsp_compose_memories 60)
echo "$out" | grep -q "yyyy" && { echo "FAIL: section over ceiling injected — accounting ignores scaffolding"; exit 1; }
echo "$out" | grep -q "core memories: 0 of 1 injected" || { echo "FAIL: scaffolding-test disclosure wrong"; exit 1; }

echo "PASS: composer selection/ceiling"
