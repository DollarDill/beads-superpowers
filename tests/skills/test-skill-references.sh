#!/usr/bin/env bash
# tests/skills/test-skill-references.sh — run: bash tests/skills/test-skill-references.sh
# MECHANICAL reach guard for the shared references/ layout (sub-project B). Asserts
# structure only, never instruction wording.
#   C1 every references/<n>.md path named in SKILL.md resolves
#   C2 every file in references/ is named in SKILL.md (no orphans)
#   C3 at least one same-skill pointer exists (no vacuous pass; bead beads-superpowers-kjs4v)
#   C4 every file in references/ is named [a-z0-9-]+.md
# Per registry entry (tests/skills/skill-references-moved/<skill>.txt):
#   C5 SKILL.md has the exact pointer line, with a gist (non-space start, >= 9 more chars, ends in ".")
#   C6 file starts "# Title", a blank line, then a "Read this when " line (a missing file fails here)
#   C7 a file over 100 lines then has a "Contents: " line
#   C8 the file names no same-skill references/*.md that SKILL.md itself does not name
#      outside fences (one hop either way; no hidden chain)
# Registry completeness (C9): every well-formed file in a references/ dir must be
# registered in <skill>.txt unless grandfathered (see grandfathered()); a missing
# <skill>.txt fails; checking zero skills while any registry lists a file fails.
# C1 runs for every skill (pointers may reach another skill's references/ even when
# the skill has none); C2-C4(dir) apply only where references/ exists. C4 also fails
# any ill-formed references/ name that SKILL.md mentions.
# CRs are stripped before every match; fenced code blocks are ignored for C1/C3/C5.
# Every failure prints "FAIL Cn:" so a selftest can assert WHICH check fired.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGDIR="$ROOT/tests/skills/skill-references-moved"
SKILLS=(subagent-driven-development executing-plans write-documentation)
PTR='(\.\./[a-z0-9-]+/)?references/[a-z0-9-]+\.md'
BROAD='(\.\./[A-Za-z0-9_-]+/)?references/[A-Za-z0-9_-]+\.md'
rc=0
skill=""
checked=0
total_entries=0

# grandfathered <file>: existing references/ files that predate the registry
grandfathered() {
  case "$skill:$1" in
    subagent-driven-development:breaker-trip.md | subagent-driven-development:dispatch-efficiency.md | subagent-driven-development:rulings-and-escalation.md | write-documentation:long-form-diagnostics.md) return 0 ;;
  esac
  return 1
}

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
  else
    fail C9 "registry file missing: tests/skills/skill-references-moved/$skill.txt"
  fi
  if [ -n "$entries" ]; then
    total_entries=$((total_entries + $(printf '%s\n' "$entries" | grep -c '')))
  fi

  # C1 (every skill) + C3 (only where references/ exists) + C4 for mentioned names
  same=0
  skill_named=""  # same-skill basenames SKILL.md names outside fences (C8 allows one hop to these)
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ ! -f "$dir/$m" ]; then
      fail C1 "dangling pointer: $m"
    fi
    if ! printf '%s\n' "${m##*/}" | grep -qE '^[a-z0-9-]+\.md$'; then
      fail C4 "ill-formed name mentioned in SKILL.md: $m"
    fi
    if is_same_skill "$m"; then
      same=$((same + 1))
      skill_named="$skill_named${m##*/}
"
    fi
  done < <(printf '%s\n' "$unfenced" | grep -oE "$BROAD" | sort -u)

  if [ ! -d "$refs" ]; then
    echo "SKIP $skill: no references/"
  else
    checked=$((checked + 1))
    if [ "$same" -eq 0 ]; then
      fail C3 "references/ exists but SKILL.md has no same-skill pointer (vacuous pass)"
    fi
    # C2 + C4 + C9 (names taken from the raw text, broad charset, so an ill-formed name is still seen)
    named="$(printf '%s\n' "$raw" | grep -oE "$BROAD" || true)"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      base="$(basename "$f")"
      if [ ! -f "$f" ] || ! printf '%s\n' "$base" | grep -qE '^[a-z0-9-]+\.md$'; then
        fail C4 "ill-formed entry (subdirectory, dotfile or bad name): references/$base"
        continue
      fi
      hit=0
      while IFS= read -r m; do
        [ -n "$m" ] || continue
        if [ "${m##*/}" = "$base" ] && is_same_skill "$m"; then hit=1; fi
      done < <(printf '%s\n' "$named")
      if [ "$hit" -eq 0 ]; then
        fail C2 "orphan: references/$base is not named in SKILL.md"
      fi
      if ! printf '%s\n' "$entries" | grep -qxF "$base"; then
        if ! grandfathered "$base"; then
          fail C9 "references/$base is not registered in tests/skills/skill-references-moved/$skill.txt"
        fi
      fi
    done < <(find "$refs" -mindepth 1 -maxdepth 1 | sort)
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
    if ! printf '%s\n' "$unfenced" | grep -qE "^[[:space:]]*(([-*+]|[0-9]+[.)])[[:space:]]+)?\*\*Read \`references/$esc\` \(in this skill's directory\) before .+\*\* — [^[:space:]].{8,}\\.[[:space:]]*\$"; then
      fail C5 "no pointer line with a gist for references/$f"
    fi
    body="$(tr -d '\r' < "$file")"
    first="$(printf '%s\n' "$body" | head -n 1)"
    if ! printf '%s\n' "$first" | grep -qE '^# .'; then
      fail C6 "references/$f: first line is not '# Title'"
      continue
    fi
    second="$(printf '%s\n' "$body" | sed -n '2p')"
    if ! printf '%s\n' "$second" | grep -qE '^[[:space:]]*$'; then
      fail C6 "references/$f: no blank line after the '# Title'"
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
      nxt="$(printf '%s\n' "$body" | awk -v n="$rtw_line" 'NR < n { next } !pdone { if ($0 ~ /^[[:space:]]*$/) pdone = 1; next } $0 !~ /^[[:space:]]*$/ { print; exit }')"
      case "$nxt" in
        "Contents: "*) ;;
        *) fail C7 "references/$f: $total lines but no 'Contents: ' line after 'Read this when'" ;;
      esac
    fi
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      if is_same_skill "$m" && ! printf '%s' "$skill_named" | grep -qxF "${m##*/}"; then
        fail C8 "references/$f chains to same-skill $m, which SKILL.md does not name"
      fi
    done < <(printf '%s\n' "$body" | grep -oE "$PTR" | sort -u)
  done < <(printf '%s\n' "$entries")
done

if [ "$checked" -eq 0 ] && [ "$total_entries" -gt 0 ]; then
  skill="(all)"
  fail C9 "no skill was checked (every references/ dir missing) but a registry lists $total_entries file(s)"
fi

if [ "$rc" -eq 0 ]; then
  echo "PASS: skill references structure"
fi
exit "$rc"
