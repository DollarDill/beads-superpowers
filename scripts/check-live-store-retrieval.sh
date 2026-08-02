#!/usr/bin/env bash
# check-live-store-retrieval.sh — durable, numbers-free half of Task 9.
# Visible SKIP, never FAIL, when the store is unavailable OR empty. (Note: `kb
# label vocab` and `kb doc reconciliation` currently FAIL rather than SKIP in a
# bare clone — do not copy that shape.)
#
# The one property that must never regress: a multi-word query — the shape an
# agent naturally types — returns something. The exact counts are Task 9's
# one-time verify-real-store.sh measurement, not this guard's job: a number
# pinned here goes red the first time anyone adds a memory.
set -uo pipefail

if command -v bd >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && bd memories >/dev/null 2>&1; then
  # Derive the probe FROM THE STORE (beads-superpowers-eo9z2.18). The old fixed
  # phrase "bd worktree gotchas" asserted that THIS maintainer's lore exists, so
  # every other contributor got a red guard in the shared run-guards.sh entrypoint.
  # A store-derived probe asserts the real property instead: the ranker works on
  # whatever this store holds.
  #
  # Derived from a BODY, never from a key. rank.py's Corpus tokenizes the stripped
  # body only — keys are map keys, never indexed — so a key-derived probe asserts
  # that this store's key-naming echoes its prose, which is just the original
  # maintainer-specific assumption in a new costume. Verified: a store whose key
  # shares no token with its body went red under the key-derived probe while the
  # ranker was perfectly healthy.
  #
  # The leading @k=v header is stripped because rank.py strips it too: probing on
  # @type= or @salience= would query terms the corpus does not contain.
  #
  # The MULTI-WORD shape is the point, not incidental — it is the exact case
  # `bd memories` and `bd search` return zero for, so the probe still exercises
  # the ranker's reason to exist.
  #
  # `sed -n '1p'`, never `head -1`: head exits early and SIGPIPEs the upstream
  # stage under pipefail (same reason surface.sh gives at its key-extraction step).
  first_body="$(bd memories 2>/dev/null | grep -E '^    [^ ]' | sed -n '1p')"
  read -r probe_a probe_b _ <<<"$(printf '%s' "$first_body" | sed -E 's/^ *(@[A-Za-z_]+=[^ ]+ +)*//')"
  if [ -z "${probe_b:-}" ]; then
    # No two-token probe derivable — nothing to assert, so say so rather than
    # inventing a query. This SKIP widens the old conditions, which is exactly how
    # a guard silently stops being a gate; the FAIL path below is unchanged and is
    # pinned by a selftest mutation.
    echo "SKIP: live-store retrieval check (no multi-word probe derivable from the store)"
    exit 0
  fi
  # Passed as ARGV, never interpolated into a command string (security floor).
  # Captured, not piped straight into grep: a crashed surface.sh (Python
  # traceback, a bd failure inside it) must be reported as a crash, not
  # misattributed to a zero-hit retrieval regression.
  if out="$(bash skills/knowledge-retrieval/scripts/surface.sh "$probe_a" "$probe_b")"; then
    n="$(printf '%s\n' "$out" | grep -c '^  [A-Za-z0-9._-]' || true)"
    if [ "$n" -gt 0 ]; then
      echo "live-store retrieval: OK (multi-word query '$probe_a $probe_b' returned $n hits)"
    else
      # Zero hits is only a regression against a populated store. Read
      # emptiness off surface.sh's own coverage line (rank.py's _store())
      # instead of a second bd probe, so it comes from the same invocation
      # that produced the zero. An initialised-but-empty store must SKIP
      # here, not FAIL — this file's own note above says not to copy that
      # shape.
      mem_n="$(printf '%s\n' "$out" | grep -oE 'memories\([0-9]+\)' | grep -oE '[0-9]+' || true)"
      if [ "${mem_n:-0}" -eq 0 ]; then
        echo "SKIP: live-store retrieval check (store empty or memories unavailable)"
      else
        # Zero hits for a probe built from the store's OWN indexed text is a real
        # ranker defect, not a foreign-store artifact: the queried terms came out
        # of a body the corpus contains, so a healthy ranker must return at least
        # that entry.
        echo "FAIL: multi-word query '$probe_a $probe_b' returned zero against the live store"
        exit 1
      fi
    fi
  else
    echo "FAIL: surface.sh crashed against the live store (non-zero exit, not a zero-hit result)"
    exit 1
  fi
else
  echo "SKIP: live-store retrieval check (bd, python3 or store unavailable)"
fi
