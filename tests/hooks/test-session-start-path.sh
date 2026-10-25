#!/usr/bin/env bash
# Asserts hooks/session-start survives an empty or hostile PATH
# (anthropics/claude-code#43127) without ever running a binary planted in the
# working directory. An empty PATH, or an empty/relative entry, makes bash look
# commands up in the cwd, which for a hook is an untrusted project. Also covers
# install.sh's generated shim and npx fallback, and pins that a normal PATH
# emits the same bytes as the pre-change hook.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
bash_bin="$(command -v bash)"
n=0
GOLDEN_BASE=0c5127c

report() { # name | ok(0/1) | detail
  if [ "$2" = 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; echo "  $3"; fail=1; fi
}

# fresh: a new HOME, runtime dir and output files, so dedup markers never collide.
fresh() {
  n=$((n + 1)); h="$T/home$n"; rt="$T/rt$n"; out="$T/out$n"; err="$T/err$n"
  mkdir -p "$h" "$rt"
}

# run <cwd> <PATH value> <command...>: sets rc; stdout/stderr land in $out/$err.
run() {
  local dir="$1" p="$2"; shift 2
  (cd "$dir" && env -i HOME="$h" XDG_RUNTIME_DIR="$rt" CLAUDE_PLUGIN_ROOT="$ROOT" PATH="$p" "$@" </dev/null >"$out" 2>"$err")
  rc=$?
}

# The nested envelope carrying the bootstrap. Parsed outside the hook's env
# (jq is not on an empty PATH).
valid_envelope() {
  python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert "Production-Grade Doctrine" in d["hookSpecificOutput"]["additionalContext"]' <"$1" 2>/dev/null
}

detail() { printf 'rc=%s out=%s err=%s' "$rc" "$(head -c 200 "$out")" "$(head -c 300 "$err")"; }

check() { # name [extra-condition-result(0/1)]
  if [ "$rc" = 0 ] && valid_envelope "$out" && [ "${2:-0}" = 0 ]; then report "$1" 0 ""; else report "$1" 1 "$(detail)"; fi
}

# --- empty PATH ---
fresh; run "$T" "" "$bash_bin" "$ROOT/hooks/session-start"
check "empty PATH direct"
if [ -x /bin/bash ] && [ "/bin/bash" != "$bash_bin" ]; then
  fresh; run "$T" "" /bin/bash "$ROOT/hooks/session-start"
  check "empty PATH direct (/bin/bash $(/bin/bash -c 'echo "$BASH_VERSION"'))"
fi
fresh; run "$T" "" "$bash_bin" "$ROOT/hooks/run-hook.cmd" session-start
check "empty PATH via launcher"

# --- $0 shapes ---
fresh
# shellcheck disable=SC2016 # $1/$2 are expanded by the inner bash, not this shell
run "$T" "/usr/bin:/bin" "$bash_bin" -c 'cd "$1" && exec "$2" session-start' _ "$ROOT/hooks" "$bash_bin"
check "bare name"
fresh
# shellcheck disable=SC2016 # $1/$2 are expanded by the inner bash, not this shell
run "$T" "" "$bash_bin" -c 'cd "$1" && exec "$2" session-start' _ "$ROOT/hooks" "$bash_bin"
check "bare name, empty PATH"

mkdir -p "$T/bs"
ln -s "$ROOT/hooks" "$T/bs/hooks"
ln -s "$ROOT/skills" "$T/bs/skills"
ln -s "$ROOT/hooks/session-start" "$T/bs/hooks\\session-start"
fresh; run "$T/bs" "/usr/bin:/bin" "$bash_bin" 'hooks\session-start'
unreadable=0; if grep -qF 'skill unreadable' "$out"; then unreadable=1; fi
check "backslash \$0" "$unreadable"
fresh; run "$T/bs" "" "$bash_bin" 'hooks\session-start'
unreadable=0; if grep -qF 'skill unreadable' "$out"; then unreadable=1; fi
check "backslash \$0, empty PATH" "$unreadable"

# --- partial PATH: cat resolves, sed/mkdir do not (Review Focus 1) ---
mkdir -p "$T/catbin"
printf '#!%s\n: > "%s/cat-used"\nexec /bin/cat "$@"\n' "$bash_bin" "$T" >"$T/catbin/cat"
chmod +x "$T/catbin/cat"
fresh; run "$T" "$T/catbin" "$bash_bin" "$ROOT/hooks/session-start"
cat_used=1; if [ -e "$T/cat-used" ]; then cat_used=0; fi
check "cat stub (emit_json goes through cat)" "$cat_used"

# --- planted binaries in the cwd (security) ---
mkdir -p "$T/evil"
for b in cat sed dirname id bd bash; do
  if [ "$b" = cat ]; then
    printf '#!/bin/sh\n: > "%s/ran-%s"\nexec /bin/cat "$@"\n' "$T" "$b" >"$T/evil/$b"
  else
    printf '#!/bin/sh\n: > "%s/ran-%s"\n' "$T" "$b" >"$T/evil/$b"
  fi
  chmod +x "$T/evil/$b"
done
no_planted() { # 0 when no planted binary ran; lists offenders otherwise
  local m ran=""
  for m in "$T"/ran-*; do [ -e "$m" ] && ran="$ran ${m##*/ran-}"; done
  rm -f "$T"/ran-*
  if [ -n "$ran" ]; then echo "  planted ran:$ran"; return 1; fi
  return 0
}
planted_check() { # name
  local planted prc
  planted=$(no_planted); prc=$?
  if [ "$prc" != 0 ]; then echo "$planted"; fi
  check "$1" "$prc"
}
for p in "" "/nonexistent:" ".:/usr/bin"; do
  fresh; run "$T/evil" "$p" "$bash_bin" "$ROOT/hooks/session-start"
  planted_check "planted binaries: hook with PATH='$p'"
done
fresh; run "$T/evil" "" "$bash_bin" "$ROOT/hooks/run-hook.cmd" session-start
planted_check "planted binaries: launcher with PATH=''"

# --- a literal ~ entry is kept (bash expands it at lookup) ---
fresh
mkdir -p "$h/bin" "$T/plain"
# shellcheck disable=SC2016 # $1 belongs to the stub, expanded when it runs
printf '#!/bin/sh\n: > "%s/tilde-bd-ran"\nif [ "$1" = memories ]; then echo "{}"; fi\nexit 0\n' "$T" >"$h/bin/bd"
chmod +x "$h/bin/bd"
# shellcheck disable=SC2088 # the literal ~ is the point of this check
run "$T/plain" '~/bin:/usr/bin:/bin' "$bash_bin" "$ROOT/hooks/session-start"
tilde=1; if [ -e "$T/tilde-bd-ran" ]; then tilde=0; fi
check "tilde entry kept (~/bin/bd runs)" "$tilde"

# --- golden: a normal PATH emits the same bytes as the pre-change hook ---
# Base: GOLDEN_BASE (0c5127c), the last commit before sub-project A. Rule: when a
# later change INTENDS to change the hook's normal-PATH output, move GOLDEN_BASE
# to the commit just before that change, in the same commit. One cmp per output
# dialect. A checkout without that commit (shallow clone, tarball) SKIPs.
mkdir -p "$T/old/hooks" "$T/gcwd" "$T/ghome" "$T/ghome-sm/.claude"
ln -s "$ROOT/skills" "$T/old/skills"
printf '{"session_id":"golden","source":"startup"}' >"$T/golden-in"
printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bd prime --hook-json"}]}]}}\n' \
  >"$T/ghome-sm/.claude/settings.json"
# golden_run <old|new> <dialect>: writes $T/golden-<dialect>-<which> and its .rc
golden_run() {
  local which="$1" dialect="$2" groot ghome="$T/ghome"
  local -a denv
  if [ "$which" = old ]; then groot="$T/old"; else groot="$ROOT"; fi
  case "$dialect" in
    claude) denv=(CLAUDE_PLUGIN_ROOT="$groot") ;;
    cursor) denv=(CURSOR_PLUGIN_ROOT="$groot") ;;
    copilot) denv=(COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$groot") ;;
    claude-systemMessage) denv=(CLAUDE_PLUGIN_ROOT="$groot"); ghome="$T/ghome-sm" ;;
  esac
  mkdir -p "$T/grt-$dialect-$which"
  (cd "$T/gcwd" && env -i HOME="$ghome" PATH=/usr/bin:/bin XDG_RUNTIME_DIR="$T/grt-$dialect-$which" "${denv[@]}" \
    "$bash_bin" "$groot/hooks/session-start" <"$T/golden-in" >"$T/golden-$dialect-$which" 2>/dev/null)
  echo "$?" >"$T/golden-$dialect-$which.rc"
}
if git -C "$ROOT" show "$GOLDEN_BASE:hooks/session-start" >"$T/old/hooks/session-start" 2>"$T/golden-git-err"; then
  for dialect in claude cursor copilot claude-systemMessage; do
    golden_run old "$dialect"; golden_run new "$dialect"
    g="$T/golden-$dialect"
    exercised=0
    if [ "$dialect" = claude-systemMessage ] && ! grep -q '"systemMessage"' "$g-new"; then exercised=1; fi
    if [ "$(cat "$g-old.rc")" = 0 ] && [ "$(cat "$g-new.rc")" = 0 ] && [ "$exercised" = 0 ] \
       && [ -s "$g-new" ] && cmp -s "$g-old" "$g-new"; then
      report "golden $dialect (normal PATH unchanged since $GOLDEN_BASE)" 0 ""
    else
      report "golden $dialect (normal PATH unchanged since $GOLDEN_BASE)" 1 "rc old=$(cat "$g-old.rc") new=$(cat "$g-new.rc") systemMessage-missing=$exercised; $(cmp "$g-old" "$g-new" 2>&1)"
    fi
  done
