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
# The eval runs whatever case.yaml's scaffold_script names. Every tracked
# case.yaml must be byte-for-byte the canonical form, so no YAML spelling
# (flow mapping, quoted/escaped/explicit keys, JSON, invisible Unicode) can
# name a script the guard never scanned — each bypass below was reproduced
# against the eval tool's own YAML parser in the re-review of c4e27c4.
gitc checkout -q -- "$S"   # undo the previous mutation: these must fail on case.yaml alone
CY="$FIX/evals/x/c/case.yaml"
canon() { printf 'schema_version: "1.1"\nname: c\ncontext:\n  scaffold_script: scaffold.sh\n' > "$CY"; }
canon; gitc add evals/x/c/case.yaml
expect_pass "no args: canonical case.yaml (control)" in_repo
CYRE='^EVAL-SCAFFOLD: evals/x/c/case\.yaml:0: not the canonical case\.yaml'
yaml_case() {  # label printf-%b-content
  printf '%b' "$2" > "$CY"
  expect_fail "no args: case.yaml $1" "$CYRE" in_repo
  canon
}
yaml_case "block form, other script" 'schema_version: "1.1"\nname: c\ncontext:\n  scaffold_script: setup.sh\n'
yaml_case "flow mapping"             'schema_version: "1.1"\nname: c\ncontext: {scaffold_script: setup.sh}\n'
yaml_case "double-quoted key"        'schema_version: "1.1"\nname: c\ncontext:\n  "scaffold_script": setup.sh\n'
yaml_case "single-quoted key"        "schema_version: \"1.1\"\nname: c\ncontext:\n  'scaffold_script': setup.sh\n"
yaml_case "space before colon"       'schema_version: "1.1"\nname: c\ncontext:\n  scaffold_script : setup.sh\n'
yaml_case "explicit key"             'schema_version: "1.1"\nname: c\ncontext:\n  ? scaffold_script\n  : setup.sh\n'
yaml_case "JSON form"                '{"schema_version": "1.1", "name": "c", "context": {"scaffold_script": "setup.sh"}}\n'
yaml_case "escaped key"              'schema_version: "1.1"\nname: c\ncontext:\n  "scaffold\\x5fscript": setup.sh\n'
yaml_case "zero-width suffix value"  'schema_version: "1.1"\nname: c\ncontext:\n  scaffold_script: scaffold.sh\0342\0200\0213\n'
# The file such a case.yaml would run: a tracked path with a non-ASCII byte.
ZW="$(printf 'scaffold.sh\342\200\213')"
printf 'touch PWNED\n' > "$FIX/evals/x/c/$ZW"; gitc add "evals/x/c/$ZW"
expect_fail "no args: non-ASCII tracked path" '^EVAL-SCAFFOLD: .*: non-printable or non-ASCII byte in tracked path' in_repo
gitc rm -q --cached "evals/x/c/$ZW"; rm -f "$FIX/evals/x/c/$ZW"
# Cases one level below evals/ are discovered by the tool, so they are scanned too.
mkdir -p "$FIX/evals/shallow"
printf 'schema_version: "1.1"\nname: shallow\ncontext:\n  scaffold_script: setup.sh\n' > "$FIX/evals/shallow/case.yaml"
printf 'git init\n' > "$FIX/evals/shallow/setup.sh"
gitc add evals/shallow
expect_fail "no args: shallow case.yaml scanned" '^EVAL-SCAFFOLD: evals/shallow/case\.yaml:0: not the canonical case\.yaml' in_repo
printf 'schema_version: "1.1"\nname: shallow\ncontext:\n  scaffold_script: scaffold.sh\n' > "$FIX/evals/shallow/case.yaml"
printf '#!/usr/bin/env bash\ngit init\n' > "$FIX/evals/shallow/scaffold.sh"; gitc add evals/shallow
expect_fail "no args: shallow scaffold.sh scanned" '^EVAL-SCAFFOLD: evals/shallow/scaffold\.sh:2: disallowed command' in_repo
gitc rm -q -r --cached evals/shallow; rm -rf "$FIX/evals/shallow"
# Explicit-path mode also checks a case.yaml sitting beside the named scaffold.
printf 'context: {scaffold_script: setup.sh}\n' > "$CY"
expect_fail "explicit file: sibling case.yaml checked" '^EVAL-SCAFFOLD: .*case\.yaml:0: not the canonical case\.yaml' bash "$GUARD" "$FIX/$S"
canon
gitc rm -q --cached evals/x/c/case.yaml
# Discovery is wider than top-level evals/ (re-review of 78b9e9d, from the
# 2.1.310 binary): any directory named evals anywhere in the plugin, symlinked
# directories, case-insensitive filesystems, and the manifest's eval dir.
mkdir -p "$FIX/skills/demo/evals/h1"
printf 'schema_version: "1.1"\nname: h1\ncontext:\n  scaffold_script: pwn.sh\n' > "$FIX/skills/demo/evals/h1/case.yaml"
gitc add skills/demo
expect_fail "N1: nested evals dir case.yaml scanned" '^EVAL-SCAFFOLD: skills/demo/evals/h1/case\.yaml:0: not the canonical case\.yaml' in_repo
printf 'schema_version: "1.1"\nname: h1\ncontext:\n  scaffold_script: scaffold.sh\n' > "$FIX/skills/demo/evals/h1/case.yaml"
printf '#!/usr/bin/env bash\ngit init\n' > "$FIX/skills/demo/evals/h1/scaffold.sh"; gitc add skills/demo
expect_fail "N1: nested evals dir scaffold.sh scanned" '^EVAL-SCAFFOLD: skills/demo/evals/h1/scaffold\.sh:2: disallowed command' in_repo
gitc rm -q -r --cached skills/demo; rm -rf "$FIX/skills/demo"
mkdir -p "$FIX/fixtures/h2"; ln -s ../fixtures/h2 "$FIX/evals/h2link"; gitc add evals/h2link
expect_fail "N2: symlink inside an eval tree" '^EVAL-SCAFFOLD: evals/h2link:0: symlink or gitlink inside an eval tree' in_repo
gitc rm -q --cached evals/h2link; rm -f "$FIX/evals/h2link"; rm -rf "$FIX/fixtures"
mkdir -p "$FIX/evals/h3"; printf 'x\n' > "$FIX/evals/h3/Case.yaml"; gitc add evals/h3
expect_fail "N3: case-variant case.yaml" '^EVAL-SCAFFOLD: evals/h3/Case\.yaml:0: case-variant of case\.yaml or scaffold\.sh' in_repo
gitc rm -q -r --cached evals/h3; rm -rf "$FIX/evals/h3"
mkdir -p "$FIX/evals/h3b"; printf 'git init\n' > "$FIX/evals/h3b/Scaffold.sh"; gitc add evals/h3b
expect_fail "N3: case-variant scaffold.sh" '^EVAL-SCAFFOLD: evals/h3b/Scaffold\.sh:0: case-variant of case\.yaml or scaffold\.sh' in_repo
gitc rm -q -r --cached evals/h3b; rm -rf "$FIX/evals/h3b"
mkdir -p "$FIX/.claude-plugin"; printf '{"name": "x"}\n' > "$FIX/.claude-plugin/plugin.json"; gitc add .claude-plugin
expect_pass "N4: manifest without experimental.evals (control)" in_repo
printf '{"name": "x", "experimental": {"evals": "qa"}}\n' > "$FIX/.claude-plugin/plugin.json"
expect_fail "N4: manifest moves the eval dir" '^EVAL-SCAFFOLD: \.claude-plugin/plugin\.json:0: manifest sets experimental\.evals' in_repo
gitc rm -q -r --cached .claude-plugin; rm -rf "$FIX/.claude-plugin"
gitc update-index --add --cacheinfo "160000,$(gitc rev-parse HEAD),evals/sub"
expect_fail "N5: gitlink inside an eval tree" '^EVAL-SCAFFOLD: evals/sub:0: symlink or gitlink inside an eval tree' in_repo
gitc rm -q --cached evals/sub
NL="$(printf 'evals/x/c/a\nb')"; printf 'x\n' > "$FIX/$NL"; gitc add "$NL"
expect_fail "control byte (newline) in tracked path" '^EVAL-SCAFFOLD: .*: non-printable or non-ASCII byte in tracked path' in_repo
gitc rm -q --cached "$NL"; rm -f "$FIX/$NL"
gitc rm -q --cached "$S"
expect_fail "no args: zero tracked scaffolds is never a PASS" '^FAIL: no scaffolds scanned' in_repo

exit "$fails"
