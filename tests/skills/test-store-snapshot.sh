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
TMP2="$(mktemp -d)"           # a SECOND real store — assertion 7's containment control
EMPTY="$(mktemp -d)"          # no store, ever — assertion 4's subject
STUB="$(mktemp -d)"           # a fake `bd` on PATH — assertion 8's environment probe
trap 'rm -rf "$TMP" "$TMP2" "$EMPTY" "$STUB"' EXIT
( cd "$TMP" && bd init --non-interactive --prefix snaptest >/dev/null 2>&1 ) \
  || { echo "FAIL: scratch bd init failed"; exit 1; }
# bd auto-discovers .beads/ UP the tree, so prove the store is local BEFORE writing:
# "no foreign store is touched" is load-bearing for this whole plan, and this task
# writes (remember/create). Same guard Task 1's shim test carries.
[ -d "$TMP/.beads" ] || { echo "FAIL: scratch store not created in \$TMP"; exit 1; }
( cd "$TMP" && bd remember "original body about dolt remotes" --key snap-key >/dev/null )
( cd "$TMP" && bd create "a task" -t task -p 2 >/dev/null )

# ── 1. stable when nothing changes
set +e
a="$( bash "$SNAP" "$TMP" )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: snapshot of \$TMP exited $rc unexpectedly"; exit 1; }
set +e
b="$( bash "$SNAP" "$TMP" )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: second snapshot of \$TMP exited $rc unexpectedly"; exit 1; }
[ "$a" = "$b" ] || { echo "FAIL: snapshot unstable across two reads"; printf '%s\n%s\n' "$a" "$b"; exit 1; }
grep -qE '^issues=[0-9a-f]{64} memories=[0-9a-f]{64}$' <<<"$a" \
  || { echo "FAIL: snapshot format wrong: $a"; exit 1; }

# ── 2a. PIN THE ENVELOPE (stress-test B4). `bd memories --json` is an OBJECT of
# key->body PLUS a `schema_version` key, so a bare `jq length` overcounts by one.
# Asserting our de-enveloped count against bd's OWN header count means a future bd
# that adds a SECOND envelope key fails here, loudly, instead of silently skewing
# every snapshot from then on.
set +e
hdr="$( cd "$TMP" && bd memories 2>/dev/null | sed -n '1s/.*(\([0-9]\+\)).*/\1/p' )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: could not capture bd's own memories header count (rc=$rc)"; exit 1; }
set +e
dee="$( cd "$TMP" && bd memories --json | jq 'del(.schema_version) | length' )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: could not capture de-enveloped memories count (rc=$rc)"; exit 1; }
if [ -z "$hdr" ] || [ "$hdr" != "$dee" ]; then
  echo "FAIL: de-enveloped count ($dee) != bd's own header count ($hdr) — bd's --json envelope changed shape"; exit 1
fi

# ── 2b. THE LOAD-BEARING CASE: in-place overwrite, count unchanged, hash must move
count_before="$dee"
( cd "$TMP" && bd remember "REPLACED body about git origin" --key snap-key >/dev/null )
set +e
count_after="$( cd "$TMP" && bd memories --json | jq 'del(.schema_version) | length' )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: could not capture post-overwrite memories count (rc=$rc)"; exit 1; }
set +e
c="$( bash "$SNAP" "$TMP" )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: post-overwrite snapshot of \$TMP exited $rc unexpectedly"; exit 1; }
[ "$count_before" = "$count_after" ] \
  || { echo "FAIL: fixture invalid — overwrite changed the count, so it does not test the gap"; exit 1; }
# Pin to the memories field specifically (assertion 3 already isolates its own
# field the same way) — comparing whole lines would pass if EITHER hash moved,
# so a future write that also touched an issue row could mask a broken memories
# hash here.
[ "${a#* }" != "${c#* }" ] \
  || { echo "FAIL: in-place memory overwrite did NOT change the snapshot"; exit 1; }

# ── 2c. Cross-check: the helper's memories= field must equal an independently
# recomputed digest of the same raw content. Without this, deleting the helper's
# `del(.schema_version)` step would go undetected — schema_version is constant
# across this fixture, so every other assertion here stays green either way.
set +e
raw_memories_after="$( cd "$TMP" && bd memories --json 2>/dev/null )"
rc=$?
set -e
if [ "$rc" -ne 0 ] || [ -z "$raw_memories_after" ]; then
  echo "FAIL: could not capture raw memories for the cross-check (rc=$rc)"; exit 1
