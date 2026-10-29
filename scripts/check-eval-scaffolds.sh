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
#   no args: every TRACKED entry in the repo (git ls-files -s), because the
#     eval discovers any directory named evals anywhere in the plugin. Paths
#     must be printable ASCII; inside any evals/ tree (any depth, any case) no
#     symlink or gitlink, no case-variant of case.yaml/scaffold.sh, each
#     case.yaml canonical, each scaffold.sh scanned; and the manifest may not
#     set experimental.evals. Also: .claude-plugin/plugin.json must exist (a
#     root plugin.json is checked too), no gitlink anywhere, and every
#     canonical case.yaml's scaffold.sh must be tracked.
#   FILE...: those scaffolds, plus any case.yaml beside each one.
#
# Scope: this guards TRACKED content, i.e. what a commit can introduce. The
# eval also walks untracked files on disk, which this guard does not see:
# gitignored probes (.internal/evals/calib — check each by explicit path
# before its first run), worktrees under .worktrees/, untracked targets of a
# tracked symlink outside evals trees, and a clone whose path has an `evals`
# ancestor. Run --scaffold only from a checkout whose untracked content you trust.
# It also assumes the eval targets the repo root (`claude plugin eval .`):
# aiming it at a subdirectory with its own .claude-plugin/plugin.json makes
# that directory the plugin root, and its manifest is not checked here.
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
  # The eval discovers cases far beyond top-level evals/ (2.1.310): any
  # directory named evals anywhere in the plugin (16 levels deep), symlinked
  # directories, a case.yaml opened case-insensitively on APFS, and an eval dir
  # moved by the manifest. So scan every tracked entry in the repo.
  # The tool reads .claude-plugin/plugin.json, else a root plugin.json (when
  # the first is absent or .claude-plugin is a file); either may set
  # experimental.evals. Require the first and check both.
  check_manifest() {  # file label
    if ! python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); e=d.get("experimental"); sys.exit(1 if isinstance(e, dict) and "evals" in e else 0)' "$1" 2>/dev/null; then
      echo "EVAL-SCAFFOLD: $2:0: manifest sets experimental.evals or is unreadable (moves the eval dir out of the guard's view)"; rc=1
    fi
  }
  if [ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]; then
    check_manifest "$REPO_ROOT/.claude-plugin/plugin.json" .claude-plugin/plugin.json
  else
    echo "EVAL-SCAFFOLD: .claude-plugin/plugin.json:0: manifest missing (the eval would fall back to a root plugin.json)"; rc=1
  fi
  if [ -e "$REPO_ROOT/plugin.json" ]; then check_manifest "$REPO_ROOT/plugin.json" plugin.json; fi
  declare -A tracked_scaffold=()
  case_dirs=()
  if ! git -C "$REPO_ROOT" ls-files -s -- . >/dev/null; then
    echo "FAIL: git ls-files failed under $REPO_ROOT"; exit 1
  fi
  entries=()
  mapfile -d '' entries < <(git -C "$REPO_ROOT" ls-files -s -z -- .)
  for e in "${entries[@]}"; do
    mode="${e%% *}"; p="${e#*$'\t'}"
    # Delete every printable ASCII byte (0x20-0x7E); anything left is bad. The
    # 'x' sentinel is appended AFTER tr, so a leftover trailing newline is not
    # stripped by $(...).
    if [ "$(printf '%s' "$p" | tr -d ' -~'; printf x)" != x ]; then
      echo "EVAL-SCAFFOLD: $(printf '%q' "$p"):0: non-printable or non-ASCII byte in tracked path"; rc=1; continue
    fi
    in_tree=0
    case "/$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')/" in */evals/*) in_tree=1 ;; esac
    if [ "$in_tree" = 0 ]; then
      # A gitlink anywhere hides its submodule's files (and any evals/ tree
      # inside it) from git ls-files, while the eval walks the checkout.
      if [ "$mode" = 160000 ]; then
        echo "EVAL-SCAFFOLD: $p:0: gitlink (submodule): its files are invisible to this guard"; rc=1
      fi
      continue
    fi
    if [ "$mode" = 120000 ] || [ "$mode" = 160000 ]; then
      echo "EVAL-SCAFFOLD: $p:0: symlink or gitlink inside an eval tree"; rc=1; continue
    fi
    base="${p##*/}"; lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
    case "$base" in
      case.yaml) check_case_yaml "$REPO_ROOT/$p" "$p"; case_dirs+=("${p%/*}") ;;
      scaffold.sh) files+=("$REPO_ROOT/$p"); tracked_scaffold["$p"]=1 ;;
      *) if [ "$lower" = case.yaml ] || [ "$lower" = scaffold.sh ]; then
           echo "EVAL-SCAFFOLD: $p:0: case-variant of case.yaml or scaffold.sh"; rc=1
         fi ;;
    esac
  done
  # A canonical case.yaml runs the scaffold.sh beside it: that file must be
  # tracked, or the guard never read what would run.
  for d in "${case_dirs[@]}"; do
    if [ -z "${tracked_scaffold["$d/scaffold.sh"]:-}" ]; then
      echo "EVAL-SCAFFOLD: $d/case.yaml:0: its scaffold.sh is not tracked"; rc=1
    fi
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
      if (p ~ /^-/) { bad("option-shaped path"); return 0 }
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
