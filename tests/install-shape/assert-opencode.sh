#!/usr/bin/env bash
# assert-opencode.sh — Tier A: OpenCode skills + TS plugin + round-trip.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup opencode
trap 'shape_sandbox_teardown' EXIT
# shellcheck disable=SC2119  # bare call intentional — no extra install flags for this harness
shape_install

assert_all_skills "$SANDBOX/.config/opencode/skills"
assert_file "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
# Canonical hook must be reachable by the TS plugin's exec target (bead 7bod):
# present at the OpenCode root, executable, bash shebang intact.
OC_HOOK="$SANDBOX/.config/opencode/hooks/session-start"
assert_file "$OC_HOOK"
# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
[ -x "$OC_HOOK" ] && _pass "executable $OC_HOOK" || _fail "hook not executable: $OC_HOOK"
# shellcheck disable=SC2015  # _pass/_fail always succeed, so A && B || C can't misfire
[ "$(head -n1 "$OC_HOOK" 2>/dev/null)" = "#!/usr/bin/env bash" ] && _pass "bash shebang on hook" || _fail "hook missing bash shebang"
assert_in_log "OpenCode: installed"
assert_shims_never_invoked

shape_uninstall
assert_no_file "$SANDBOX/.config/opencode/plugins/beads-superpowers-plugin.ts"
assert_no_file "$SANDBOX/.config/opencode/hooks/session-start"
assert_no_file "$SANDBOX/.config/opencode/skills/using-superpowers/SKILL.md"

shape_sandbox_teardown
fail_count
