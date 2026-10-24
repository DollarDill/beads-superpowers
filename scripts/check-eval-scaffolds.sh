#!/usr/bin/env bash
# Guard: eval scaffolds run as the user, OUTSIDE the eval sandbox
# (`claude plugin eval --scaffold`), so a scaffold may only write fixture
# files. Outside heredoc bodies a scaffold may contain only:
#   the shebang `#!/usr/bin/env bash` (line 1), `set -euo pipefail`,
#   comments, blank lines, `mkdir -p <rel>...`, `cat > <rel> <<'TAG'`
#   (quoted tag, so the body is never expanded) and the heredoc terminator.
# <rel> = [A-Za-z0-9._/-] only: no leading /, no .. segment, no $ or backtick.
# Heredoc bodies are file content and are not inspected.
#
# Usage: check-eval-scaffolds.sh [FILE...]
#   no args: the TRACKED scaffolds of this repo (git ls-files) — never
#   gitignored probes, which are checked by explicit path before first run.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

files=()
if [ $# -gt 0 ]; then
  files=("$@")
else
  if ! listed="$(git -C "$REPO_ROOT" ls-files -- 'evals/*/*/scaffold.sh')"; then
    echo "FAIL: git ls-files failed under $REPO_ROOT"; exit 1
  fi
  while IFS= read -r f; do [ -n "$f" ] && files+=("$REPO_ROOT/$f"); done <<< "$listed"
  if [ "${#files[@]}" -eq 0 ]; then
    echo "FAIL: no scaffolds scanned under $REPO_ROOT"; exit 1
  fi
fi

rc=0
# The eval runs whatever case.yaml's scaffold_script names, so a tracked case
# may only name scaffold.sh — the file this guard actually checks.
if [ $# -eq 0 ]; then
  if ! cases="$(git -C "$REPO_ROOT" ls-files -- 'evals/*/*/case.yaml')"; then
    echo "FAIL: git ls-files failed under $REPO_ROOT"; exit 1
  fi
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    awk -v F="$c" '
      /^[ \t]*scaffold_script:/ {
        v = $0; sub(/^[ \t]*scaffold_script:[ \t]*/, "", v); gsub(/^["\047]|["\047][ \t]*$|[ \t]+$/, "", v)
        if (v != "scaffold.sh") { printf "EVAL-SCAFFOLD: %s:%d: scaffold_script must be scaffold.sh (got %s)\n", F, NR, v; bad = 1 }
      }
      END { exit bad }' "$REPO_ROOT/$c" || rc=1
  done <<< "$cases"
fi
for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then echo "EVAL-SCAFFOLD: $f:0: no such file"; rc=1; continue; fi
  label="${f#"$REPO_ROOT"/}"
  awk -v F="$label" '
    function bad(reason) { printf "EVAL-SCAFFOLD: %s:%d: %s\n", F, NR, reason; err = 1 }
    function path_ok(p) {
      if (p ~ /[$`]/) { bad("expansion in path"); return 0 }
      if (p ~ /^\//) { bad("absolute path"); return 0 }
      if (p ~ /(^|\/)\.\.(\/|$)/) { bad("parent-dir segment"); return 0 }
      if (p !~ /^[A-Za-z0-9._\/-]+$/) { bad("disallowed path characters"); return 0 }
      return 1
    }
    inhd { if ($0 == term) inhd = 0; next }
    NR == 1 { if ($0 != "#!/usr/bin/env bash") bad("line 1 must be #!/usr/bin/env bash"); next }
    /^[ \t]*$/ || /^[ \t]*#/ { next }
    $0 == "set -euo pipefail" { next }
    $1 == "mkdir" && $2 == "-p" && NF >= 3 { for (i = 3; i <= NF; i++) path_ok($i); next }
    $1 == "cat" && $2 == ">" && NF == 4 && $4 ~ /^<</ {
      path_ok($3)
      tag = $4; sub(/^<</, "", tag)
      if (tag !~ /^\047[A-Za-z_]+\047$/) { bad("unquoted heredoc tag"); exit }
      gsub(/\047/, "", tag); term = tag; inhd = 1; start = NR
      next
    }
    { bad("disallowed command") }
    END {
      if (inhd) { printf "EVAL-SCAFFOLD: %s:%d: unterminated heredoc\n", F, start; err = 1 }
      exit err
    }' "$f" || rc=1
done
exit "$rc"
