#!/usr/bin/env bash
# assert-opencode.sh — Tier A: OpenCode is git-install only (see .opencode/INSTALL.md).
# Fresh install must write NO OpenCode artifacts; --uninstall must still clean up
# artifacts a pre-0.12 installer copied (legacy round-trip).
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup opencode
trap 'shape_sandbox_teardown' EXIT
# shellcheck disable=SC2119  # bare call intentional — no extra install flags for this harness
shape_install

# Fresh install: no OpenCode artifacts written by this script anymore.
assert_no_file "$SANDBOX/.config/opencode/plugins/beads-superpowers.js"
assert_no_file "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
assert_no_file "$SANDBOX/.config/opencode/skills/using-superpowers/SKILL.md"
assert_no_file "$SANDBOX/.config/opencode/hooks/session-start"
assert_shims_never_invoked

# Legacy round-trip: pre-seed artifacts a pre-0.12 install.sh would have copied,
# then run --uninstall and assert they are all removed.
mkdir -p "$SANDBOX/.config/opencode/plugins" "$SANDBOX/.config/opencode/skills/using-superpowers" "$SANDBOX/.config/opencode/hooks"
touch "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
touch "$SANDBOX/.config/opencode/skills/using-superpowers/SKILL.md"
touch "$SANDBOX/.config/opencode/hooks/session-start"

shape_uninstall
assert_no_file "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
assert_no_file "$SANDBOX/.config/opencode/skills/using-superpowers/SKILL.md"
assert_no_file "$SANDBOX/.config/opencode/hooks/session-start"

shape_sandbox_teardown
fail_count
