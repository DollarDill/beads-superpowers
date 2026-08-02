#!/usr/bin/env bash
# surface.sh — bd interface for the knowledge-retrieval skill.
# Queries are passed as ARGV ONLY, never interpolated into a command string:
# the 3-8 keyword expansion is the model inventing search strings, so an
# interpolated query is an execution primitive, not a theoretical risk.
# Reads only — this script never writes, re-scores, prunes or mutates a store.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$#" -gt 0 ] || { echo "usage: surface.sh <query...>" >&2; exit 2; }

if ! command -v bd >/dev/null 2>&1; then
  echo "searched: memories(SKIP) beads(SKIP) — bd absent"; exit 0
fi

# Each bd call's exit status is captured separately. Falling back to an empty
# document set WITHOUT recording the failure would print a bd error as
# "memories(0)" — indistinguishable from an empty store, which is precisely the
# silent partial the coverage line exists to prevent (orient.sh:29-33).
degraded=""
if ! mem="$(bd memories --json 2>/dev/null)"; then
  mem='{}'; degraded="memories"
fi
# -n 0 is mandatory: a captured lesson records bd list defaulting to --limit 50
# (v1.1.0). It did NOT reproduce on v1.1.2 (232 returned either way), but silent
# truncation is the exact failure this design exists to prevent, and the existing
# guard scripts already pass it. Costs nothing; immune to version/flag drift.
if ! beads="$(bd list --label kb --status all -n 0 --json 2>/dev/null)"; then
  beads='[]'; degraded="${degraded:+$degraded,}beads"
fi

if ! command -v python3 >/dev/null 2>&1; then
  # Visible degradation, never a silent partial (orient.sh:29-33).
  # BODIES ARE WITHHELD: redact() lives in rank.py, so without python3 there is
  # no redaction. A floor with a bypass is not a floor — print keys only and let
  # the agent `bd recall <key>` deliberately, at the same trust boundary as today.
  #
  # One bd call PER TERM, unioned. bd substring-matches the WHOLE argument, so a
  # single quoted multi-word phrase — the shape SKILL.md documents — matches
  # nothing at all, while searching only "$1" silently drops terms 2..N of an
  # argv-word query. "$*" re-splits both shapes into the same term list, and the
  # terms actually searched are disclosed on the coverage line.
  read -ra terms <<<"$*"
  # A whitespace-only query leaves the array empty, and "${terms[@]}" is an
  # unbound variable under `set -u` on bash 3.2.
  [ "${#terms[@]}" -gt 0 ] || terms=("$*")
  raw="" joined=""
  for term in "${terms[@]}"; do
    joined="${joined:+$joined,}$term"
    # bd's exit status is CHECKED, never discarded: "nothing matched" and "bd is
    # broken" both print nothing usable here, and only the status separates them.
    if out="$(bd memories "$term" 2>/dev/null)"; then
      raw="$raw$out"$'\n'
    else
      case ",$degraded," in *,memories,*) ;; *) degraded="${degraded:+$degraded,}memories" ;; esac
    fi
  done
  # Keys indent 2, bodies 4 (verified against bd 1.1.2) — this anchor is what
  # withholds the bodies. sort -u unions the per-term result sets; sed, not head,
  # because head exits early and SIGPIPEs the upstream stage under pipefail.
  # SECURITY FLOOR — the '^  [A-Za-z0-9._-]+$' anchor IS the body-withholding
  # control (keys indent 2, bodies 4), enforcing "never print bodies without
  # python3". Only the surrounding status handling changes below; the anchor,
  # the sort and the sed are untouched. Do NOT loosen the charset or drop the
  # full-line anchors.
  #
  # Pipeline status is CAPTURED, never discarded: the previous `|| true` made a
  # missing or erroring grep byte-identical to a genuine zero-hit result, so an
  # agent reading stdout could not tell a broken toolchain from an empty store
  # (beads-superpowers-eo9z2.23). Runs under `set -o pipefail`, so a failure in
  # any stage propagates here.
  keys_status=""
  # Capture the FULL key set BEFORE truncating, so the cut can be disclosed
  # (beads-superpowers-eo9z2.9): cutting inside the pipeline made 20-of-20
  # indistinguishable from 20-of-200 on a line carrying no total.
  #
  # Branch on the STATUS, not on truthiness (beads-superpowers-eo9z2.28). grep exits 1
  # for "no match" — normal — and >=2 for a real error. Under `set -o pipefail` a bare
  # `if !` conflated the two, so a healthy-but-empty result reported a pipeline error:
  # eo9z2.23's fix inverted into its own mirror image. BOTH directions must hold — a
  # broken pipeline never reads as zero hits, and zero hits never read as broken.
  set +e
  all_keys="$(grep -E '^  [A-Za-z0-9._-]+$' <<<"$raw" | sort -u)"; keys_rc=$?
  set -e
  if [ "$keys_rc" -gt 1 ]; then
    keys=""; keys_status=" keys UNAVAILABLE(pipeline error)"
  else
    if [ -z "$all_keys" ]; then key_total=0; else key_total="$(grep -c '' <<<"$all_keys")"; fi
    keys="$(sed -n '1,20p' <<<"$all_keys")"
    # `if/fi`, never a trailing `[ cond ] && ...`: a false trailing conditional makes
    # the enclosing block's status 1, which `set -e` can act on.
    if [ "$key_total" -gt 20 ]; then keys_status=" showing 20 of ${key_total} keys"; fi
  fi
  # The failure record built above is RENDERED here, not discarded: a coverage
  # line that reads identically whether bd answered or died is exactly the silent
  # partial this line exists to prevent, and this is the one path that never
  # reaches rank.py's _store().
  case ",$degraded," in
    *,memories,*) searched="memories UNAVAILABLE(bd error)" ;;
    *)            searched="memories(DEGRADED)" ;;
  esac
  printf 'searched: %s beads(SKIPPED)%s terms=%s\n' "$searched" "$keys_status" "$joined"
  echo "ranking requires python3 — matching keys only, bodies withheld (redaction unavailable)"
  if [ -n "$keys" ]; then
    printf '%s\n' "$keys"
  else
    echo "  (no hits — re-angle the query once before reporting none)"
  fi
  exit 0
fi

# NUL-separated so no field can be confused with another: memories JSON, beads
# JSON, then the comma-separated names of any store bd failed to return.
printf '%s\0%s\0%s' "$mem" "$beads" "$degraded" | python3 "$HERE/rank.py" --stdin "$@"
