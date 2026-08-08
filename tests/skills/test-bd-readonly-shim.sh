#!/usr/bin/env bash
# tests/skills/test-bd-readonly-shim.sh — run: bash tests/skills/test-bd-readonly-shim.sh
#
# The shim is the MECHANISM behind spec §5.3: prompts forbidding writes are model
# compliance, and no before/after snapshot can detect `bd dolt push` because a push
# changes no local state. CLAUDE.md records the reproduced consequence — zero-remote
# push silently adopts git origin (ADR-0057).
#
# Default-deny is asserted explicitly: allowlist guards have a silent-escape class
# where an unregistered item is never CHECKED rather than FAILED
# (lesson-allowlist-driven-guards-have-a-silent-escape). A made-up verb is the
# completeness assertion.
set -euo pipefail
command -v bd >/dev/null 2>&1 || { echo "SKIP: test-bd-readonly-shim (bd absent)"; exit 0; }

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SHIM_DIR="$REPO/tests/skills/helpers/bd-readonly"
[ -x "$SHIM_DIR/bd" ] || { echo "FAIL: $SHIM_DIR/bd missing or not executable"; exit 1; }

unset BEADS_DIR
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
( cd "$TMP" && bd init --non-interactive --prefix shimtest >/dev/null 2>&1 ) \
  || { echo "FAIL: scratch bd init failed"; exit 1; }
# bd auto-discovers .beads/ UP the tree, so prove the store is local before writing:
# "no foreign store is touched" is load-bearing for this whole plan.
[ -d "$TMP/.beads" ] || { echo "FAIL: scratch store not created in \$TMP"; exit 1; }
( cd "$TMP" && bd remember "shim fixture body about worktree isolation" --key shim-fixture >/dev/null )

SHIMMED="$SHIM_DIR:$PATH"

# ── 1. an allowlisted verb passes through with real output
set +e
out="$( cd "$TMP" && PATH="$SHIMMED" bd memories shim-fixture 2>&1 )"
rc=$?
set -e
[ "$rc" -eq 0 ] \
  || { echo "FAIL: allowlisted 'memories' exited $rc unexpectedly"; printf '%s\n' "$out"; exit 1; }
grep -q 'worktree isolation' <<<"$out" \
  || { echo "FAIL: allowlisted 'memories' did not pass through"; printf '%s\n' "$out"; exit 1; }

# ── 2. mutating verbs are rejected BY THE SHIM, and leave the store unchanged.
#
# THE ASSERTION MUST BE SHIM-SPECIFIC (stress-test B6). A bare `rc -ne 0` check is
# an eo9z2.8-class assertion that CANNOT FAIL: most of these verbs error on their
# own merits with the shim absent — `close probe` (no such issue), `update probe`,
# `forget probe` (no such memory), `import probe` (no such file), `init` (already
# initialised). Only `remember` and `create` would genuinely succeed unshimmed, so a
# non-zero check stays green with the shim DELETED. Exit 64 plus the REJECTED marker
# are signatures only the shim produces.
set +e
before="$( cd "$TMP" && bd memories --json | sha256sum )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: could not snapshot store state before the rejection loop (rc=$rc)"; exit 1; }
for verb in remember create close update import forget init; do
  set +e
  err="$( cd "$TMP" && PATH="$SHIMMED" bd "$verb" "probe" 2>&1 >/dev/null )"
  rc=$?
  set -e
  [ "$rc" -eq 64 ] \
    || { echo "FAIL: 'bd $verb' exited $rc, not the shim's 64 — cannot tell shim rejection from bd's own error"; exit 1; }
  grep -q 'bd-readonly: REJECTED' <<<"$err" \
    || { echo "FAIL: 'bd $verb' lacked the shim's REJECTED marker on stderr"; printf '%s\n' "$err"; exit 1; }
done
set +e
after="$( cd "$TMP" && bd memories --json | sha256sum )"
rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL: could not snapshot store state after the rejection loop (rc=$rc)"; exit 1; }
[ "$before" = "$after" ] || { echo "FAIL: store mutated despite rejection"; exit 1; }

# ── 3. EVERY bd dolt subcommand is rejected — this is the one snapshots cannot catch
for sub in push pull status commit remote; do
  set +e
  err="$( cd "$TMP" && PATH="$SHIMMED" bd dolt "$sub" 2>&1 >/dev/null )"
  rc=$?
  set -e
  [ "$rc" -eq 64 ] \
    || { echo "FAIL: 'bd dolt $sub' exited $rc, not the shim's 64"; exit 1; }
  grep -q 'bd-readonly: REJECTED' <<<"$err" \
    || { echo "FAIL: 'bd dolt $sub' lacked the shim's REJECTED marker"; printf '%s\n' "$err"; exit 1; }
done

# ── 4. default-deny: an unregistered verb must FAIL, not pass through unchecked
# VERIFIED 2026-08-08: unshimmed `bd frobnicate` exits 1, so a bare `-ne 0` check
# stays GREEN with the shim deleted — the one assertion written to prove default-deny
# would have proven nothing. Exit 64 + the marker are shim-only signatures.
set +e
err="$( cd "$TMP" && PATH="$SHIMMED" bd frobnicate 2>&1 >/dev/null )"
rc=$?
set -e
[ "$rc" -eq 64 ] \
  || { echo "FAIL: unknown verb exited $rc, not 64 — allowlist is not default-deny"; exit 1; }
grep -q 'bd-readonly: REJECTED' <<<"$err" \
  || { echo "FAIL: unknown verb lacked the shim's REJECTED marker"; printf '%s\n' "$err"; exit 1; }

# ── 5. 'label list-all' is allowed; 'label add' is not
# The `label` branch is the shim's ONLY sub-verb check, so it is the one piece of
# allowlist logic with a real branch to get wrong. VERIFIED 2026-08-08: unshimmed
# `bd label add x y` exits 1, so a bare `-ne 0` left that branch untested in the
# failing direction.
set +e
( cd "$TMP" && PATH="$SHIMMED" bd label list-all >/dev/null 2>&1 ); rc_ok=$?
err="$( cd "$TMP" && PATH="$SHIMMED" bd label add x y 2>&1 >/dev/null )"; rc_bad=$?
set -e
[ "$rc_ok" -eq 0 ]   || { echo "FAIL: 'bd label list-all' was rejected"; exit 1; }
[ "$rc_bad" -eq 64 ] || { echo "FAIL: 'bd label add' exited $rc_bad, not the shim's 64"; exit 1; }
grep -q 'bd-readonly: REJECTED' <<<"$err" \
  || { echo "FAIL: 'bd label add' lacked the shim's REJECTED marker"; printf '%s\n' "$err"; exit 1; }

echo "PASS: test-bd-readonly-shim (5 assertions)"