fi
expected_memories="$( printf '%s' "$raw_memories_after" | jq -S 'del(.schema_version)' | sha256sum | cut -d' ' -f1 )"
actual_memories="${c#*memories=}"
[ "$expected_memories" = "$actual_memories" ] \
  || { echo "FAIL: helper memories= field ($actual_memories) != independently recomputed digest ($expected_memories)"; exit 1; }

# ── 3. an issue write moves the issues hash
( cd "$TMP" && bd create "another task" -t task -p 2 >/dev/null )
set +e
d="$( bash "$SNAP" "$TMP" )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: post-issue-write snapshot of \$TMP exited $rc unexpectedly"; exit 1; }
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
set +e
err="$( bash "$SNAP" "$EMPTY" 2>&1 >/dev/null )"
rc=$?
set -e
# A bare non-zero check cannot distinguish exit 4 (the guard firing) from exit 2,
# exit 3, or a syntax error in the helper — pin to the guard's specific exit code
# and its stderr marker, same signature discipline as the Task 1 shim test.
[ "$rc" -eq 4 ] \
  || { echo "FAIL: storeless dir exited $rc, not the helper's 4 — cannot tell the guard from a different failure"; exit 1; }
grep -q 'no reachable store' <<<"$err" \
  || { echo "FAIL: storeless dir lacked the 'no reachable store' message: $err"; exit 1; }

# `BEADS_DB` names the database directory INSIDE a store. Derive it from the scratch
# store and fail loudly if bd's layout ever moves: a path that does not exist would
# make assertions 6-8 pass vacuously, which is the failure mode this whole file exists
# to stamp out.
FOREIGN_DB="$TMP/.beads/embeddeddolt"
[ -d "$FOREIGN_DB" ] \
  || { echo "FAIL: fixture invalid — no db dir at $FOREIGN_DB, so the redirect probes prove nothing"; exit 1; }

# ── 5. AN INHERITED BEADS_DIR MUST NOT REDIRECT THE HELPER TO A FOREIGN STORE.
# An inherited BEADS_DIR is the exact false-clean this backstop exists to prevent,
# arriving via environment instead of via hash-ordering: it must fail exactly like
# assertion 4, not silently resolve to $TMP's store while $EMPTY is the argument.
# Pinned to rc 4 plus the stderr marker for the same reason assertion 4 is — a bare
# non-zero check cannot tell the containment guard from a typo in the helper.
set +e
err="$( BEADS_DIR="$TMP/.beads" bash "$SNAP" "$EMPTY" 2>&1 >/dev/null )"
rc=$?
set -e
[ "$rc" -eq 4 ] \
  || { echo "FAIL: BEADS_DIR + storeless dir exited $rc, not the helper's 4 — cannot tell the guard from a different failure"; exit 1; }
grep -q 'no reachable store' <<<"$err" \
  || { echo "FAIL: BEADS_DIR + storeless dir lacked the 'no reachable store' message: $err"; exit 1; }

# ── 6. NOR MUST BEADS_DB. A round of fixes closed BEADS_DIR by name and this variable
# reopened the identical false-clean: exit 0, a foreign store's hashes for a directory
# holding no store at all, byte-stable across consecutive reads. The caller's decision
# rule is "hash delta -> floor breach, stop" and "no delta -> proceed", so that reads
# as a permanent all-clear on the containment backstop itself.
set +e
err="$( BEADS_DB="$FOREIGN_DB" bash "$SNAP" "$EMPTY" 2>&1 >/dev/null )"
rc=$?
set -e
[ "$rc" -eq 4 ] \
  || { echo "FAIL: BEADS_DB + storeless dir exited $rc, not the helper's 4 — cannot tell the guard from a different failure"; exit 1; }
grep -q 'no reachable store' <<<"$err" \
  || { echo "FAIL: BEADS_DB + storeless dir lacked the 'no reachable store' message: $err"; exit 1; }

# ── 7. CONTAINMENT WHERE IT ACTUALLY BITES: an argument that DOES own a store.
# Assertions 5-6 pass a storeless directory, which a bare "$dir/.beads must exist"
# precondition satisfies on its own without constraining store resolution at all.
# This one cannot be satisfied that way: $TMP2 owns a store, so the helper reaches its
# `bd` reads either way and the only question left is WHICH store answered them. The
# answer must be $TMP2's, whatever the ambient environment claims.
( cd "$TMP2" && bd init --non-interactive --prefix snaptest2 >/dev/null 2>&1 ) \
  || { echo "FAIL: second scratch bd init failed"; exit 1; }
