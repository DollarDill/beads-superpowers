#!/usr/bin/env bash
# test-path-containment.sh — one table of PATH-entry rows, run against every
# place that cleans PATH before running a tool: the launcher's bash walk
# (hooks/run-hook.cmd), hooks/session-start's PATH clean-up (bd, sed and every
# other tool it calls; run directly and in the harness's launcher shape), and
# the PATH each plugin hands its own `bd memories` fallback (Hermes and
# OpenCode), install.sh's hook_bash, the bash it registers as the hook's
# interpreter, and the npx-tier fallback hook install.sh writes. All must
# apply one containment rule, so they share the rows.
#
# The rule (hooks/run-hook.cmd's bsp_outside): an absolute entry is dropped when
# it has a . or .. component, literally starts with the cwd (logical, physical
# or canonical), lies physically inside the cwd tree or the project root
# (CLAUDE_PROJECT_DIR, else CURSOR_PROJECT_DIR, else the highest .git ancestor
# of the cwd), or when a root variable is relative or does not resolve (then
# every entry is dropped). An absolute entry inside the project is what npm
# exec (<proj>/node_modules/.bin) and direnv PATH_add put on PATH.
#
# Each row puts its entry first on PATH, then an outside bin and /usr/bin:/bin.
# Every directory holds a bash, a bd and a sed that leave a marker and then
# behave like the real tool. Expectations: drop (the entry's tools never run,
# the outside bin's do), all (no entry survives: neither runs) and keep (the
# entry's tools run).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
bash_bin="$(command -v bash)"
real_sed="$(command -v sed)"
py_bin="$(command -v python3 || true)"
node_bin="$(command -v node || true)"

