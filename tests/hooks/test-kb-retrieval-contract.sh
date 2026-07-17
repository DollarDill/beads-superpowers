#!/usr/bin/env bash
# tests/hooks/test-kb-retrieval-contract.sh — pins the bd behaviors the beads-native
# KB store (ADR-0056) depends on. Runs against a SCRATCH bd DB (mktemp -d, outside the
# repo tree) — never the real, Dolt-synced store. A future `bd` upgrade that regresses
# any of the 9 pinned behaviors below must fail THIS test, not silently break the store.
set -euo pipefail

# Visible SKIP when bd is absent (matches the node/shellcheck SKIP convention) —
# run-hook-tests.sh treats a non-zero exit as FAIL, so guard rather than fail.
command -v bd >/dev/null 2>&1 || { echo "SKIP (bd not installed)"; exit 0; }

T=$(mktemp -d)
trap 'rm -rf "$T" 2>/dev/null || true' EXIT
bde() { bd -C "$T" "$@"; }

# Assertion idiom: capture-then-grep — `out=$(bde ...)` then `printf '%s' "$out" | grep -q`.
# NEVER `bde ... | grep -q` on a live pipe: grep -q exits at first match, bd's remaining
# writes (bodies, footer lines) hit the closed pipe, and `set -o pipefail` turns correct
# output into a false FAIL — and on negative assertions into a false PASS (captured
# lesson `lesson-producer-grep-q-pattern-under-set-o`, bead sq23, refixed here 2026-07-17).

# --skip-agents --skip-hooks: no CLAUDE.md/AGENTS.md/git-hooks scaffolding in the
# scratch dir — this test only needs a working embedded-Dolt bd DB, nothing else.
# `bd init` must run via `cd` (subshell), NOT `bd -C <dir> init` — `-C` requires an
# EXISTING beads project to change into, so it can't bootstrap a new one (verified:
# `bd -C <empty-dir> init` fails with "no beads project found").
( cd "$T" && bd init -p kbtest --non-interactive --skip-agents --skip-hooks -q >/dev/null ) \
  || { echo "FAIL: setup — bd init failed in scratch dir (rig broken, not a bd regression)"; exit 1; }

BDVER=$(bd version)

# --- fixture: one deferred knowledge-bead, labeled kb + a topic label ---
id=$(bde create "positioning decision sample" -t decision -l kb,positioning --defer 2099-01-01 --silent)

# body-carrying fixture for behaviors 6-8: keyword exists ONLY in the description
bodyid=$(printf '%s' "distilled summary with body-only marker zzqxprobe for retrieval pinning" \
  | bde create "flatlong fixture sample" -t decision -l kb,retrieval --defer 2099-01-01 --body-file - --silent)

# 1. Label query: `bd list --label <topic> --status all` returns the deferred bead.
out1=$(bde list --label positioning --status all)
printf '%s' "$out1" | grep -q "$id" \
  || { echo "FAIL: label query did not return $id"; exit 1; }
echo "PASS (1/5): label query finds deferred knowledge-bead"

# 2. Ready-hidden: a deferred knowledge-bead is NOT in `bd ready`.
out2=$(bde ready)
printf '%s' "$out2" | grep -q "$id" && { echo "FAIL: deferred bead $id appeared in bd ready"; exit 1; }
echo "PASS (2/5): deferred knowledge-bead hidden from bd ready"

# 3. GC-safety — TWO-SIDED (Branch 7, the crux). `bd gc --dry-run` (verified against
# `bd gc --help` and its --json output) reports only an aggregate per-phase COUNT for
# the decay phase, never per-issue IDs — so an ID-grep over the decay listing (as the
# task-5 pseudocode sketched) is not the real interface. The discriminating check is
# built on controlled cardinality instead: with only the deferred bead in the DB, the
# decay count must be exactly 0; after closing exactly one control bead, it must become
# exactly 1 (not 0 — the closed control must be swept; not 2 — the deferred bead must
# not be). No `|| true` anywhere near these two assertions.
decay_count() {
  # Aggregate decay count from `bd gc --dry-run`. bd always prints a "Decay: <n>" line;
  # if that format ever changes, emit a clear FAIL (on stderr, so it survives $()
  # capture) instead of letting set -e abort the script with no diagnostic.
  local out num
  out=$(bde gc --dry-run --older-than 0 --skip-dolt 2>&1)
  num=$(printf '%s\n' "$out" | grep -oE 'Decay: [0-9]+' | grep -oE '[0-9]+') || num=""
  if [ -z "$num" ]; then
    printf 'FAIL: could not parse "Decay: <n>" from bd gc output (interface changed?):\n%s\n' "$out" >&2
    return 2
  fi
  printf '%s\n' "$num"
}

# "before" side (deterministic, non-racy): only the never-closed deferred bead exists,
# so nothing is decay-eligible — the count MUST be 0. This proves the deferred bead is
# GC-safe on its own, independent of any timing.
before=$(decay_count)
[ "$before" = "0" ] \
  || { echo "FAIL: decay set non-empty before any closed bead exists (got $before, want 0) — deferred bead is leaking into GC"; exit 1; }

