#!/usr/bin/env bash
# Verify zh docs preserve structure & do-not-translate (DNT) terms vs their English source.
# Heuristic structural gate — pairs with manual prose-quality review. See
# .internal/plans/2026-06-28-zh-docs-i18n.md (Task 2) and the spec's DNT list.
#
# Usage:
#   scripts/check-zh-docs.sh            # check the real docs pairs
#   scripts/check-zh-docs.sh --self-test # prove the gate FAILS on a broken fixture (ADR-0025 pattern)
set -uo pipefail

# check_pair <english-source> <zh-translation> [require_banner]
# Echoes FAIL lines; returns non-zero if any check fails.
check_pair() {
  local en="$1" zh="$2" require_banner="${3:-yes}" rc=0
  # (a) fenced-code-block parity — same number of ``` fence lines
  local en_fences zh_fences
  en_fences=$(grep -c '^```' "$en")
  zh_fences=$(grep -c '^```' "$zh")
  if [ "$en_fences" != "$zh_fences" ]; then
    echo "FAIL $zh: code-fence count $zh_fences != source $en_fences"; rc=1
  fi
  # (b) every {{ macro }} token in the English file must appear verbatim in zh
  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    grep -qF "$tok" "$zh" || { echo "FAIL $zh: missing macro token $tok"; rc=1; }
  done < <(grep -oE '\{\{[^}]*\}\}' "$en" | sort -u)
  # (c) DNT product/jargon terms present in en must remain present in zh
  local term
  for term in '`bd ' 'Beads' 'worktree' 'TodoWrite'; do
    if grep -qF "$term" "$en"; then
      grep -qF "$term" "$zh" || { echo "FAIL $zh: DNT term '$term' absent"; rc=1; }
    fi
  done
  # (d) docs pages must carry the MT banner + frontmatter flag (README is exempt)
  if [ "$require_banner" = "yes" ]; then
    grep -q 'machine_translated: true' "$zh" || { echo "FAIL $zh: missing 'machine_translated: true' frontmatter"; rc=1; }
    grep -q '机器翻译' "$zh" || { echo "FAIL $zh: missing MT banner (机器翻译)"; rc=1; }
  fi
  return $rc
}

self_test() {
  local d en good bad
  d=$(mktemp -d)
  en="$d/page.md"; good="$d/page.zh.md"; bad="$d/bad.zh.md"
  # Fixtures are literal markdown; backticks and {{ }} must NOT expand.
  # shellcheck disable=SC2016
  printf '# Title\n\nUse `bd ready` and {{ skill_count }} skills.\n\n```bash\nbd ready\n```\n' > "$en"
  # good: same structure, banner + frontmatter, DNT preserved
  # shellcheck disable=SC2016
  printf -- '---\nmachine_translated: true\n---\n!!! warning "机器翻译"\n\n# 标题\n\n使用 `bd ready` 和 {{ skill_count }} 个技能。\n\n```bash\nbd ready\n```\n' > "$good"
  # bad: dropped the macro token, deleted the code fence, removed the banner
  # shellcheck disable=SC2016
  printf -- '---\n---\n# 标题\n\n使用 `bd ready`。\n' > "$bad"

  local pass=0
  if check_pair "$en" "$good" yes >/dev/null 2>&1; then echo "self-test: good fixture PASSES (ok)"; else echo "self-test FAIL: good fixture rejected"; pass=1; fi
  if check_pair "$en" "$bad" yes >/dev/null 2>&1; then echo "self-test FAIL: gate is BLIND (broken fixture passed)"; pass=1; else echo "self-test: broken fixture FAILS (ok — gate catches violations)"; fi
  rm -rf "$d"
  if [ "$pass" = 0 ]; then echo "check-zh-docs --self-test: PASS"; else echo "check-zh-docs --self-test: FAIL"; fi
  return $pass
}

main() {
  cd "$(dirname "$0")/.." || exit 2
  if [ "${1:-}" = "--self-test" ]; then
    self_test; exit $?
  fi
  local fail=0
  # README pair — outside docs/, banner-exempt, kept explicit.
  if check_pair README.md README.zh-CN.md no; then echo "ok: README.zh-CN.md"; else fail=1; fi

  # STRUCTURAL docs pairing (self-registering): docs/en/X.md <-> docs/zh/X.md,
  # asserted 1:1 in BOTH directions. Adding a page pair needs no guard edit;
  # an EN page without its ZH twin fails, and an orphan ZH page fails too.
  # docs/assets/ and docs/decisions/ are locale-independent and out of scope.
  local en zh base
  for en in docs/en/*.md; do
    [ -e "$en" ] || continue
    base=$(basename "$en")
    zh="docs/zh/$base"
    if [ ! -f "$zh" ]; then echo "FAIL: $zh missing (no ZH twin for $en)"; fail=1; continue; fi
    if check_pair "$en" "$zh" yes; then echo "ok: $zh"; else fail=1; fi
  done
  for zh in docs/zh/*.md; do
    [ -e "$zh" ] || continue
    base=$(basename "$zh")
    if [ ! -f "docs/en/$base" ]; then echo "FAIL: docs/en/$base missing (orphan ZH page $zh)"; fail=1; fi
  done
  if [ "$fail" = 0 ]; then echo "check-zh-docs: PASS"; else echo "check-zh-docs: FAIL"; fi
  exit $fail
}

main "$@"