report() { # name | ok(0/1) | detail
  if [ "$2" = 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; echo "  $3"; fail=1; fi
}

MK="$TMP/markers"
mkdir -p "$MK"
# plant <dir> <marker prefix>: a bash, bd and sed that mark, then act real.
plant() {
  mkdir -p "$1"
  printf '#!/bin/sh\n: > "%s/%s-bash"\nexec "%s" "$@"\n' "$MK" "$2" "$bash_bin" >"$1/bash"
  printf '#!/bin/sh\n: > "%s/%s-bd"\necho "Memories (1):"\n' "$MK" "$2" >"$1/bd"
  printf '#!/bin/sh\n: > "%s/%s-sed"\nexec "%s" "$@"\n' "$MK" "$2" "$real_sed" >"$1/sed"
  chmod +x "$1/bash" "$1/bd" "$1/sed"
}
markers() { # prints the markers left, sorted, and clears them
  local m s=""
  for m in "$MK"/*; do [ -e "$m" ] && s="$s ${m##*/}"; done
  rm -f "$MK"/*
  printf '%s' "$s"
}

OUT="$TMP/outside/bin"
plant "$OUT" out
AB="$TMP/ab/proj"
mkdir -p "$AB/.git" "$AB/other" "$TMP/ab/nogit/other"
plant "$AB/node_modules/.bin" ran
plant "$AB/sub" ran
plant "$TMP/ab/nogit/sub" ran
ln -s proj/sub "$TMP/ab/alias"
# An entry literally under the cwd that a symlink carries outside it.
mkdir -p "$TMP/ct/cwd"
plant "$TMP/ct/elsewhere" ran
ln -s ../elsewhere "$TMP/ct/cwd/out"
ln -s ct/cwd "$TMP/ctl"
CTP=$(cd -P "$TMP/ct/cwd" && pwd -P)
FH="$TMP/fakehome"
mkdir -p "$FH/work"
plant "$FH/.local/bin" ran
plant "$TMP/legit/bin" ran
H="$TMP/home"
mkdir -p "$H"

# Rows: name | cwd | PWD | first PATH entry | expect | extra env (space-separated)
rows() {
  cat <<ROWS
cwd tree, node_modules/.bin, CLAUDE_PROJECT_DIR|$AB|$AB|$AB/node_modules/.bin|drop|CLAUDE_PROJECT_DIR=$AB
cwd tree, node_modules/.bin, .git root|$AB|$AB|$AB/node_modules/.bin|drop|
CLAUDE_PROJECT_DIR root, sibling cwd|$AB/other|$AB/other|$AB/sub|drop|CLAUDE_PROJECT_DIR=$AB
CURSOR_PROJECT_DIR root, sibling cwd|$AB/other|$AB/other|$AB/sub|drop|CURSOR_PROJECT_DIR=$AB
.git ancestor root, sibling cwd|$AB/other|$AB/other|$AB/sub|drop|
symlinked into the project|$AB|$AB|$TMP/ab/alias|drop|CLAUDE_PROJECT_DIR=$AB
.. component|$TMP/ab/nogit/other|$TMP/ab/nogit/other|$TMP/ab/nogit/other/../sub|drop|
. component|$TMP/ab/nogit/other|$TMP/ab/nogit/other|$TMP/ab/nogit/./sub|drop|
.. component, no cwd prefix|$TMP/ab/nogit/other|$TMP/ab/nogit/other|$TMP/ab/nogit/sub/../sub|drop|
literal cwd prefix, symlinked out|$TMP/ct/cwd|$TMP/ct/cwd|$TMP/ct/cwd/out|drop|CLAUDE_PROJECT_DIR=$TMP/ct/cwd
logical cwd prefix|$TMP/ctl|$TMP/ctl|$TMP/ctl/out|drop|CLAUDE_PROJECT_DIR=$TMP/ct/cwd
physical cwd prefix|$TMP/ctl|$TMP/ctl|$CTP/out|drop|CLAUDE_PROJECT_DIR=$TMP/ct/cwd
PWD spelled //|$TMP/ctl|/$TMP/ctl|$TMP/ctl/out|drop|CLAUDE_PROJECT_DIR=$TMP/ct/cwd
entry spelled //|$TMP/ctl|$TMP/ctl|/$TMP/ctl/out|drop|CLAUDE_PROJECT_DIR=$TMP/ct/cwd
CLAUDE_PROJECT_DIR spelled //|$AB/other|$AB/other|$AB/sub|drop|CLAUDE_PROJECT_DIR=/$AB
HOME is CLAUDE_PROJECT_DIR, ~/.local/bin|$FH/work|$FH/work|~/.local/bin|drop|HOME=$FH CLAUDE_PROJECT_DIR=$FH
HOME is CLAUDE_PROJECT_DIR, absolute|$FH/work|$FH/work|$FH/.local/bin|drop|HOME=$FH CLAUDE_PROJECT_DIR=$FH
relative CLAUDE_PROJECT_DIR|$AB|$AB|$TMP/legit/bin|all|CLAUDE_PROJECT_DIR=proj
unresolvable CLAUDE_PROJECT_DIR|$AB|$AB|$TMP/legit/bin|all|CLAUDE_PROJECT_DIR=$TMP/no-such-root
relative CURSOR_PROJECT_DIR beside an absolute CLAUDE_PROJECT_DIR|$AB|$AB|$TMP/legit/bin|all|CLAUDE_PROJECT_DIR=$AB CURSOR_PROJECT_DIR=proj
control: outside entry, CLAUDE_PROJECT_DIR set|$AB|$AB|$TMP/legit/bin|keep|CLAUDE_PROJECT_DIR=$AB
control: ~/.local/bin, project root elsewhere|$AB|$AB|~/.local/bin|keep|HOME=$FH CLAUDE_PROJECT_DIR=$AB
control: absolute ~/.local/bin, .git root elsewhere|$AB/other|$AB/other|$FH/.local/bin|keep|HOME=$FH
control: outside entry, CLAUDE_PROJECT_DIR spelled //|$AB|$AB|$TMP/legit/bin|keep|CLAUDE_PROJECT_DIR=/$AB
control: outside entry, inherited PWD names no directory|$AB|$TMP/no-such-dir|$TMP/legit/bin|keep|CLAUDE_PROJECT_DIR=$AB
ROWS
}

# On a case-insensitive filesystem (the macOS APFS default) one directory has
# many spellings, so containment must compare file identity, not strings.
# These rows name the fixture with its letters' case swapped; they need such a
# filesystem, probed at runtime, and SKIP visibly elsewhere (on a
# case-sensitive one the swapped spelling names nothing and a row would pass
# for the wrong reason).
SW="$TMP/AB/PROJ"
if [ -d "$SW" ] && [ "$SW" -ef "$AB" ] && [ -d "$TMP/CT/CWD" ]; then ci=1; else ci=0; fi
ci_rows() {
  cat <<ROWS
case-swapped PWD, cwd tree, .git root|$AB|$SW|$AB/node_modules/.bin|drop|
case-swapped PWD, cwd tree, CLAUDE_PROJECT_DIR|$AB|$SW|$AB/node_modules/.bin|drop|CLAUDE_PROJECT_DIR=$AB
case-swapped PWD, .git ancestor root, sibling cwd|$AB/other|$SW/OTHER|$AB/sub|drop|
case-swapped PATH entry, cwd tree, .git root|$AB|$AB|$SW/node_modules/.bin|drop|
case-swapped PATH entry, cwd tree, CLAUDE_PROJECT_DIR|$AB|$AB|$SW/node_modules/.bin|drop|CLAUDE_PROJECT_DIR=$AB
case-swapped PATH entry, .git ancestor root, sibling cwd|$AB/other|$AB/other|$SW/SUB|drop|
case-swapped PATH entry, CLAUDE_PROJECT_DIR root, sibling cwd|$AB/other|$AB/other|$SW/SUB|drop|CLAUDE_PROJECT_DIR=$AB
case-swapped CLAUDE_PROJECT_DIR, sibling cwd|$AB/other|$AB/other|$AB/sub|drop|CLAUDE_PROJECT_DIR=$SW
case-swapped CURSOR_PROJECT_DIR, sibling cwd|$AB/other|$AB/other|$AB/sub|drop|CURSOR_PROJECT_DIR=$SW
case-swapped literal cwd prefix, symlinked out|$TMP/ct/cwd|$TMP/ct/cwd|$TMP/CT/CWD/out|drop|CLAUDE_PROJECT_DIR=$TMP/ct/cwd
control: case-swapped outside entry|$AB|$AB|$TMP/LEGIT/BIN|keep|CLAUDE_PROJECT_DIR=$AB
ROWS
}
all_rows() {
  rows
  if [ "$ci" = 1 ]; then ci_rows; fi
}

# want <expect> <tool...>: the markers that row expects, in markers' order.
want() {
  local e="$1" t s=""; shift
  case "$e" in
    drop) for t in "$@"; do s="$s out-$t"; done ;;
    keep) for t in "$@"; do s="$s ran-$t"; done ;;
  esac
  # markers() lists out-* before ran-*, each by tool name: sort the same way.
  printf '%s' "$s" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/^ *//; s/ *$//'
}
norm() { printf '%s' "$1" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/^ *//; s/ *$//'; }

# In a temp plugin root: the launcher with a probe, and plugin fixtures with
# no composer, so each plugin takes its own `bd memories` fallback.
PR="$TMP/plugin"
mkdir -p "$PR/hooks"
cp -f "$ROOT/hooks/run-hook.cmd" "$PR/hooks/run-hook.cmd"
printf '#!/bin/sh\necho probe-ran\n' >"$PR/hooks/probe-ok"
chmod +x "$PR/hooks/run-hook.cmd" "$PR/hooks/probe-ok"
mkdir -p "$TMP/hfx" "$TMP/ocfx/.opencode/plugins"
cp -f "$ROOT/.hermes-plugin/__init__.py" "$TMP/hfx/__init__.py"
cp -f "$ROOT/.opencode/plugins/beads-superpowers.js" "$TMP/ocfx/.opencode/plugins/beads-superpowers.js"
# shellcheck disable=SC2016 # python source, not shell
HERMES_PY='import importlib.util, sys
spec = importlib.util.spec_from_file_location("hermes_under_test", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(m._fallback_bootstrap())'
OC_JS='import { pathToFileURL } from "node:url";
const { BeadsSuperpowersPlugin } = await import(pathToFileURL(process.argv[1]).href);
const hooks = await BeadsSuperpowersPlugin({ client: {}, directory: process.cwd() });
const out = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] };
await hooks["experimental.chat.messages.transform"]({}, out);
console.log(out.messages[0].parts[0].text);'

