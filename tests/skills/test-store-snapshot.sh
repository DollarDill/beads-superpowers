#!/usr/bin/env bash
# tests/skills/test-store-snapshot.sh — run: bash tests/skills/test-store-snapshot.sh
#
# Spec §5.4: the backstop hashes CONTENT, never counts. `bd remember` on an
# existing key overwrites IN PLACE and `bd forget`+`bd remember` round-trips, both
# leaving the memory COUNT unchanged — so a count-based check reports clean on a
# store that was rewritten. Demonstrated live 2026-08-08 when two `bd remember`
# calls collapsed onto one auto-derived key and the second silently replaced the first.
set -euo pipefail
command -v bd >/dev/null 2>&1 || { echo "SKIP: test-store-snapshot (bd absent)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: test-store-snapshot (jq absent)"; exit 0; }

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SNAP="$REPO/tests/skills/helpers/store-snapshot.sh"
[ -f "$SNAP" ] || { echo "FAIL: $SNAP missing"; exit 1; }

unset BEADS_DIR
TMP="$(mktemp -d)"
EMPTY="$(mktemp -d)"          # no store, ever — assertion 4's subject
trap 'rm -rf "$TMP" "$EMPTY"' EXIT
( cd "$TMP" && bd init --non-interactive --prefix snaptest >/dev/null 2>&1 ) \
  || { echo "FAIL: scratch bd init failed"; exit 1; }
# bd auto-discovers .beads/ UP the tree, so prove the store is local BEFORE writing:
# "no foreign store is touched" is load-bearing for this whole plan, and this task
# writes (remember/create). Same guard Task 1's shim test carries.
[ -d "$TMP/.beads" ] || { echo "FAIL: scratch store not created in \$TMP"; exit 1; }
( cd "$TMP" && bd remember "original body about dolt remotes" --key snap-key >/dev/null )
( cd "$TMP" && bd create "a task" -t task -p 2 >/dev/null )

# ── 1. stable when nothing changes
a="$( bash "$SNAP" "$TMP" )"
b="$( bash "$SNAP" "$TMP" )"
[ "$a" = "$b" ] || { echo "FAIL: snapshot unstable across two reads"; printf '%s\n%s\n' "$a" "$b"; exit 1; }
grep -qE '^issues=[0-9a-f]{64} memories=[0-9a-f]{64}$' <<<"$a" \
  || { echo "FAIL: snapshot format wrong: $a"; exit 1; }

# ── 2a. PIN THE ENVELOPE (stress-test B4). `bd memories --json` is an OBJECT of
# key->body PLUS a `schema_version` key, so a bare `jq length` overcounts by one.
# Asserting our de-enveloped count against bd's OWN header count means a future bd
# that adds a SECOND envelope key fails here, loudly, instead of silently skewing
# every snapshot from then on.
hdr="$( cd "$TMP" && bd memories 2>/dev/null | sed -n '1s/.*(\([0-9]\+\)).*/\1/p' )"
dee="$( cd "$TMP" && bd memories --json | jq 'del(.schema_version) | length' )"
if [ -z "$hdr" ] || [ "$hdr" != "$dee" ]; then
  echo "FAIL: de-enveloped count ($dee) != bd's own header count ($hdr) — bd's --json envelope changed shape"; exit 1
fi

# ── 2b. THE LOAD-BEARING CASE: in-place overwrite, count unchanged, hash must move
count_before="$dee"
( cd "$TMP" && bd remember "REPLACED body about git origin" --key snap-key >/dev/null )
count_after="$( cd "$TMP" && bd memories --json | jq 'del(.schema_version) | length' )"
c="$( bash "$SNAP" "$TMP" )"
[ "$count_before" = "$count_after" ] \
  || { echo "FAIL: fixture invalid — overwrite changed the count, so it does not test the gap"; exit 1; }
[ "$a" != "$c" ] \
  || { echo "FAIL: in-place memory overwrite did NOT change the snapshot"; exit 1; }

# ── 3. an issue write moves the issues hash
( cd "$TMP" && bd create "another task" -t task -p 2 >/dev/null )
d="$( bash "$SNAP" "$TMP" )"
[ "${c%% *}" != "${d%% *}" ] || { echo "FAIL: issue creation did not change the issues hash"; exit 1; }

# ── 4. A STORELESS DIRECTORY MUST FAIL, not emit a stable hash.
# VERIFIED 2026-08-08 against the pre-amendment helper: `sha256sum` of empty input is
# always 64 hex chars, so a `[ -n "$issues" ]` test AFTER hashing can never be false —
# the guard was dead and the helper returned exit 0 with
# issues=e3b0c442…b855 memories=e3b0c442…b855 for a directory with no store at all.
# Two such calls compare byte-identical, which every caller reads as CLEAN. Since the
# caller's decision rule is "hash delta -> floor breach, stop" and "no delta -> proceed",
# a misresolved store read as a permanent all-clear on the containment backstop.
# Guarding the RAW output before hashing is what makes this assertion able to fail.
# The empty-but-reachable store is NOT this case: a fresh `bd init` yields `[]` and
# `{"schema_version": 1}` — both non-empty, so a legitimately empty store still snapshots.
if out="$( bash "$SNAP" "$EMPTY" 2>/dev/null )"; then
  echo "FAIL: storeless dir exited 0 and emitted: $out"; exit 1
fi

echo "PASS: test-store-snapshot (7 assertions)"
