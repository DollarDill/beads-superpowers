#!/usr/bin/env bash
# assert-opencode.sh — Tier A: OpenCode skills + TS plugin + round-trip.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup opencode
trap 'shape_sandbox_teardown' EXIT
shape_install

assert_all_skills "$SANDBOX/.config/opencode/skills"
assert_file "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
assert_in_log "OpenCode: installed"
assert_shims_never_invoked

shape_uninstall
assert_no_file "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
assert_no_file "$SANDBOX/.config/opencode/skills/using-superpowers/SKILL.md"

shape_sandbox_teardown
fail_count