# install.sh's hook_bash with the shim's rule it evals, as a host without
# /bin/bash runs it (NixOS, FreeBSD): /bin/bash, when there, is taken first.
{
  awk '/^IFS= read -r -d .. BSP_USABLE_SH <</,/^BSPEOF$/' "$ROOT/install.sh"
  awk '/^hook_bash\(\) \{$/,/^}$/' "$ROOT/install.sh" | sed 's#^  if \[ -x /bin/bash \]; then$#  if [ -x /nonexistent/bin/bash ]; then#'
} >"$TMP/hb.sh"
if grep -q -x '  if \[ -x /nonexistent/bin/bash \]; then' "$TMP/hb.sh"; then hb_ok=1; else hb_ok=0; report "extract hook_bash from install.sh" 1 "function body or its /bin/bash line not found"; fi

# install.sh's npx-tier fallback hook (no checkout: skill injection plus a
# bd memories line), written as write_hook_script writes it. It finds the
# skill under $HOME/.claude/skills.
{
  awk '/^IFS= read -r -d .. BSP_USABLE_SH <</,/^BSPEOF$/' "$ROOT/install.sh"
  awk '/^write_hook_script\(\) \{$/ { on = 1 }
       on { print }
       on && /^}$/ && prev ~ /chmod \+x "\$HOOK_SCRIPT"$/ { exit }
       { prev = $0 }' "$ROOT/install.sh"
} >"$TMP/whs.sh"
fb_ok=0
if [ "$(tail -n 1 "$TMP/whs.sh")" = "}" ]; then
  mkdir -p "$TMP/fbhooks"
  # shellcheck source=/dev/null
  if (. "$TMP/whs.sh" && HOOKS_DIR="$TMP/fbhooks" HOOK_SCRIPT="$TMP/fbhooks/fallback.sh" SKILLS_DIR="$TMP/skills" write_hook_script ""); then fb_ok=1; fi
