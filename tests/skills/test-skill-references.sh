#!/usr/bin/env bash
# tests/skills/test-skill-references.sh — run: bash tests/skills/test-skill-references.sh
# MECHANICAL reach guard for the shared references/ layout (sub-project B). Asserts
# structure only, never instruction wording.
#   C1 every references/<n>.md path named in SKILL.md resolves
#   C2 every file in references/ is named in SKILL.md (no orphans)
#   C3 at least one same-skill pointer exists (no vacuous pass; bead beads-superpowers-kjs4v)
#   C4 every file in references/ is named [a-z0-9-]+.md
# Per registry entry (tests/skills/skill-references-moved/<skill>.txt):
#   C5 SKILL.md has the exact pointer line, with a gist (>= 10 chars after " — ")
#   C6 file starts "# Title", then a "Read this when " line (a missing file fails here)
#   C7 a file over 100 lines then has a "Contents: " line
#   C8 the file names no same-skill references/*.md (no chaining)
# CRs are stripped before every match; fenced code blocks are ignored for C1/C3/C5.
# Every failure prints "FAIL Cn:" so a selftest can assert WHICH check fired.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGDIR="$ROOT/tests/skills/skill-references-moved"
SKILLS=(subagent-driven-development executing-plans write-documentation)
PTR='(\.\./[a-z0-9-]+/)?references/[a-z0-9-]+\.md'
rc=0
skill=""

fail() {  # fail <Cn> <message>
  echo "FAIL $1: $skill: $2"
  rc=1
}

# is_same_skill <match>: true if a pointer match targets this skill's own references/
is_same_skill() {
  case "$1" in
    ../*) [ "${1#../"$skill"/}" != "$1" ] ;;
    *) return 0 ;;
  esac
}

for skill in "${SKILLS[@]}"; do
  dir="$ROOT/skills/$skill"
  skillmd="$dir/SKILL.md"
  refs="$dir/references"
  if [ ! -f "$skillmd" ]; then
    fail C1 "SKILL.md missing"
    continue
  fi
  raw="$(tr -d '\r' < "$skillmd")"
  unfenced="$(printf '%s\n' "$raw" | awk '/^[[:space:]]*```/ { f = !f; next } !f')"

  entries=""
  if [ -f "$REGDIR/$skill.txt" ]; then
    entries="$(tr -d '\r' < "$REGDIR/$skill.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v -e '^#' -e '^$' || true)"
  fi

  if [ ! -d "$refs" ]; then
    echo "SKIP $skill: no references/"
  else
    # C1 + C3
    same=0
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      if [ ! -f "$dir/$m" ]; then
        fail C1 "dangling pointer: $m"
      fi
      if is_same_skill "$m"; then same=$((same + 1)); fi
    done < <(printf '%s\n' "$unfenced" | grep -oE "$PTR" | sort -u)
    if [ "$same" -eq 0 ]; then
      fail C3 "references/ exists but SKILL.md has no same-skill pointer (vacuous pass)"
    fi
    # C2 + C4 (names taken from the raw text, broad charset, so an ill-formed name is still seen)
    named="$(printf '%s\n' "$raw" | grep -oE '(\.\./[A-Za-z0-9_-]+/)?references/[A-Za-z0-9_-]+\.md' || true)"
    for f in "$refs"/*; do
      [ -e "$f" ] || continue
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if ! printf '%s\n' "$base" | grep -qE '^[a-z0-9-]+\.md$'; then
        fail C4 "ill-formed name: references/$base"
      fi
      hit=0
      while IFS= read -r m; do
        [ -n "$m" ] || continue
        if [ "${m##*/}" = "$base" ] && is_same_skill "$m"; then hit=1; fi
      done < <(printf '%s\n' "$named")
      if [ "$hit" -eq 0 ]; then
        fail C2 "orphan: references/$base is not named in SKILL.md"
      fi
    done
  fi

  # registry entries (C5-C8)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! printf '%s\n' "$f" | grep -qE '^[a-z0-9-]+\.md$'; then
      fail C4 "registry entry ill-formed: $f"
      continue
    fi
    file="$refs/$f"
    if [ ! -f "$file" ]; then
      fail C6 "registry file missing: references/$f"
      continue
    fi
    esc="${f//./\\.}"
    if ! printf '%s\n' "$unfenced" | grep -qE "^[[:space:]]*(([-*+]|[0-9]+[.)])[[:space:]]+)?\*\*Read \`references/$esc\` \(in this skill's directory\) before .+\*\* — .{10,}"; then
      fail C5 "no pointer line with a gist for references/$f"
    fi
    body="$(tr -d '\r' < "$file")"
    first="$(printf '%s\n' "$body" | head -n 1)"
    if ! printf '%s\n' "$first" | grep -qE '^# .'; then
      fail C6 "references/$f: first line is not '# Title'"
      continue
    fi
    rtw="$(printf '%s\n' "$body" | awk 'NR > 1 && $0 !~ /^[[:space:]]*$/ { print NR ":" $0; exit }')"
    rtw_line="${rtw%%:*}"
    case "${rtw#*:}" in
      "Read this when "*) ;;
      *)
        fail C6 "references/$f: no 'Read this when ' line after the title"
        continue
        ;;
    esac
    total="$(printf '%s\n' "$body" | grep -c '')"
    if [ "$total" -gt 100 ]; then
      nxt="$(printf '%s\n' "$body" | awk -v n="$rtw_line" 'NR > n && $0 !~ /^[[:space:]]*$/ { print; exit }')"
      case "$nxt" in
        "Contents: "*) ;;
        *) fail C7 "references/$f: $total lines but no 'Contents: ' line after 'Read this when'" ;;
      esac
    fi
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      if is_same_skill "$m"; then
        fail C8 "references/$f chains to same-skill $m"
      fi
    done < <(printf '%s\n' "$body" | grep -oE "$PTR" | sort -u)
  done < <(printf '%s\n' "$entries")
done

if [ "$rc" -eq 0 ]; then
  echo "PASS: skill references structure"
fi
exit "$rc"
