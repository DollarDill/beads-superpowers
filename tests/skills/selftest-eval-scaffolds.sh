#!/usr/bin/env bash
# Guard-the-guards for check-eval-scaffolds.sh. Stages a clean scaffold (only
# the allowed command shapes, with path-like text inside a quoted heredoc
# body), confirms it passes, then applies one mutation per rule and confirms
# each FAILS naming its reason. Also covers the no-argument production path:
# tracked scaffolds only, an untracked bad scaffold ignored, zero scanned = FAIL.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/scripts/check-eval-scaffolds.sh"
fails=0

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
S=evals/x/c/scaffold.sh

stage() {  # pristine clean scaffold at $FIX/$S
  rm -rf "$FIX"; FIX="$(mktemp -d)"
  mkdir -p "$FIX/evals/x/c"
  cat > "$FIX/$S" <<'CLEAN'
#!/usr/bin/env bash
# Seeds a toy app.
set -euo pipefail

mkdir -p src .internal/specs
cat > src/app.js <<'EOF'
// Settings page: GET /admin is guarded.
import { range } from '../src/range.js';
const home = `${process.env.HOME}/x`;
EOF
cat > README.md <<'EOT'
Run `npm test`, then `git commit`.
EOT
CLEAN
}
mutate() { printf '%s\n' "$1" >> "$FIX/$S"; }
want() { printf '^EVAL-SCAFFOLD: .*scaffold\\.sh:[0-9]+: %s' "$1"; }

expect_pass() {  # label [cmd...]   (default: guard on the staged file)
  local label="$1"; shift
  [ $# -gt 0 ] || set -- bash "$GUARD" "$FIX/$S"
  if "$@" >/dev/null 2>&1; then echo "OK   clean fixture passes: $label"
  else echo "SELFTEST FAIL: clean fixture should pass but failed: $label"; fails=1; fi
}
expect_fail() {  # label output-regex [cmd...]
  local label="$1" re="$2" out; shift 2
  [ $# -gt 0 ] || set -- bash "$GUARD" "$FIX/$S"
  if out="$("$@" 2>&1)"; then echo "SELFTEST FAIL: mutation NOT caught: $label"; fails=1
  elif ! printf '%s\n' "$out" | grep -Eq -- "$re"; then
    echo "SELFTEST FAIL: caught, but output lacks /$re/: $label"; printf '%s\n' "$out" | sed 's/^/     /'; fails=1
  else echo "OK   mutation caught: $label"; fi
}

stage; expect_pass "heredoc-body-ignored (clean control)"
stage; mutate 'mkdir -p /tmp/x';                expect_fail "absolute-path"       "$(want 'absolute path')"
stage; printf "cat > ../x <<'EOF'\nhi\nEOF\n" >> "$FIX/$S"
expect_fail "dotdot" "$(want 'parent-dir segment')"
stage; mutate 'git init';                       expect_fail "git-command"         "$(want 'disallowed command')"
stage; printf 'cat > a <<EOF\nhi\nEOF\n' >> "$FIX/$S"
expect_fail "unquoted-tag" "$(want 'unquoted heredoc tag')"
stage
# shellcheck disable=SC2016  # literal fixture text, never expanded
mutate 'mkdir -p "$HOME/x"'
expect_fail "dollar-in-path" "$(want 'expansion in path')"
stage; printf "cat > b <<'EOF'\nnever closed\n" >> "$FIX/$S"
expect_fail "unterminated heredoc" "$(want 'unterminated heredoc')"
# Line 1 must be exactly the bash shebang: a comment-shaped line 1 can name any interpreter.
stage
# shellcheck disable=SC2016  # literal fixture text, never expanded
{ printf '%s\n' '#!/bin/sh -c touch${IFS}PWNED'; tail -n +2 "$FIX/$S"; } > "$FIX/$S.new" && mv -f "$FIX/$S.new" "$FIX/$S"
expect_fail "shebang (any interpreter on line 1)" "$(want 'line 1 must be')"

# No-argument production path: the guard anchors to its own repo and scans
# tracked scaffolds only (git ls-files), never gitignored or untracked ones.
gitc() { GIT_CONFIG_GLOBAL=/dev/null git -C "$FIX" -c user.name=selftest \
  -c user.email=selftest@invalid -c commit.gpgsign=false \
  -c init.defaultBranch=main -c core.hooksPath=/dev/null "$@"; }
# shellcheck disable=SC2317,SC2329  # invoked indirectly, as a command word of expect_*
in_repo() { bash "$FIX/scripts/check-eval-scaffolds.sh"; }
stage; mkdir -p "$FIX/scripts"; cp -f "$GUARD" "$FIX/scripts/"
gitc init -q; gitc add evals scripts; gitc commit -qm init
mkdir -p "$FIX/evals/x/untracked"; printf 'git init\n' > "$FIX/evals/x/untracked/scaffold.sh"
expect_pass "no args: untracked bad scaffold ignored" in_repo
mutate 'git init'
expect_fail "no args: tracked dirty scaffold scanned" "$(want 'disallowed command')" in_repo
# The eval runs whatever case.yaml's scaffold_script names, not just scaffold.sh.
gitc checkout -q -- "$S"   # undo the previous mutation: this one must fail on case.yaml alone
printf 'schema_version: "1.1"\nname: c\ncontext:\n  scaffold_script: setup.sh\n' > "$FIX/evals/x/c/case.yaml"
gitc add evals/x/c/case.yaml
expect_fail "no args: case.yaml names a script other than scaffold.sh" '^EVAL-SCAFFOLD: evals/x/c/case\.yaml:[0-9]+: scaffold_script must be scaffold\.sh' in_repo
gitc rm -q --cached evals/x/c/case.yaml
gitc rm -q --cached "$S"
expect_fail "no args: zero tracked scaffolds is never a PASS" '^FAIL: no scaffolds scanned' in_repo

exit "$fails"