fi
if [ "$fb_ok" = 0 ]; then report "write the npx fallback hook from install.sh" 1 "write_hook_script not found or failed"; fi
# Its PATH clean-up is hooks/session-start's, byte for byte.
pc_block() { awk '/^# Keep only absolute PATH entries/ { on = 1 } on { print } on && /^PATH="\$\{bsp_safe_path:-\/usr\/bin:\/bin\}"; export PATH$/ { exit }' "$1"; }
pc_ss=$(pc_block "$ROOT/hooks/session-start")
if [ "$fb_ok" = 1 ] && [ -n "$pc_ss" ] && [ "$(pc_block "$TMP/fbhooks/fallback.sh")" = "$pc_ss" ]; then report "npx fallback hook's PATH clean-up is session-start's" 0 ""; else report "npx fallback hook's PATH clean-up is session-start's" 1 "the blocks differ (or one is missing)"; fi
for hh in "$H" "$FH"; do
  mkdir -p "$hh/.claude/skills"
  ln -s "$ROOT/skills/using-superpowers" "$hh/.claude/skills/using-superpowers"
done

n=0
# row_run <cwd> <PWD> <entry> <extras> <command...>: sets rc, out, got.
row_run() {
  local dir="$1" pw="$2" e="$3" x="$4"; shift 4
  local -a extra=()
  if [ -n "$x" ]; then read -r -a extra <<<"$x"; fi
  n=$((n + 1)); mkdir -p "$TMP/rt$n"
  out=$(cd "$dir" && env -i HOME="$H" XDG_RUNTIME_DIR="$TMP/rt$n" PWD="$pw" PATH="$e:$OUT:/usr/bin:/bin" \
    ${extra[@]+"${extra[@]}"} "$@" </dev/null 2>/dev/null); rc=$?
  got=$(norm "$(markers)")
}
verdict() { # name | expected markers | injected(0/1)
  if [ "$rc" = 0 ] && [ "$got" = "$2" ] && [ "$3" = 0 ]; then report "$1" 0 ""; else report "$1" 1 "rc=$rc markers=[$got] want=[$2] out=$(printf '%s' "$out" | head -c 160)"; fi
}
has() { if [[ "$out" == *"$1"* ]]; then echo 0; else echo 1; fi; }

