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
( cd "$TMP" && bd remember "shim fixture body about worktree isolation" --key shim-fixture >/dev/null )

SHIMMED="$SHIM_DIR:$PATH"

# ── 1. an allowlisted verb passes through with real output
out="$( cd "$TMP" && PATH="$SHIMMED" bd memories shim-fixture 2>&1 )"
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
before="$( cd "$TMP" && bd memories --json | sha256sum )"
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
after="$( cd "$TMP" && bd memories --json | sha256sum )"
[ "$before" = "$after" ] || { echo "FAIL: store mutated despite rejection"; exit 1; }

# ── 3. EVERY bd dolt subcommand is rejected — this is the one snapshots cannot catch
for sub in push pull status commit remote; do
  set +e
  ( cd "$TMP" && PATH="$SHIMMED" bd dolt "$sub" >/dev/null 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || { echo "FAIL: 'bd dolt $sub' was NOT rejected"; exit 1; }
done

# ── 4. default-deny: an unregistered verb must FAIL, not pass through unchecked
set +e
( cd "$TMP" && PATH="$SHIMMED" bd frobnicate >/dev/null 2>&1 )
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL: unknown verb passed through — allowlist is not default-deny"; exit 1; }

# ── 5. 'label list-all' is allowed; 'label add' is not
set +e
( cd "$TMP" && PATH="$SHIMMED" bd label list-all >/dev/null 2>&1 ); rc_ok=$?
( cd "$TMP" && PATH="$SHIMMED" bd label add x y >/dev/null 2>&1 ); rc_bad=$?
set -e
[ "$rc_ok" -eq 0 ]  || { echo "FAIL: 'bd label list-all' was rejected"; exit 1; }
[ "$rc_bad" -ne 0 ] || { echo "FAIL: 'bd label add' was NOT rejected"; exit 1; }

echo "PASS: test-bd-readonly-shim (5 assertions)"
