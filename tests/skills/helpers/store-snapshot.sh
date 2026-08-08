#!/usr/bin/env bash
# tests/skills/helpers/store-snapshot.sh <store-root> — spec §5.4 backstop.
#
# Emits: issues=<sha256> memories=<sha256>
#
# CONTENT hashes, never counts: `bd remember` on an existing key overwrites in
# place and `bd forget`+`bd remember` round-trips, both leaving the count
# unchanged while the store's content differs.
#
# CONTRACT (NARROWED 2026-08-08): the argument is the directory that OWNS the store —
# the one holding `.beads/` — not an arbitrary subdirectory of a project. `bd`
# auto-discovers `.beads/` UP the tree, so a subdirectory argument leaves the helper
# unable to say which store answered its reads. Callers holding a subdirectory must
# pass the store root instead.
#
# Reads only. Never call this with the shim absent from a foreign-store context.
set -euo pipefail

dir="${1:?usage: store-snapshot.sh <store-root>}"
[ -d "$dir" ] || { echo "store-snapshot: no such directory: $dir" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "store-snapshot: jq required" >&2; exit 3; }

# ── HALF 1 OF CONTAINMENT: state where the store IS, positively.
# Requiring `.beads/` under $dir is an assertion about the argument, not an attempt to
# enumerate the ways resolution might wander off it. It also removes upward
# auto-discovery as a silent source of content: without it, snapshotting a scratch
# directory nested anywhere under a real project reports that project's store.
if [ ! -d "$dir/.beads" ]; then
  echo "store-snapshot: no reachable store at $dir" >&2
  exit 4
fi

# ── HALF 2 OF CONTAINMENT: a scrubbed environment, NOT `unset BEADS_DIR BEADS_DB`.
# An inherited store-resolution variable redirects every `bd` call below to a foreign
# store while this script still prints a well-formed, stable hash line for the directory
# it was asked to snapshot. The caller's rule is "hash delta -> floor breach, stop" and
# "no delta -> proceed", so that is a permanent all-clear on the containment backstop
# itself — reproduced 2026-08-08, byte-identical to a read of the foreign store.
#
# Unsetting the names we know about is a BLOCKLIST, and a blocklist stops guarding the
# moment `bd` grows another one. That is not hypothetical here: a fix that unset
# BEADS_DIR was followed immediately by the discovery that BEADS_DB reopens the identical
# hole. So enumerate the other way round. `env -i` starts from an EMPTY environment and
# adds back only what `bd` needs to run at all, so a variable a future `bd` invents is
# excluded without anyone editing this file. The failure direction is right too: too
# small a keep-list makes `bd` fail loudly and trip the guard below, never quietly report
# somebody else's store.
#
# PATH is kept deliberately — it is how `bd` is found, and how a caller puts the
# read-only shim (tests/skills/helpers/bd-readonly) in front of it.
bd_read() {
  ( cd "$dir" && env -i \
      PATH="$PATH" \
      HOME="${HOME-}" \
      TMPDIR="${TMPDIR:-/tmp}" \
      bd "$@" 2>/dev/null )
}

# CAPTURE RAW FIRST, GUARD, THEN HASH — the order is the whole point.
# `sha256sum` of empty input is always a 64-hex string (e3b0c442…b855), so an
# emptiness test applied to the HASH can never be false. Guarding the raw `bd` output
# is what makes "no reachable store" a reachable error path instead of dead code.
# `-n 0` is unlimited (verified: `bd list --help`, "use 0 for unlimited").
raw_issues=""
if issues_out="$( bd_read list --status all -n 0 --json )"; then
  raw_issues="$issues_out"
fi
raw_memories=""
if memories_out="$( bd_read memories --json )"; then
  raw_memories="$memories_out"
fi

# A reachable-but-empty store is NOT an error: a fresh `bd init` returns `[]` for
# issues and `{"schema_version": 1}` for memories — both non-empty. raw_issues/
# raw_memories stay empty when the corresponding `bd` call above EITHER exits
# non-zero (the `if` above never assigns) OR exits zero with genuinely empty
# output — a non-zero `bd` exit or empty output both mean no usable store here.
if [ -z "$raw_issues" ] || [ -z "$raw_memories" ]; then
  echo "store-snapshot: no reachable store at $dir" >&2
  exit 4
fi

# `bd list --json` is an ARRAY; `sort_by(.id)` plus `-S` normalise row order and key
# order, so a re-read of an unchanged store cannot differ for cosmetic reasons.
issues="$( printf '%s' "$raw_issues" | jq -S 'sort_by(.id)' | sha256sum | cut -d' ' -f1 )"
# `bd memories --json` is an OBJECT of key->body PLUS a `schema_version` envelope key
# (verified as of bd v1.1.2). The envelope is DELETED before hashing (stress-test B4):
# a bd upgrade that bumps schema_version would otherwise move this hash with ZERO
# content change, and the caller's rule for a hash delta is "floor breach: stop, do
# not proceed" — a routine upgrade would forge a security incident and halt the run.
memories="$( printf '%s' "$raw_memories" | jq -S 'del(.schema_version)' | sha256sum | cut -d' ' -f1 )"

printf 'issues=%s memories=%s\n' "$issues" "$memories"