[ -d "$TMP2/.beads" ] || { echo "FAIL: second scratch store not created in \$TMP2"; exit 1; }
( cd "$TMP2" && bd remember "second store body about worktrees" --key snap2-key >/dev/null )
( cd "$TMP2" && bd create "a second-store task" -t task -p 2 >/dev/null )
set +e
plain2="$( bash "$SNAP" "$TMP2" )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: snapshot of \$TMP2 exited $rc unexpectedly"; exit 1; }
# Fixture validity: the two scratch stores must be distinguishable, or "unchanged
# under redirection" would hold trivially and assertion 7 would prove nothing.
[ "$plain2" != "$d" ] \
  || { echo "FAIL: fixture invalid — the two scratch stores hash identically"; exit 1; }
set +e
redir2="$( BEADS_DIR="$TMP/.beads" BEADS_DB="$FOREIGN_DB" bash "$SNAP" "$TMP2" )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: redirected snapshot of \$TMP2 exited $rc unexpectedly"; exit 1; }
[ "$redir2" = "$plain2" ] \
  || { echo "FAIL: the environment changed the snapshot of a store-owning dir: $redir2 != $plain2"; exit 1; }

# ── 8. THE MECHANISM, NOT A LIST OF NAMES. Assertions 5-7 name the variables that
# exist TODAY, and a guard that enumerates names silently stops guarding the moment bd
# adds another one — exactly how BEADS_DB slipped past a fix that had just closed
# BEADS_DIR. So probe the property itself: stand a fake `bd` on PATH that records every
# ambient variable that reached it, and require that set to be EMPTY. BSPPROBE_FUTURE_VAR
# stands in for the variable a future bd has not invented yet: no enumeration can
# contain a name nobody knows, so only a scrub-everything mechanism keeps this green.
DUMP="$STUB/leaked-env.txt"
cat > "$STUB/bd" <<'STUBSH'
#!/usr/bin/env bash
# Records which ambient variables survived into `bd`'s environment, then fails, so
# the caller also exercises its no-reachable-store path.
env | sed -n 's/^\(BEADS_[A-Z0-9_]*\|BSPPROBE_[A-Z0-9_]*\)=.*/\1/p' \
  >> "$(dirname "$0")/leaked-env.txt"
exit 1
STUBSH
chmod 755 "$STUB/bd"

# Guard the guard: an empty $DUMP proves nothing unless the probe records when nothing
# is scrubbing it. Establish that it does BEFORE reading emptiness as containment.
: > "$DUMP"
set +e
( cd "$TMP2" && BEADS_DB="$FOREIGN_DB" BSPPROBE_FUTURE_VAR=1 PATH="$STUB:$PATH" bd list >/dev/null 2>&1 )
set -e
[ -s "$DUMP" ] \
  || { echo "FAIL: fixture invalid — the env probe recorded nothing even unscrubbed, so assertion 8 cannot fail"; exit 1; }

: > "$DUMP"
set +e
BEADS_DIR="$TMP/.beads" BEADS_DB="$FOREIGN_DB" BSPPROBE_FUTURE_VAR=1 \
  PATH="$STUB:$PATH" bash "$SNAP" "$TMP2" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 4 ] \
  || { echo "FAIL: with a stub bd that returns nothing, the helper exited $rc, not the guard's 4"; exit 1; }
leaked="$( sort -u "$DUMP" | tr '\n' ' ' )"
[ -z "$leaked" ] \
  || { echo "FAIL: ambient variables reached bd: $leaked"; exit 1; }

# ── 9. THE NARROWED CONTRACT, PINNED. The helper documents its argument as the store
# ROOT and enforces it by requiring $dir/.beads. Drop that requirement and `bd` walks UP
# the tree, so a subdirectory reports the PARENT project's store under the
# subdirectory's name — the same false attribution as an environment redirect, reached
# through the filesystem instead of the environment. A caller holding a subdirectory has
# to be told so, not quietly answered from a store it did not name.
mkdir -p "$TMP2/sub"
set +e
err="$( bash "$SNAP" "$TMP2/sub" 2>&1 >/dev/null )"
rc=$?
set -e
[ "$rc" -eq 4 ] \
  || { echo "FAIL: a subdirectory of a store-owning dir exited $rc, not the helper's 4 — it answered from a store it was not asked about"; exit 1; }
grep -q 'no reachable store' <<<"$err" \
  || { echo "FAIL: subdirectory case lacked the 'no reachable store' message: $err"; exit 1; }

# Counting rule, unchanged since this file was written: every failure site, minus the 5
# fixture-CONSTRUCTION checks ($SNAP missing, plus each scratch store's `bd init` and
# local-store guard). Recount with `grep -c 'FAIL' + colon` over this file: 36 - 5 = 31.
# No comment here may contain that literal marker, or the recount inflates.
echo "PASS: test-store-snapshot (31 assertions)"
