#!/usr/bin/env bash
# assert-combo.sh — all 11 harnesses detected in one run; every hint prints; no shim executes.
# NOTE: the shim list below must stay in sync with tier-b.tsv, which the hint loop reads.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup claude codex opencode cursor-agent copilot kimi agy droid pi gemini devin hermes
trap 'shape_sandbox_teardown' EXIT
# shellcheck disable=SC2119  # bare call intentional — no extra install flags for this harness
shape_install

assert_all_skills "$SANDBOX/skills"
assert_all_skills "$SANDBOX/.codex/skills"
while IFS=$'\t' read -r _h _b _m hint; do
  assert_in_log "$hint"
done < "$REPO_ROOT/tests/install-shape/tier-b.tsv"
assert_shims_never_invoked

shape_sandbox_teardown
fail_count
