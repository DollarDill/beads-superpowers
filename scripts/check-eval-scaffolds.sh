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
#
# The eval runs whatever case.yaml's context.scaffold_script names, and reads
# case.yaml with a full YAML parser. So no YAML spelling is parsed here: every
# case.yaml must be byte-for-byte the canonical text
#   schema_version: "1.1" / name: <its dir> / context: / scaffold_script: scaffold.sh
# which names the scaffold.sh beside it — a file this guard scans.
#
# Usage: check-eval-scaffolds.sh [FILE...]
#   no args: every TRACKED file under evals/, at any depth (git ls-files):
#     each case.yaml must be canonical, each scaffold.sh is scanned, and any
#     path with a non-ASCII byte is rejected. Gitignored probes are never
#     scanned implicitly; they are checked by explicit path before first run.
#   FILE...: those scaffolds, plus any case.yaml beside each one.
set -uo pipefail
# Byte-wise comparisons everywhere: a UTF-8 locale lets awk treat invisible
# characters (U+200B, U+FEFF, U+00AD, U+2060) as equal to nothing.
export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rc=0
check_case_yaml() {  # file label
  local dir; dir="$(basename "$(dirname "$1")")"
  if ! printf 'schema_version: "1.1"\nname: %s\ncontext:\n  scaffold_script: scaffold.sh\n' "$dir" | cmp -s - "$1"; then
    echo "EVAL-SCAFFOLD: $2:0: not the canonical case.yaml (schema_version \"1.1\", name: $dir, context.scaffold_script: scaffold.sh)"
    rc=1
  fi
}

files=()
if [ $# -gt 0 ]; then
  for f in "$@"; do
    files+=("$f")
    sib="$(dirname "$f")/case.yaml"
    if [ -f "$sib" ]; then check_case_yaml "$sib" "${sib#"$REPO_ROOT"/}"; fi
  done
else
  if ! git -C "$REPO_ROOT" ls-files -- evals/ >/dev/null; then
    echo "FAIL: git ls-files failed under $REPO_ROOT"; exit 1
  fi
  tracked=()
  mapfile -d '' tracked < <(git -C "$REPO_ROOT" ls-files -z -- evals/)
  for p in "${tracked[@]}"; do
    if [ -n "$(printf '%s' "$p" | tr -d ' -~')" ]; then
      echo "EVAL-SCAFFOLD: $p:0: non-ASCII byte in tracked path"; rc=1; continue
    fi
    case "$p" in
      */case.yaml) check_case_yaml "$REPO_ROOT/$p" "$p" ;;
      */scaffold.sh) files+=("$REPO_ROOT/$p") ;;
    esac
  done
  if [ "${#files[@]}" -eq 0 ]; then
    echo "FAIL: no scaffolds scanned under $REPO_ROOT"; exit 1
  fi
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