else
  echo "SKIP: golden (git show $GOLDEN_BASE failed, e.g. a shallow or tarball checkout: $(head -c 200 "$T/golden-git-err"))"
fi

# --- install.sh's generated shim and npx fallback ---
# The function body ends at the first column-0 `}` after its final chmod line
# (the fallback heredoc has column-0 `}` lines of its own).
awk '/^write_hook_script\(\) \{$/ { on = 1 }
     on { print }
     on && /^}$/ && prev ~ /chmod \+x "\$HOOK_SCRIPT"$/ { exit }
     { prev = $0 }' "$ROOT/install.sh" >"$T/whs.sh"
if [ "$(tail -n 1 "$T/whs.sh")" = "}" ] && grep -q 'HOOKEOF' "$T/whs.sh"; then
  # shellcheck source=/dev/null
  . "$T/whs.sh"
  HOOKS_DIR="$T/hookhome" HOOK_SCRIPT="$T/hookhome/shim.sh" SKILLS_DIR="$ROOT/skills" write_hook_script "$ROOT"
  HOOKS_DIR="$T/hookhome" HOOK_SCRIPT="$T/hookhome/fallback.sh" SKILLS_DIR="$ROOT/skills" write_hook_script ""
  # shellcheck disable=SC2016 # the shim's exec line is matched literally
  want='exec "$bsp_bash" "$BSP_ROOT/hooks/session-start" "$@"'
  last=$(tail -n 1 "$T/hookhome/shim.sh")
  if [ "$last" = "$want" ]; then report "shim execs the vetted bash" 0 ""; else report "shim execs the vetted bash" 1 "last line: $last"; fi

  fresh; run "$T/evil" "" "$bash_bin" "$T/hookhome/shim.sh"
  planted_check "planted binaries: install.sh shim with PATH=''"

  # The shim picks bash with hooks/run-hook.cmd's rule: the bash on the
  # cleaned PATH, else $BASH only when absolute, outside the cwd tree and the
  # project root, and not the shim; else exit 0 silently.
  # silent_check <name>: refused — rc 0, no output, no planted binary ran.
  silent_check() {
    local planted prc
    planted=$(no_planted); prc=$?
    if [ "$rc" = 0 ] && [ ! -s "$out" ] && [ "$prc" = 0 ]; then report "$1" 0 ""; else report "$1" 1 "$planted $(detail)"; fi
  }
  # bash started with argv0 "bash" fills $BASH by a PATH search, which can
  # land in the cwd (finding d).
  fresh
  # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
  run "$T/evil" "" "$bash_bin" -c 'exec -a bash "$0" "$@"' "$bash_bin" "$T/hookhome/shim.sh"
  planted_check "shim: argv0 bash, PATH='' (cleaned-PATH bash used, not the cwd one)"
  fresh
  # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
  run "$T/evil" "/nonexistent:" "$bash_bin" -c 'exec -a bash "$0" "$@"' "$bash_bin" "$T/hookhome/shim.sh"
  silent_check "shim: argv0 bash, PATH='/nonexistent:' (\$BASH in cwd refused)"
  fresh; run "$T/evil" "/nonexistent" "$bash_bin" "$T/hookhome/shim.sh"
  planted_check "shim: bash-less PATH falls back to an absolute \$BASH"
  # Project root: $BASH = <root>/bash from a subdirectory cwd, as an absolute
  # argv0, so no . or .. component or cwd prefix refuses it first.
  mkdir -p "$T/proj/sub"
  printf '#!/bin/sh\n: > "%s/ran-rootbash"\n' "$T" >"$T/proj/bash"
  chmod +x "$T/proj/bash"
  for pv in CLAUDE_PROJECT_DIR CURSOR_PROJECT_DIR; do
    fresh
    # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
    run "$T/proj/sub" /nonexistent /usr/bin/env "$pv=$T/proj" "$bash_bin" -c 'exec -a "$0" "$@"' "$T/proj/bash" "$bash_bin" "$T/hookhome/shim.sh"
    silent_check "shim: \$BASH inside $pv from a subdirectory cwd (refused)"
  done
  # cwd / contains every $BASH; bash 5.3 does not match "${v%/}"/* when the
  # expansion is empty.
  seen=" "
  for sh_bin in /opt/homebrew/bin/bash /usr/local/bin/bash /bin/bash /bin/dash "$bash_bin"; do
    if [ ! -x "$sh_bin" ]; then continue; fi
    case "$seen" in *" $sh_bin "*) continue ;; esac
    seen="$seen$sh_bin "
    fresh; run / /nonexistent /usr/bin/env BASH="$bash_bin" "$sh_bin" "$T/hookhome/shim.sh"
    silent_check "shim: cwd / refuses \$BASH ($sh_bin)"
    # With a project root elsewhere, only the cwd half of the pattern holds.
    fresh; run / /nonexistent /usr/bin/env BASH="$bash_bin" CLAUDE_PROJECT_DIR="$T/proj" "$sh_bin" "$T/hookhome/shim.sh"
    silent_check "shim: cwd /, CLAUDE_PROJECT_DIR elsewhere, refuses \$BASH ($sh_bin)"
  done
  # Containment shapes under dash, bash 3.2 and bash 5.3, with no bash on
  # the cleaned PATH. The planted $BASH is spelled absolutely, with no . or ..
  # component and no cwd prefix, so the root, // and .git logic refuses it
  # (an absolute PATH entry cannot deliver it: `command -v` would pick that
  # bash directly). Under bash it is the absolute argv0; under dash it is set.
  # shim_cont <shell> <cwd> <$BASH> [VAR=value...]
  shim_cont() {
    local sh_bin="$1" dir="$2" bv="$3"; shift 3
    fresh
    # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
    case "$sh_bin" in
      */dash) run "$dir" /nonexistent /usr/bin/env BASH="$bv" "$@" "$sh_bin" "$T/hookhome/shim.sh" ;;
      *) run "$dir" /nonexistent /usr/bin/env "$@" "$bash_bin" -c 'exec -a "$0" "$@"' "$bv" "$sh_bin" "$T/hookhome/shim.sh" ;;
    esac
  }
  for t in cp gp gf gn; do
    mkdir -p "$T/$t/proj/sub"
    printf '#!/bin/sh\n: > "%s/ran-contbash"\n' "$T" >"$T/$t/proj/bash"
    chmod +x "$T/$t/proj/bash"
  done
  mkdir -p "$T/gp/proj/.git"
  printf 'gitdir: /elsewhere\n' >"$T/gf/proj/.git"
  # gn: a nested .git the project can plant must not shrink the root.
  mkdir -p "$T/gn/proj/.git"
  printf 'gitdir: /elsewhere\n' >"$T/gn/proj/sub/.git"
  C="$T/cp/proj"
  seen=" "
  for sh_bin in /bin/dash /bin/bash /opt/homebrew/bin/bash "$bash_bin"; do
    if [ ! -x "$sh_bin" ]; then continue; fi
    case "$seen" in *" $sh_bin "*) continue ;; esac
    seen="$seen$sh_bin "
    # A leading // survives cd -P and pwd -P in bash (dash collapses it).
    shim_cont "$sh_bin" "$C/sub" "$C/bash" CLAUDE_PROJECT_DIR=/
    silent_check "shim: CLAUDE_PROJECT_DIR=/ contains \$BASH ($sh_bin)"
    shim_cont "$sh_bin" "$C/sub" "$C/bash" CLAUDE_PROJECT_DIR="/$C"
    silent_check "shim: CLAUDE_PROJECT_DIR=//<proj> contains \$BASH ($sh_bin)"
    shim_cont "$sh_bin" "$C/sub" "/$C/bash" PWD="/$C/sub" CLAUDE_PROJECT_DIR="$C"
    silent_check "shim: inherited PWD=//<proj>/sub, \$BASH=//<proj>/bash ($sh_bin)"
    # Control: an outside bash still runs under a //-spelled root.
    fresh; run "$C/sub" /nonexistent /usr/bin/env BASH="$bash_bin" CLAUDE_PROJECT_DIR="/$C" "$sh_bin" "$T/hookhome/shim.sh"
    planted_check "shim: outside \$BASH runs under CLAUDE_PROJECT_DIR=//<proj> ($sh_bin)"
    # A relative root variable fails closed, even for an outside bash.
    for pv in CLAUDE_PROJECT_DIR CURSOR_PROJECT_DIR; do
      shim_cont "$sh_bin" "$C/sub" "$C/bash" "$pv=proj"
      silent_check "shim: relative $pv refuses \$BASH ($sh_bin)"
      fresh; run "$C/sub" /nonexistent /usr/bin/env BASH="$bash_bin" "$pv=proj" "$sh_bin" "$T/hookhome/shim.sh"
      silent_check "shim: relative $pv refuses an outside \$BASH ($sh_bin)"
    done
    # No root variable: the nearest ancestor holding .git is a root too.
    for t in gp gf gn; do
      shim_cont "$sh_bin" "$T/$t/proj/sub" "$T/$t/proj/bash"
      silent_check "shim: no root variable, \$BASH inside the .git ancestor ($t) ($sh_bin)"
    done
    fresh; run "$T/gp/proj/sub" /nonexistent /usr/bin/env BASH="$bash_bin" "$sh_bin" "$T/hookhome/shim.sh"
    planted_check "shim: outside \$BASH runs below a .git ancestor ($sh_bin)"
  done
  # R1: no root variable and no .git, so the root is just the cwd, and a
  # relative entry reaches a bash above or beside it: through ".."
  # (<cwd>/../bash, <cwd>/../other/bash) or through a symlink the project
  # ships (nm -> ../evilnm, entry nm/.bin). bash builds $BASH as
  # $PWD/<entry>/bash, so a . or .. component, or a literal logical or
  # physical cwd prefix, is refused.
  mkdir -p "$T/ng/proj/sub" "$T/ng/proj/other" "$T/ng/proj/evilnm/.bin" "$T/rbin"
  ln -s ../evilnm "$T/ng/proj/sub/nm"
  ln -s ng/proj "$T/ngl"
  for b in "$T/ng/proj/bash" "$T/ng/proj/other/bash" "$T/ng/proj/evilnm/.bin/bash"; do
    printf '#!/bin/sh\n: > "%s/ran-relbash"\n' "$T" >"$b"
    chmod +x "$b"
  done
  ln -s "$bash_bin" "$T/rbin/bash"
  NG="$T/ng/proj/sub"
  NGL="$T/ngl/sub"
  NGP=$(cd -P "$NG" && pwd -P)
  seen=" "
  for sh_bin in /bin/dash /bin/bash /opt/homebrew/bin/bash "$bash_bin"; do
    if [ ! -x "$sh_bin" ]; then continue; fi
    case "$seen" in *" $sh_bin "*) continue ;; esac
    seen="$seen$sh_bin "
    for e in .. ../other nm/.bin; do
      fresh
      # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
      case "$sh_bin" in
        */dash) run "$NG" /nonexistent /usr/bin/env PWD="$NG" BASH="$NG/$e/bash" "$sh_bin" "$T/hookhome/shim.sh" ;;
        *) run "$NG" "/nonexistent:$e" "$bash_bin" -c 'exec -a bash "$0" "$@"' "$sh_bin" "$T/hookhome/shim.sh" ;;
      esac
      silent_check "shim: no root, no .git, PATH entry '$e' reaches a planted bash ($sh_bin)"
    done
    # The same symlinked entry from a symlinked (logical) cwd, $PWD inherited.
    fresh
    # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
    case "$sh_bin" in
      */dash) run "$NGL" /nonexistent /usr/bin/env PWD="$NGL" BASH="$NGL/nm/.bin/bash" "$sh_bin" "$T/hookhome/shim.sh" ;;
      *) run "$NGL" /nonexistent:nm/.bin /usr/bin/env PWD="$NGL" "$bash_bin" -c 'exec -a bash "$0" "$@"' "$sh_bin" "$T/hookhome/shim.sh" ;;
    esac
    silent_check "shim: no root, no .git, entry nm/.bin from a symlinked cwd ($sh_bin)"
    # Controls: a bash outside the project still runs, as $BASH and through
    # an absolute PATH entry.
    fresh; run "$NG" /nonexistent /usr/bin/env BASH="$bash_bin" "$sh_bin" "$T/hookhome/shim.sh"
    planted_check "shim: no root, no .git: outside \$BASH runs ($sh_bin)"
    fresh; run "$NG" "/nonexistent:$T/rbin" "$sh_bin" "$T/hookhome/shim.sh"
    planted_check "shim: no root, no .git: bash on an absolute PATH entry runs ($sh_bin)"
  done
  if [ -x /bin/dash ]; then
    for bv in "$T/ng/proj/./bash" "$T/ng/proj/other/." "$T/ng/proj/other/.."; do
      fresh; run "$NG" /nonexistent /usr/bin/env PWD="$NG" BASH="$bv" /bin/dash "$T/hookhome/shim.sh"
      silent_check "shim: \$BASH with a . or .. component (${bv#"$T"/}) (dash)"
    done
    # Each prefix on its own ($PWD is the symlinked spelling; $BASH starts
    # with it, or with the physical cwd), then a leading // on either side.
    # shim_spell <name> <PWD> <$BASH>
    shim_spell() {
      fresh; run "$NG" /nonexistent /usr/bin/env PWD="$2" BASH="$3" /bin/dash "$T/hookhome/shim.sh"
      silent_check "shim: $1 (dash)"
    }
    shim_spell "\$BASH starts with the logical cwd" "$NGL" "$NGL/nm/.bin/bash"
    shim_spell "\$BASH starts with the physical cwd" "$NGL" "$NGP/nm/.bin/bash"
    shim_spell "\$BASH starts with the logical cwd, PWD=//..." "/$NGL" "$NGL/nm/.bin/bash"
    shim_spell "\$BASH=//<logical cwd>/..." "$NGL" "/$NGL/nm/.bin/bash"
  else
    echo "SKIP: shim \$BASH . and .. components under /bin/dash (/bin/dash not found)"
  fi
  # $BASH naming the shim itself is refused (no self re-exec).
  if [ -x /bin/dash ]; then
    fresh; run "$T/plain" /nonexistent /usr/bin/env BASH="$T/hookhome/shim.sh" /bin/dash "$T/hookhome/shim.sh"
    silent_check "shim: \$BASH = the shim is refused"
  fi
  # The generated shim is clean POSIX sh and bash.
  if command -v shellcheck >/dev/null 2>&1; then
    for d in sh bash; do
      if sc_out=$(shellcheck -s "$d" "$T/hookhome/shim.sh" 2>&1); then report "generated shim passes shellcheck -s $d" 0 ""; else report "generated shim passes shellcheck -s $d" 1 "$sc_out"; fi
    done
  else
    echo "SKIP: generated shim shellcheck (shellcheck not found)"
  fi

  fresh
  mkdir -p "$h/.claude/skills"
  ln -s "$ROOT/skills/using-superpowers" "$h/.claude/skills/using-superpowers"
  run "$T/evil" "" "$bash_bin" "$T/hookhome/fallback.sh"
  planted_check "planted binaries: npx fallback with PATH=''"
