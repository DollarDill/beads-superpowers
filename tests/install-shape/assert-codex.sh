#!/usr/bin/env bash
# assert-codex.sh — Tier A: Codex skills copy + round-trip.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup codex
trap 'shape_sandbox_teardown' EXIT
# shellcheck disable=SC2119  # bare call intentional — no extra install flags for this harness
shape_install

assert_all_skills "$SANDBOX/.codex/skills"
# ADR-0044: maintainer-only skill must never be installed
assert_no_file "$SANDBOX/.codex/skills/auditing-upstream-drift/SKILL.md"
assert_in_log "Codex: installed"
# Codex activation guidance printed (config.toml features block)
assert_in_log "codex_hooks = true"
assert_shims_never_invoked

shape_uninstall
assert_no_file "$SANDBOX/.codex/skills/using-superpowers/SKILL.md"

shape_sandbox_teardown
fail_count