# "after" side: close exactly one control bead, then POLL until the decay set reflects
# it. `--older-than 0` uses a second-granularity cutoff evaluated at gc-run time, so a
# bead closed in the same wall-clock second is not yet "older than 0 days" — a fixed
# `sleep 1` races that boundary (measured ~15-20% false-0). The poll waits for the
# cutoff to roll over instead of assuming a fixed margin is always enough:
#   count == 1  -> success: closed control decayed, deferred did NOT (break)
#   count  > 1  -> FAIL NOW: the deferred bead leaked into the decay set — the exact
#                  regression this two-sided check exists to catch; never keep polling
#   count == 0  -> the cutoff second has not rolled over yet; keep polling
#   timeout     -> FAIL: closed control never entered the decay set
closed=$(bde create "closed control" -t task --silent)
bde close "$closed" --reason ctl >/dev/null
after=""
for _ in $(seq 1 20); do   # ~20 * 0.25s = 5s bound
  n=$(decay_count)
  if [ "$n" = "1" ]; then after=1; break; fi
  if [ "$n" -gt 1 ]; then
    echo "FAIL: deferred bead leaked into the decay set (decay count=$n, want 1) — GC-safety regression"; exit 1
  fi
  sleep 0.25
done
[ "$after" = "1" ] \
  || { echo "FAIL: closed control never entered the decay set within ~5s — decay/GC interface regressed"; exit 1; }
echo "PASS (3/5): GC-safety two-sided (before=0, after=1 via bounded poll) — deferred bead survives decay, closed control does not"

# 4. Supersede: `bd supersede <old> --with <new>` CLOSES + links the old bead, and it
# stays queryable via --status all (the KB store's supersede-then-decay lifecycle).
new=$(bde create "positioning reconsider" -t decision -l kb,positioning --defer 2099-01-01 --silent)
bde supersede "$id" --with "$new" >/dev/null
# 4a. old bead is actually CLOSED, not merely linked. `--status all` would also match an
# open/deferred bead, so a regression where supersede stops closing (but still links)
# must fail here. `list --id <old> --status closed` returns the bead iff its stored
# status is closed (verified: a still-deferred bead does NOT match this filter).
out4a=$(bde list --id "$id" --status closed)
printf '%s' "$out4a" | grep -q "$id" \
  || { echo "FAIL: supersede did not close old bead $id (status != closed) — supersede-then-decay lifecycle broken"; exit 1; }
# 4b. and it remains queryable via --status all (edit-in-place retrieval).
out4b=$(bde list --label positioning --status all)
printf '%s' "$out4b" | grep -q "$id" \
  || { echo "FAIL: superseded bead $id no longer queryable via --status all"; exit 1; }
echo "PASS (4/5): supersede closes old bead + links; still queryable via --status all"

# 5. Search: `bd search <kw> --status all` finds the bead by keyword.
out5=$(bde search "positioning decision" --status all)
printf '%s' "$out5" | grep -q "$id" \
  || { echo "FAIL: search did not find $id"; exit 1; }
echo "PASS (5/5): search finds knowledge-bead by keyword"

# 6. Fused read: `bd list --flat --long` prints the description body inline
# (tree mode suppresses --long — the skills document the --flat form).
out6=$(bde list --label retrieval --status all --flat --long)
printf '%s' "$out6" | grep -q "zzqxprobe" \
  || { echo "FAIL: list --flat --long did not print the description body"; exit 1; }
echo "PASS (6/9): list --flat --long emits full bodies"

# 7. Body recall two-sided: list --desc-contains finds a body-only keyword;
# search (title-only) must NOT — if search becomes body-aware, simplify the
# skill text and re-pin.
out7a=$(bde list --label kb --status all --desc-contains "zzqxprobe")
printf '%s' "$out7a" | grep -q "$bodyid" \
  || { echo "FAIL: list --desc-contains missed the body-only keyword"; exit 1; }
out7b=$(bde search "zzqxprobe" --status all)
if printf '%s' "$out7b" | grep -q "$bodyid"; then
  echo "FAIL: bd search matched a body-only keyword — search is no longer title-only; update skill text + this pin"; exit 1
fi
echo "PASS (7/9): --desc-contains body recall + search title-only limitation"

# 8. Batch read: multi-id `bd show` returns both bodies in one call.
shown=$(bde show "$id" "$bodyid")
printf '%s' "$shown" | grep -q "positioning decision sample" \
  || { echo "FAIL: multi-id bd show missing first bead"; exit 1; }
printf '%s' "$shown" | grep -q "zzqxprobe" \
  || { echo "FAIL: multi-id bd show missing second bead's body"; exit 1; }
echo "PASS (8/9): multi-id bd show returns all requested bodies"

# 9. Memory round-trip: `bd remember` -> `bd recall <key>` returns FULL text
# (bd memories prints truncated previews; recall is the read path skills document).
memout=$(bde remember "lesson probe: recall-roundtrip-full-text zzqxmem end-marker" 2>&1)
# Capture-first parse (same idiom, same reason): a zero-match grep must reach the
# FAIL diagnostic below, not abort the script via pipefail before it fires.
memtoks=$(printf '%s' "$memout" | grep -oE '\[[^]]+\]') || memtoks=""
memkey=$(printf '%s\n' "$memtoks" | head -1 | tr -d '[]')
[ -n "$memkey" ] || { echo "FAIL: could not parse memory key from bd remember output: $memout"; exit 1; }
out9=$(bde recall "$memkey")
printf '%s' "$out9" | grep -q "zzqxmem end-marker" \
  || { echo "FAIL: bd recall did not return the full memory text"; exit 1; }
echo "PASS (9/9): bd remember -> bd recall full-text round-trip"

echo "PASS: KB retrieval contract — all 9 behaviors pinned [$BDVER]"
