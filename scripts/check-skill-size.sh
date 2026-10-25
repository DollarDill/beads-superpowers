#!/usr/bin/env bash
# Guard: no skills/*/SKILL.md at or over 20,000 bytes. After a compaction Claude
# Code re-attaches each invoked skill truncated to 20,000 characters, so content
# past the cut is lost. Bytes are stricter than characters, which is deliberate.
# Offenders are recorded in scripts/skill-size-baseline.txt as a ratchet: they
# may not grow, and an entry must be removed once the skill drops under the limit.
# WARN (exit unchanged) from 19,000 bytes.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE="$REPO_ROOT/scripts/skill-size-baseline.txt"
LIMIT=20000
WARN_AT=19000
fails=0

baseline_for() {  # skill name -> recorded bytes, empty if unlisted
  [ -f "$BASELINE" ] || return 0
  tr -d '\r' < "$BASELINE" | awk -v n="$1" '$1 !~ /^#/ && $1 == n { print $2; exit }'
}

for f in "$REPO_ROOT"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  name="$(basename "$(dirname "$f")")"
  bytes="$(wc -c < "$f" | tr -d ' ')"
  rec="$(baseline_for "$name")"
  if [ "$bytes" -ge "$LIMIT" ]; then
    case "$rec" in *[!0-9]*) continue ;; esac  # malformed: reported by the baseline pass below
    if [ -z "$rec" ]; then
      echo "SKILL-SIZE FAIL: skills/$name/SKILL.md is $bytes bytes (limit: under $LIMIT)"
      fails=$((fails + 1))
    elif [ "$bytes" -gt "$rec" ]; then
      echo "SKILL-SIZE FAIL: skills/$name/SKILL.md grew to $bytes bytes (baseline $rec)"
      fails=$((fails + 1))
    fi
  elif [ "$bytes" -ge "$WARN_AT" ]; then
    echo "SKILL-SIZE WARN: skills/$name/SKILL.md is $bytes bytes (within 1,000 of the 20,000 limit)"
  fi
done

if [ -f "$BASELINE" ]; then
  while read -r name rec _; do
    case "$name" in ''|'#'*) continue ;; esac
    case "$rec" in
      ''|*[!0-9]*)
        echo "SKILL-SIZE FAIL: baseline entry $name has a malformed size '$rec'"
        fails=$((fails + 1))
        continue ;;
    esac
    f="$REPO_ROOT/skills/$name/SKILL.md"
    if [ ! -f "$f" ]; then
      echo "SKILL-SIZE FAIL: baseline entry $name is stale (skill missing, $rec recorded): remove it"
      fails=$((fails + 1))
      continue
    fi
    bytes="$(wc -c < "$f" | tr -d ' ')"
    if [ "$bytes" -lt "$LIMIT" ]; then
      echo "SKILL-SIZE FAIL: baseline entry $name is stale ($bytes bytes, under $LIMIT): remove it"
      fails=$((fails + 1))
    fi
  done < <(tr -d '\r' < "$BASELINE")
fi

if [ "$fails" -gt 0 ]; then
  exit 1
fi
echo "PASS: no SKILL.md at or over $LIMIT bytes beyond the baseline"
exit 0
