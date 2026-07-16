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
  # pairs: "<english-source> <zh-translation> <require_banner>"
  local pairs=(
    "README.md README.zh-CN.md no"
    "docs/index.md docs/index.zh.md yes"
    "docs/getting-started.md docs/getting-started.zh.md yes"
    "docs/methodology.md docs/methodology.zh.md yes"
    "docs/skills.md docs/skills.zh.md yes"
    "docs/workflow.md docs/workflow.zh.md yes"
    "docs/tips.md docs/tips.zh.md yes"
    "docs/migration.md docs/migration.zh.md yes"
  )

  # Completeness assertion: every top-level docs/*.md page (excluding *.zh.md,
  # no recursion — docs/assets/ etc. out of scope) must be registered as the
  # EN member of a pair above, else a new page silently escapes zh-parity
  # checking entirely. README.zh-CN.md stays handled separately (not under docs/).
  local registered=" " pair page
  for pair in "${pairs[@]}"; do
    # shellcheck disable=SC2086
    set -- $pair
    registered="$registered$1 "
  done
  for page in docs/*.md; do
    [ -e "$page" ] || continue
    case "$page" in
      *.zh.md) continue ;;
    esac
    case "$registered" in
      *" $page "*) ;;
      *) echo "FAIL: $page not registered for zh-parity"; fail=1 ;;
    esac
  done

  local en zh banner
  for pair in "${pairs[@]}"; do
    # shellcheck disable=SC2086
    set -- $pair; en="$1"; zh="$2"; banner="$3"
    if [ ! -f "$zh" ]; then echo "SKIP (not yet translated): $zh"; continue; fi
    if check_pair "$en" "$zh" "$banner"; then echo "ok: $zh"; else fail=1; fi
  done
  if [ "$fail" = 0 ]; then echo "check-zh-docs: PASS"; else echo "check-zh-docs: FAIL"; fi
  exit $fail
}

main "$@"
