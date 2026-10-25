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
  want='exec "${BASH:-bash}" "$BSP_ROOT/hooks/session-start" "$@"'
  last=$(tail -n 1 "$T/hookhome/shim.sh")
  if [ "$last" = "$want" ]; then report "shim execs \${BASH:-bash}" 0 ""; else report "shim execs \${BASH:-bash}" 1 "last line: $last"; fi

  fresh; run "$T/evil" "" "$bash_bin" "$T/hookhome/shim.sh"
  planted_check "planted binaries: install.sh shim with PATH=''"

  fresh
  mkdir -p "$h/.claude/skills"
  ln -s "$ROOT/skills/using-superpowers" "$h/.claude/skills/using-superpowers"
  run "$T/evil" "" "$bash_bin" "$T/hookhome/fallback.sh"
  planted_check "planted binaries: npx fallback with PATH=''"
else
  report "extract write_hook_script from install.sh" 1 "function body not found"
fi

exit $fail
