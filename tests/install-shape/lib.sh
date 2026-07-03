#!/usr/bin/env bash
# lib.sh — shared helpers for the install-shape suite. Sourced, not executed.
# Proves artifacts land where each harness expects — does NOT prove hooks fire.
# SHAPE_REPO_ROOT override exists for selftest.sh (guard-the-guards mutations).
set -uo pipefail

REPO_ROOT="${SHAPE_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# Yardstick for assert_all_skills — decoupled from the install source so selftest.sh
# can install from a mutated copy while comparing against the real checkout.
EXPECTED_SKILLS_ROOT="${SHAPE_EXPECTED_ROOT:-$REPO_ROOT}"
FAILS=0

_fail() { echo "   FAIL: $*"; FAILS=$((FAILS + 1)); }
_pass() { echo "   ok:   $*"; }
fail_count() { return "$FAILS"; }

# shape_sandbox_setup <binary>... — fresh sandbox HOME + shims for the named binaries.
shape_sandbox_setup() {
  SANDBOX=$(mktemp -d)
  SHIM_DIR="$SANDBOX/.shims"
  MARKER_DIR="$SANDBOX/.markers"
  bash "$REPO_ROOT/tests/install-shape/fixtures/make-shims.sh" "$SHIM_DIR" "$MARKER_DIR" "$@"
  # install.sh's setup_hooks hard-depends on python3; the restricted PATH below could
  # starve it on hosts where python3 lives outside /usr/bin (mise, brew, macOS).
  # Pin the host-resolved interpreter into the shim dir (stress-test plan-B1).
  ln -sf "$(command -v python3)" "$SHIM_DIR/python3"
  # Minimal PATH: shims + system dirs. Deliberately excludes the user's real PATH
  # so a real claude/codex/npx on this machine can't leak into detection.
  SANDBOX_PATH="$SHIM_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
}

shape_sandbox_teardown() { rm -rf "$SANDBOX"; }

# shape_install [extra-flags...] — run the local-source install inside the sandbox.
shape_install() {
  HOME="$SANDBOX" BEADS_SUPERPOWERS_SKILLS_DIR="$SANDBOX/skills" PATH="$SANDBOX_PATH" \
    bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" "$@" > "$SANDBOX/install.log" 2>&1
  INSTALL_RC=$?
  [ "$INSTALL_RC" -eq 0 ] || { _fail "install.sh exited $INSTALL_RC"; sed -n '1,25p' "$SANDBOX/install.log"; }
}

shape_uninstall() {
  HOME="$SANDBOX" BEADS_SUPERPOWERS_SKILLS_DIR="$SANDBOX/skills" PATH="$SANDBOX_PATH" \
    bash "$REPO_ROOT/install.sh" --yes --uninstall > "$SANDBOX/uninstall.log" 2>&1 \
    || _fail "uninstall exited non-zero"
}

# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
assert_file()    { [ -f "$1" ] && _pass "file $1" || _fail "missing file: $1"; }
# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
assert_no_file() { [ ! -e "$1" ] && _pass "absent $1" || _fail "should not exist: $1"; }
# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
assert_dir()     { [ -d "$1" ] && _pass "dir $1" || _fail "missing dir: $1"; }

# assert_json <file> <python-expr over parsed json bound to d>
assert_json() {
  local f="$1" expr="$2"
  if python3 -c "import json,sys; d=json.load(open('$f')); sys.exit(0 if ($expr) else 1)" 2>/dev/null; then
    _pass "json $f :: $expr"
  else
    _fail "json assertion failed on $f :: $expr"
  fi
}

# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
assert_in_log()     { grep -qF -- "$1" "$SANDBOX/install.log" && _pass "log has: $1" || _fail "log missing: $1"; }
# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
assert_not_in_log() { grep -qF -- "$1" "$SANDBOX/install.log" && _fail "log should NOT have: $1" || _pass "log lacks: $1"; }

# Every skill dir in the checkout must be installed (ground truth = ls skills/).
assert_all_skills() {
  local target="$1" s d
  for d in "$EXPECTED_SKILLS_ROOT"/skills/*/; do
    s=$(basename "$d")
    [ -d "$target/$s" ] || _fail "skill not installed in $target: $s"
  done
  _pass "all checkout skills present in $target"
}

# Shims must be detected, never executed (--source bypasses Tiers 1-2).
assert_shims_never_invoked() {
  local m
  if compgen -G "$MARKER_DIR/*.invoked" > /dev/null; then
    for m in "$MARKER_DIR"/*.invoked; do _fail "shim was executed: $(basename "$m" .invoked)"; done
  else
    _pass "no shim was ever executed"
  fi
}
