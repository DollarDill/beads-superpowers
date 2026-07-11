#!/usr/bin/env bash
# check-skill-count.sh — guard against hardcoded skill-count drift + structural self-consistency.
#
# The exact skill count lives only in the {{ skill_count }} macro tokens in docs/ pages; the computing
# macro (main.py) is hub-owned in the-factory-website tenants/beads-superpowers/ (ADR-0050). Everywhere
# else the integer is removed from prose; this guard forbids it from creeping back, and asserts that
# every skill directory has exactly one SKILL.md (frontmatter validity is covered by check-skill-frontmatter.py).
#
# Usage:
#   scripts/check-skill-count.sh             # check the real tree (structural + drift guard)
#   scripts/check-skill-count.sh --self-test # prove the guard FAILS on broken fixtures (ADR-0025 pattern)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Precise total-count regex: a number + optional count-qualifier adjective + "skills", or "Skills (N Total)".
# Intentionally does NOT match "7 fork-unique skills", "(9 subtests)", or "7 more agents. ... skills".
# Also catches CJK count literals: any number adjacent to 技能 (with optional 个/项 separator and 可组合),
# e.g. "24 项技能", "24个技能", "24 个可组合技能" — the list is illustrative, not exhaustive. The English-only
# pattern let the README.zh-CN.md "24 项技能" regression slip past. Alternation, not a bracket class, for
# multibyte safety under GNU grep + UTF-8.
COUNT_RE='[0-9]+\+?[[:space:]]+(composable[[:space:]]+|beads-native[[:space:]]+|process-discipline[[:space:]]+)*skills\b|Skills[[:space:]]*\([0-9]+[[:space:]]*Total\)|[0-9]+[[:space:]]*(个|项)?[[:space:]]*(可组合)?技能'

# Files excluded from the drift scan (each with a reason):
#   docs/**              macro-driven ({{ skill_count }})
#   CHANGELOG.md         frozen historical entries
#   .internal/**         local working docs
#   site/**              build output
#   .github/workflows/** GHA CI being retired in favor of pre-commit
#   scripts/check-skill-count.sh  guard's own source defines the pattern
#   tests/**             test assertions reference runtime counts (e.g. "0 skills" edge case); self-policing
is_excluded() {
  case "$1" in
    docs/*|CHANGELOG.md|.internal/*|site/*|.github/workflows/*|scripts/check-skill-count.sh|tests/*) return 0 ;;
    *) return 1 ;;
  esac
}

structural_check() {
  local root="$1" rc=0 dirs md d
  dirs=$(find "$root/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  md=$(find "$root/skills" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirs" != "$md" ]; then
    echo "FAIL structural: $dirs skill dirs but $md SKILL.md files"
    for d in "$root"/skills/*/; do
      [ -f "${d}SKILL.md" ] || echo "  -> ${d} has no SKILL.md"
    done
    rc=1
  fi
  return $rc
}

drift_check() {
  local root="$1" rc=0 f
  while IFS= read -r f; do
    is_excluded "$f" && continue
    [ -f "$root/$f" ] || continue
    if grep -nEH -- "$COUNT_RE" "$root/$f" 2>/dev/null; then
      rc=1
    fi
  done < <(git -C "$root" ls-files)
  [ "$rc" -ne 0 ] && echo "FAIL drift: hardcoded skill-count literal(s) above — remove the number (docs {{ skill_count }} macro is the single source)."
  return $rc
}

known_skills_check() {
  local root="$1" rc=0
  local array_skills fs_skills
  array_skills=$(sed -n '/^KNOWN_SKILLS=(/,/^)/p' "$root/install.sh" \
    | grep -vE '^KNOWN_SKILLS=\(|^\)' | tr -s ' \t' '\n' | sed '/^$/d' | sort)
  fs_skills=$(find "$root/skills" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
  if [ "$array_skills" != "$fs_skills" ]; then
    echo "FAIL known-skills: install.sh KNOWN_SKILLS != skills/ directories"
    diff <(echo "$array_skills") <(echo "$fs_skills") | sed 's/^/  /'
    rc=1
  fi
  return $rc
}

self_test() {
  local tmp rc=0
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  mkdir -p "$tmp/skills/alpha" "$tmp/skills/beta" "$tmp/docs"
  printf 'name: alpha\n' > "$tmp/skills/alpha/SKILL.md"
  printf 'name: beta\n'  > "$tmp/skills/beta/SKILL.md"
  printf 'Composable skills here.\n' > "$tmp/README.md"
  printf '21 of the skills are great.\n' >> "$tmp/README.md"   # legit non-total phrasing must NOT trip
  git -C "$tmp" init -q && git -C "$tmp" add -A
  # (a) clean fixture passes both checks
  if structural_check "$tmp" >/dev/null && drift_check "$tmp" >/dev/null; then :; else
    echo "SELF-TEST FAIL: clean fixture should pass"; rc=1; fi
  # (b) injected total-count literals are caught — covers the bare, multi-adjective, and N+ forms
  local form
  for form in 'This repo has 25 skills now.' '25 composable process-discipline skills' 'Run /skills — 25+ skills available' '本仓库有 25 项技能。' '现在有25个可组合技能'; do
    printf '%s\n' "$form" > "$tmp/README.md"; git -C "$tmp" add -A
    if drift_check "$tmp" >/dev/null 2>&1; then echo "SELF-TEST FAIL: injected literal not caught: $form"; rc=1; fi
  done
  printf 'Composable skills here.\n21 of the skills are great.\n' > "$tmp/README.md"; git -C "$tmp" add -A
  # (c) missing SKILL.md is caught by the structural check
  rm -f "$tmp/skills/beta/SKILL.md"; git -C "$tmp" add -A
  if structural_check "$tmp" >/dev/null 2>&1; then echo "SELF-TEST FAIL: missing SKILL.md not caught"; rc=1; fi
  # (d) KNOWN_SKILLS drift is caught, and a matching array passes
  cat > "$tmp/install.sh" << 'FIX'
KNOWN_SKILLS=(
  alpha
)
FIX
  if known_skills_check "$tmp" >/dev/null; then
    echo "SELF-TEST FAIL: KNOWN_SKILLS missing 'beta' should be caught"; rc=1; fi
  cat > "$tmp/install.sh" << 'FIX'
KNOWN_SKILLS=(
  alpha beta
)
FIX
  if ! known_skills_check "$tmp" >/dev/null; then
    echo "SELF-TEST FAIL: matching KNOWN_SKILLS should pass"; rc=1; fi
  [ "$rc" -eq 0 ] && echo "SELF-TEST PASS"
  return $rc
}

case "${1:-}" in
  --self-test) self_test; exit $? ;;
  "")
    structural_check "$REPO_ROOT"; s=$?
    drift_check "$REPO_ROOT"; d=$?
    known_skills_check "$REPO_ROOT"; k=$?
    if [ "$s" -eq 0 ] && [ "$d" -eq 0 ] && [ "$k" -eq 0 ]; then echo "OK: skill-count guard passed"; exit 0; else exit 1; fi
    ;;
  *) echo "usage: $0 [--self-test]" >&2; exit 2 ;;
esac
