#!/usr/bin/env bash
# tests/skills/helpers/store-snapshot.sh <project-dir> — spec §5.4 backstop.
#
# Emits: issues=<sha256> memories=<sha256>
#
# CONTENT hashes, never counts: `bd remember` on an existing key overwrites in
# place and `bd forget`+`bd remember` round-trips, both leaving the count
# unchanged while the store's content differs.
#
# Reads only. Never call this with the shim absent from a foreign-store context.
set -euo pipefail

dir="${1:?usage: store-snapshot.sh <project-dir>}"
[ -d "$dir" ] || { echo "store-snapshot: no such directory: $dir" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "store-snapshot: jq required" >&2; exit 3; }

# CAPTURE RAW FIRST, GUARD, THEN HASH — the order is the whole point.
# `sha256sum` of empty input is always a 64-hex string (e3b0c442…b855), so an
# emptiness test applied to the HASH can never be false. Guarding the raw `bd` output
# is what makes "no reachable store" a reachable error path instead of dead code.
# `-n 0` is unlimited (verified: `bd list --help`, "use 0 for unlimited").
raw_issues=""
if issues_out="$( cd "$dir" && bd list --status all -n 0 --json 2>/dev/null )"; then
  raw_issues="$issues_out"
fi
raw_memories=""
if memories_out="$( cd "$dir" && bd memories --json 2>/dev/null )"; then
  raw_memories="$memories_out"
fi

# A reachable-but-empty store is NOT an error: a fresh `bd init` returns `[]` for
# issues and `{"schema_version": 1}` for memories — both non-empty. Only a directory
# with no resolvable store yields empty strings for both.
if [ -z "$raw_issues" ] || [ -z "$raw_memories" ]; then
  echo "store-snapshot: no reachable store at $dir" >&2
  exit 4
fi

# `bd list --json` is an ARRAY; `sort_by(.id)` plus `-S` normalise row order and key
# order, so a re-read of an unchanged store cannot differ for cosmetic reasons.
issues="$( printf '%s' "$raw_issues" | jq -S 'sort_by(.id)' | sha256sum | cut -d' ' -f1 )"
# `bd memories --json` is an OBJECT of key->body PLUS a `schema_version` envelope key
# (verified bd v1.1.2, 2026-08-08: jq length = 190 vs 189 real memories). The envelope
# is DELETED before hashing (stress-test B4): a bd upgrade that bumps schema_version
# would otherwise move this hash with ZERO content change, and the caller's rule for a
# hash delta is "floor breach: stop, do not proceed" — a routine upgrade would forge a
# security incident and halt the run.
memories="$( printf '%s' "$raw_memories" | jq -S 'del(.schema_version)' | sha256sum | cut -d' ' -f1 )"

printf 'issues=%s memories=%s\n' "$issues" "$memories"
