#!/usr/bin/env bash
# Release eval gate (0.17.0 program spec §5). Every skill directory changed
# since the base (three-dot: from the merge base, so commits that exist only
# on the base side never count) must have, under evals/<skill>/, at least one
# case tagged core-fire, one core-nofire and one core-behaviour. Tags are read
# from the flow-style `tags: [...]` line inside each prompt.md's frontmatter.
#
# Release-time only (`just evalgate`): it fails by design until every gated
# skill has its core cases, so it is not part of `just check`.
#
# Usage: check-eval-gate.sh [ROOT]   base ref: $EVAL_GATE_BASE (default origin/main)
# Exit: 0 all covered (or nothing changed) · 1 any MISSING or ERROR · 2 base unresolvable
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BASE="${EVAL_GATE_BASE:-origin/main}"

if ! git -C "$ROOT" rev-parse --verify --quiet "$BASE^{commit}" >/dev/null; then
  echo "EVAL-GATE ERROR: cannot resolve base '$BASE' (fetch origin or set EVAL_GATE_BASE)"
  exit 2
fi
if ! changed="$(git -C "$ROOT" diff --name-only "$BASE...HEAD" -- skills/)"; then
  echo "EVAL-GATE ERROR: git diff $BASE...HEAD failed"
  exit 2
fi
gated="$(printf '%s\n' "$changed" | awk -F/ '$1 == "skills" && NF >= 3 { print $2 }' | sort -u)"
if [ -z "$gated" ]; then
  echo "eval-gate: no skills changed since $BASE"
  exit 0
fi

# Prints one tag per line from prompt.md's frontmatter, or one of the single
# lines "!unsupported" (a tags key not in flow style), "!unclosed" (frontmatter
# with no closing ---) or "!duplicate" (a second tags key).
frontmatter_tags() {
  awk '
    NR == 1 { if ($0 != "---") exit; open = 1; next }
    $0 == "---" { open = 0; exit }
    /^tags:/ {
      if (seen) { dup = 1; next }
      seen = 1
      v = $0; sub(/^tags:[ \t]*/, "", v)
      if (v !~ /^\[.*\][ \t]*$/) { bad = 1; next }
      sub(/^\[/, "", v); sub(/\][ \t]*$/, "", v)
      n = split(v, t, ",")
      for (i = 1; i <= n; i++) { gsub(/^[ \t"\047]+|[ \t"\047]+$/, "", t[i]); if (t[i] != "") out = out t[i] "\n" }
    }
    END {
      if (open) { print "!unclosed"; exit }
      if (dup) { print "!duplicate"; exit }
      if (bad) { print "!unsupported"; exit }
      printf "%s", out
    }' "$1"
}

rc=0
while IFS= read -r skill; do
  fire=0 nofire=0 behaviour=0
  for prompt in "$ROOT"/evals/"$skill"/*/prompt.md; do
    [ -f "$prompt" ] || continue
    rel="${prompt#"$ROOT"/}"
    while IFS= read -r tag; do
      case "$tag" in
        '!unclosed') echo "EVAL-GATE ERROR: $rel: frontmatter has no closing ---"; rc=1 ;;
        '!duplicate') echo "EVAL-GATE ERROR: $rel: duplicate tags key"; rc=1 ;;
        '!unsupported') echo "EVAL-GATE ERROR: $rel: unsupported tags format"; rc=1 ;;
        core-fire) fire=1 ;;
        core-nofire) nofire=1 ;;
        core-behaviour) behaviour=1 ;;
        core-security) ;;
        [Cc][Oo][Rr][Ee]*) echo "EVAL-GATE ERROR: $rel: unknown core tag $tag"; rc=1 ;;
      esac
    done < <(frontmatter_tags "$prompt")
  done
  missing=""
  [ "$fire" = 1 ] || missing="${missing},core-fire"
  [ "$nofire" = 1 ] || missing="${missing},core-nofire"
  [ "$behaviour" = 1 ] || missing="${missing},core-behaviour"
  if [ -n "$missing" ]; then
    echo "MISSING $skill: ${missing#,}"; rc=1
  else
    echo "COVERED $skill"
  fi
done <<< "$gated"
exit "$rc"