while IFS='|' read -r name dir pw e exp x; do
  # The launcher: the first PATH bash that passes its rule runs the probe.
  seen=" "
  for sh_bin in /bin/dash /bin/bash /opt/homebrew/bin/bash "$bash_bin"; do
    if [ ! -x "$sh_bin" ]; then continue; fi
    case "$seen" in *" $sh_bin "*) continue ;; esac
    seen="$seen$sh_bin "
    row_run "$dir" "$pw" "$e" "$x" "$sh_bin" "$PR/hooks/run-hook.cmd" probe-ok
    if [ "$exp" = all ]; then inj=0; if [ -n "$out" ]; then inj=1; fi; else inj=$(has probe-ran); fi
    verdict "launcher [$name] ($sh_bin)" "$(want "$exp" bash)" "$inj"
  done
  # hooks/session-start run directly: the entry's bd and sed never run, the
  # outside ones do, and the bootstrap is injected.
  seen=" "
  for b in /bin/bash /opt/homebrew/bin/bash "$bash_bin"; do
    if [ ! -x "$b" ]; then continue; fi
    case "$seen" in *" $b "*) continue ;; esac
    seen="$seen$b "
    row_run "$dir" "$pw" "$e" "$x" CLAUDE_PLUGIN_ROOT="$ROOT" "$b" "$ROOT/hooks/session-start"
    verdict "session-start [$name] ($b)" "$(want "$exp" bd sed)" "$(has 'Production-Grade Doctrine')"
  done
  # The harness shape: the registered launcher, run by sh -c. With every
  # entry dropped, no bash passes and the launcher exits silently.
  for sh_bin in /bin/sh /bin/dash; do
    if [ ! -x "$sh_bin" ]; then continue; fi
    # shellcheck disable=SC2016 # $0 is expanded by the inner shell
    row_run "$dir" "$pw" "$e" "$x" CLAUDE_PLUGIN_ROOT="$ROOT" "$sh_bin" -c '"$0" session-start' "$ROOT/hooks/run-hook.cmd"
    if [ "$exp" = all ]; then inj=0; if [ -n "$out" ]; then inj=1; fi; else inj=$(has 'Production-Grade Doctrine'); fi
    verdict "session-start via launcher, $sh_bin -c [$name]" "$(want "$exp" bash bd sed)" "$inj"
  done
  # Each plugin's own bd fallback, with the PATH it builds.
  if [ -n "$py_bin" ]; then
    row_run "$dir" "$pw" "$e" "$x" "$py_bin" -I -c "$HERMES_PY" "$TMP/hfx/__init__.py"
    verdict "Hermes bd fallback [$name]" "$(want "$exp" bd)" "$(has 'session composer unavailable')"
  fi
  if [ -n "$node_bin" ]; then
    row_run "$dir" "$pw" "$e" "$x" "$node_bin" --input-type=module -e "$OC_JS" "$TMP/ocfx/.opencode/plugins/beads-superpowers.js"
    verdict "OpenCode bd fallback [$name]" "$(want "$exp" bd)" "$(has 'session composer unavailable')"
  fi
  # The npx fallback hook: the entry's bd never runs when dropped.
  if [ "$fb_ok" = 1 ]; then
    row_run "$dir" "$pw" "$e" "$x" "$bash_bin" "$TMP/fbhooks/fallback.sh"
    verdict "install.sh npx fallback hook [$name]" "$(want "$exp" bd)" "$(has 'Production-Grade Doctrine')"
  fi
  # hook_bash prints the bash it would register: the outside bin's when the
  # entry is dropped, the entry's when kept, and none (rc 1) when every
  # candidate, $BASH included, is refused.
  if [ "$hb_ok" = 1 ]; then
    # shellcheck disable=SC2016 # $1 is expanded by the inner bash
    row_run "$dir" "$pw" "$e" "$x" "$bash_bin" -c '. "$1" && hook_bash' _ "$TMP/hb.sh"
    case "$exp" in
      drop) hb_want="$OUT/bash"; hb_rc=0 ;;
      keep) hb_want="${e/#\~/$FH}/bash"; hb_rc=0 ;;
      all) hb_want=""; hb_rc=1 ;;
    esac
    if [ "$rc" = "$hb_rc" ] && [ "$out" = "$hb_want" ] && [ -z "$got" ]; then report "install.sh hook_bash [$name]" 0 ""; else report "install.sh hook_bash [$name]" 1 "rc=$rc out=[$out] want=[$hb_want] rc want $hb_rc markers=[$got]"; fi
  fi
done < <(all_rows)
if [ "$ci" = 0 ]; then echo "SKIP: case-swapped rows (the filesystem at $TMP is case-sensitive: $SW names nothing)"; fi
# hook_bash with no PATH bash passing: $BASH when it passes, else none (rc 1,
# and setup_hooks registers no hook).
if [ "$hb_ok" = 1 ]; then
  # shellcheck disable=SC2016 # $1 is expanded by the inner bash
  out=$(cd "$AB" && env -i HOME="$H" PWD="$AB" PATH="$AB/sub" "$bash_bin" -c '. "$1" && hook_bash' _ "$TMP/hb.sh" 2>/dev/null); rc=$?
  if [ "$rc" = 0 ] && [ "$out" = "$bash_bin" ]; then report "install.sh hook_bash: only an in-project bash on PATH, outside \$BASH used" 0 ""; else report "install.sh hook_bash: only an in-project bash on PATH, outside \$BASH used" 1 "rc=$rc out=[$out]"; fi
  # shellcheck disable=SC2016 # $1/$2 are expanded by the inner bash
  out=$(cd "$AB" && env -i HOME="$H" PWD="$AB" PATH="$AB/sub" "$bash_bin" -c 'BASH=$2; . "$1" && hook_bash' _ "$TMP/hb.sh" "$AB/sub/bash" 2>/dev/null); rc=$?
  if [ "$rc" = 1 ] && [ -z "$out" ]; then report "install.sh hook_bash: in-project PATH bash and \$BASH both refused (rc 1)" 0 ""; else report "install.sh hook_bash: in-project PATH bash and \$BASH both refused (rc 1)" 1 "rc=$rc out=[$out]"; fi
fi
if [ -z "$py_bin" ]; then echo "SKIP: Hermes rows (python3 not found)"; fi
if [ -z "$node_bin" ]; then echo "SKIP: OpenCode rows (node not found)"; fi

exit "$fail"