else
  report "extract write_hook_script from install.sh" 1 "function body not found"
fi

# --- install.sh: the bash the hook is registered and run with ---
awk '/^hook_bash\(\) \{$/,/^}$/' "$ROOT/install.sh" >"$T/hb.sh"
awk '/^register_hook\(\) \{$/,/^}$/' "$ROOT/install.sh" >"$T/rh.sh"
if grep -q '^hook_bash() {$' "$T/hb.sh" && grep -q 'PYEOF' "$T/rh.sh" && [ "$(tail -n 1 "$T/rh.sh")" = "}" ]; then
  # shellcheck source=/dev/null
  . "$T/hb.sh"
  # shellcheck source=/dev/null
  . "$T/rh.sh"
  # /bin/bash is preferred: an earlier bash on the install-time PATH can be
  # ephemeral (nix-shell, devbox, mise shims).
  if [ -x /bin/bash ]; then
    mkdir -p "$T/ephem"
    ln -s "$bash_bin" "$T/ephem/bash"
    got=$(PATH="$T/ephem:/usr/bin:/bin" hook_bash)
    if [ "$got" = /bin/bash ]; then report "hook_bash prefers /bin/bash over an earlier PATH bash" 0 ""; else report "hook_bash prefers /bin/bash over an earlier PATH bash" 1 "got: $got"; fi
  else
    echo "SKIP: hook_bash /bin/bash preference (/bin/bash not found)"
  fi
  # reg_case <name> <settings JSON> <python check on d, cmd, hs>: runs
  # register_hook on that settings file with a shim under a HOME that has a
  # space and a ', and requires rc 0 and the check.
  reg_n=0
  reg_case() {
    reg_n=$((reg_n + 1))
    local sf="$T/reg$reg_n.json" hs="$T/ho me'$reg_n/.claude/hooks/beads-superpowers-session-start.sh" rrc
    python3 -I -c 'import sys; open(sys.argv[1], "w").write(sys.argv[2].replace("@HS@", sys.argv[3]))' "$sf" "$2" "$hs"
    SETTINGS_FILE="$sf" HOOK_SCRIPT="$hs" HOOK_BASH=/bin/bash register_hook >"$T/reg$reg_n.out" 2>&1
    rrc=$?
    if [ "$rrc" = 0 ] && python3 -I -c 'import json, shlex, sys
sf, hs, check = sys.argv[1:4]
d = json.load(open(sf))
cmd = shlex.quote("/bin/bash") + " " + shlex.quote(hs)
sys.exit(0 if eval(check) else 1)' "$sf" "$hs" "$3" 2>>"$T/reg$reg_n.out"; then
      report "register_hook: $1" 0 ""
    else
      report "register_hook: $1" 1 "rc=$rrc out=$(head -c 300 "$T/reg$reg_n.out") settings=$(head -c 400 "$sf")"
    fi
  }
  # Ours: every beads-superpowers command. A pre-fix `bash <shim>` that
  # shlex cannot split (a space, a ') is still rewritten.
  ours='[h["command"] for e in d["hooks"]["SessionStart"] if isinstance(e, dict) for h in e.get("hooks") or [] if isinstance(h, dict) and "beads-superpowers" in str(h.get("command"))]'
  foreign='{"hooks": [{"type": "command", "command": "bash /somewhere/else.sh"}]}'
  # The JSON is built by python so the shim path is escaped correctly.
  reg_case "pre-fix 'bash <shim>' under a HOME with a space and a ' is rewritten" \
    '{"hooks": {"SessionStart": [{"matcher": "startup|clear|compact", "hooks": [{"type": "command", "command": "bash @HS@"}]}, '"$foreign"']}}' \
    "$ours == [cmd] and any(h.get(\"command\") == \"bash /somewhere/else.sh\" for e in d[\"hooks\"][\"SessionStart\"] for h in e.get(\"hooks\") or [])"
  # Hand-edited settings never crash the install: malformed entries are
  # skipped and kept, a null container counts as empty, and a container of
  # the wrong type is left untouched.
  reg_case 'malformed SessionStart entries are skipped and kept' \
    '{"hooks": {"SessionStart": [{"hooks": null}, "junk", {"hooks": [null, "x", {"command": null}, {"command": 5}]}]}}' \
    "$ours == [cmd] and len(d[\"hooks\"][\"SessionStart\"]) == 4"
  reg_case '"hooks": null counts as empty' '{"hooks": null}' "$ours == [cmd]"
  reg_case '"SessionStart": null counts as empty' '{"hooks": {"SessionStart": null}}' "$ours == [cmd]"
  reg_case '"hooks" of the wrong type is left untouched' '{"hooks": []}' 'd == {"hooks": []}'
  reg_case '"SessionStart" of the wrong type is left untouched' '{"hooks": {"SessionStart": {"x": 1}}}' 'd == {"hooks": {"SessionStart": {"x": 1}}}'
  reg_case 'a non-object top level is left untouched' '[]' 'd == []'
else
  report "extract hook_bash and register_hook from install.sh" 1 "function body not found"
fi
# install.sh runs the hook (and itself) with the vetted bash, never a bare one.
bare=$(grep -nE '(^|[[:space:];&|(])bash "\$' "$ROOT/install.sh" | grep -vE '^[0-9]+:[[:space:]]*#')
if [ -z "$bare" ]; then report "install.sh runs no bare 'bash \"\$...\"'" 0 ""; else report "install.sh runs no bare 'bash \"\$...\"'" 1 "$bare"; fi

exit $fail
