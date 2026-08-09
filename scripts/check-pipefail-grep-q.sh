#!/usr/bin/env bash
# check-pipefail-grep-q.sh — beads-superpowers-wze77.9: under `set -o pipefail`,
# piping a producer into `grep -q` is a RACE that manufactures spurious FAILs.
#
#   echo "$out" | grep -q PATTERN || { echo "FAIL: ..."; exit 1; }
#
# `grep -q` exits the instant it matches and closes the read end of the pipe. The
# producer's next write gets EPIPE/SIGPIPE and the producer exits 141. `pipefail`
# promotes that 141 to the status of the WHOLE pipeline — so the `||` arm fires
# even though the pattern MATCHED. The assertion reports failure on success.
#
# The tell is that a DIFFERENT item fails on each run: which item grep matched
# decides how much of the stream is left unread, and therefore whether the
# producer ever attempts the write that draws the signal. Measured on the real
# harness at ~1 spurious FAIL in 30 runs of tests/skills/test-diagnose-script.sh.
#
# The fix is to stop making it a pipeline. Feed grep a here-string instead:
#   grep -q PATTERN <<<"$out"                      # variable already captured
#   out=$(cmd); grep -q PATTERN <<<"$out"          # capture first, guard as needed
# A here-string is a redirection from a temp fd, not a pipe: no SIGPIPE, no
# pipefail promotion, and grep's own status is the only status.
#
# `grep -q PATTERN file` is NOT a pipe and is never flagged.
#
# Usage: scripts/check-pipefail-grep-q.sh [file...]
#   no args -> every tracked *.sh plus the extensionless bd-readonly shim
#   args    -> exactly those files (used by the selftest's fixture mutations)
#
# Scope/limitation: only FULL-LINE comments are exempt. A trailing comment that
# quotes the anti-pattern after live code will be flagged; reword it rather than
# loosening this guard. There is deliberately NO annotation-based opt-out — every
# occurrence found in the wze77.9 sweep converted cleanly, so an escape hatch
# would only ever be used to reintroduce the bug.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# `| grep -q`, including every option cluster that carries a q (-qi -qE -qF -Fq
# -Eq -qxF ...) and the long form. Matching only a bare `-q` would miss more than
# half of the real occurrences.
PIPED_GREP_Q='\|[[:space:]]*grep[[:space:]]+(-[A-Za-z]*q[A-Za-z]*|--quiet)([[:space:]]|$)'
SETS_PIPEFAIL='^[[:space:]]*set[[:space:]]+-[^|]*pipefail'

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  if ! command -v git >/dev/null 2>&1; then
    echo "SKIP: git not installed — cannot enumerate tracked shell files (install git to enable)"
    exit 0
  fi
  mapfile -t files < <(git ls-files '*.sh')
  # Same blind spot lint-shell.sh documents: the read-only bd shim must be named
  # exactly `bd` to shadow the real binary on PATH, so no *.sh glob ever finds it.
  [ -f "tests/skills/helpers/bd-readonly/bd" ] && files+=("tests/skills/helpers/bd-readonly/bd")
  if [ "${#files[@]}" -eq 0 ]; then
    echo "pipefail-grep-q: OK (no tracked shell scripts)"
    exit 0
  fi
fi

violations=""
scanned=0
for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  grep -qE -- "$SETS_PIPEFAIL" "$f" || continue   # no pipefail => no 141 promotion
  scanned=$((scanned + 1))
  # Strip full-line comments before matching: a comment cannot take SIGPIPE.
  hits=$(grep -nE -- "$PIPED_GREP_Q" "$f" | grep -vE -- '^[0-9]+:[[:space:]]*#' || true)
  [ -n "$hits" ] && violations+="$(awk -v f="$f" '{print f":"$0}' <<<"$hits")"$'\n'
done

if [ -n "$violations" ]; then
  echo "pipefail-grep-q: FAIL — producer piped into 'grep -q' inside a pipefail script (beads-superpowers-wze77.9)."
  echo "grep -q closes the pipe on first match; the producer exits 141; pipefail makes that the pipeline status,"
  echo "so the assertion reports FAIL even when the pattern MATCHED. Use a here-string: grep -q P <<<\"\$out\""
  printf '%s' "$violations"
  exit 1
fi
echo "pipefail-grep-q: OK (no piped 'grep -q' in $scanned pipefail-setting shell files)"
