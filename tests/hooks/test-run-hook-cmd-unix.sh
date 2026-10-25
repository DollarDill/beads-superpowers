#!/usr/bin/env bash
# Asserts hooks/run-hook.cmd (the polyglot launcher) dispatches on Unix with an
# empty PATH, propagates exit codes, never execs a bash planted in the working
# directory, never re-execs itself, and that its Windows cmd half (through the
# first CMDBLOCK line) still matches the pinned upstream v7.0.1 bytes. The Unix
# half after that line is ours.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PINNED_CMD_HALF=d658e97f7ca991e08af5dc4687977a0d397aaa348fea3622eac6f7dac72cc8ce
fail=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
bash_bin="$(command -v bash)"

root="$TMP/plugin"
mkdir -p "$root/hooks"
cp -f "$ROOT/hooks/run-hook.cmd" "$root/hooks/run-hook.cmd"
printf '#!/bin/sh\necho probe-ran\n' > "$root/hooks/probe-ok"
printf '#!/bin/sh\necho probe-ran\nexit 7\n' > "$root/hooks/probe-exit"
chmod +x "$root/hooks/run-hook.cmd" "$root/hooks/probe-ok" "$root/hooks/probe-exit"

report() { # desc | ok(0/1) | detail
  if [ "$2" = 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; echo "  $3"; fail=1; fi
}

# The cmd half is every byte up to and including the first line that is
# exactly CMDBLOCK.
cmd_half_sha='
import hashlib, sys
half = b""
for line in open(sys.argv[1], "rb").read().splitlines(keepends=True):
    half += line
    if line.rstrip(b"\r\n") == b"CMDBLOCK":
        break
else:
    sys.exit("no CMDBLOCK line")
print(hashlib.sha256(half).hexdigest())
'
if command -v python3 >/dev/null 2>&1; then
  actual=$(python3 -I -c "$cmd_half_sha" "$ROOT/hooks/run-hook.cmd" 2>&1)
  if [ "$actual" = "$PINNED_CMD_HALF" ]; then report "cmd-half sha256 pin (upstream v7.0.1)" 0 ""; else report "cmd-half sha256 pin (upstream v7.0.1)" 1 "got $actual"; fi
else
  report "cmd-half sha256 pin (python3 not found)" 1 "python3 is required to compute the sha256"
fi

out=$(env -i HOME="$TMP" PATH= "$bash_bin" "$root/hooks/run-hook.cmd" probe-ok 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "empty PATH dispatches" 0 ""; else report "empty PATH dispatches" 1 "rc=$rc out=$out"; fi

out=$(env -i HOME="$TMP" PATH= "$bash_bin" "$root/hooks/run-hook.cmd" probe-exit 2>&1); rc=$?
if [ "$rc" = 7 ] && [[ "$out" == *probe-ran* ]]; then report "exit code propagates under empty PATH" 0 ""; else report "exit code propagates under empty PATH" 1 "rc=$rc out=$out"; fi

# shellcheck disable=SC2016 # $1/$2 are expanded by the inner bash, not this shell
out=$("$bash_bin" -c 'cd "$1" && exec "$2" run-hook.cmd probe-ok' _ "$root/hooks" "$bash_bin" 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "bare name from hooks/" 0 ""; else report "bare name from hooks/" 1 "rc=$rc out=$out"; fi

ln -s "$root/hooks/run-hook.cmd" "$root/hooks\\run-hook.cmd"
out=$(cd "$root" && "$bash_bin" 'hooks\run-hook.cmd' probe-ok 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "backslash in \$0" 0 ""; else report "backslash in \$0" 1 "rc=$rc out=$out"; fi

# --- a bash planted in the working directory never runs (security) ---
# An empty or relative PATH entry makes a lookup search the cwd, which for a
# hook is an untrusted project. The cwd is reached through a symlink so the
# logical and physical paths differ.
mkdir -p "$TMP/evil"
ln -s "$TMP/evil" "$TMP/evlink"
for b in bash sh; do
  printf '#!/bin/sh\n: > "%s/ran-%s"\n' "$TMP" "$b" >"$TMP/evil/$b"
  chmod +x "$TMP/evil/$b"
done
L="$root/hooks/run-hook.cmd"
planted_ran() { # prints the planted names that ran, and clears the markers
  local m ran=""
  for m in "$TMP"/ran-*; do [ -e "$m" ] && ran="$ran ${m##*/ran-}"; done
  rm -f "$TMP"/ran-*
  printf '%s' "$ran"
}
# run_evil <PATH value> <command...>: from the planted cwd; sets rc, out, ran.
run_evil() {
  local p="$1"; shift
  out=$(cd "$TMP/evlink" && env -i HOME="$TMP" PWD="$TMP/evlink" PATH="$p" "$@" </dev/null 2>&1); rc=$?
  ran=$(planted_ran)
}
# want_probe <PATH value>: "yes" when an absolute entry of it holds a bash (the
# launcher then runs the probe), "no" when none does (it must exit 0 silently;
# e.g. macOS has no /usr/bin/bash, Linux with a merged /usr does).
want_probe() {
  local e
  local IFS=:
  for e in $1; do
    case "$e" in /*) if [ -x "$e/bash" ]; then echo yes; return; fi ;; esac
  done
  echo no
}
planted_check() { # name | want-probe(yes/no)
  local probe_ok=0
  if [ "$2" = yes ]; then
    if [[ "$out" != *probe-ran* ]]; then probe_ok=1; fi
  else
    if [[ "$out" == *probe-ran* ]]; then probe_ok=1; fi
  fi
  if [ "$rc" = 0 ] && [ -z "$ran" ] && [ "$probe_ok" = 0 ]; then report "$1 (probe runs: $2)" 0 ""; else report "$1 (probe runs: $2)" 1 "rc=$rc planted ran:[$ran] out=$out"; fi
}

if [ -x /bin/dash ]; then
  for p in "" ".:/usr/bin" ":/usr/bin"; do
    run_evil "$p" /bin/dash "$L" probe-ok
    planted_check "planted bash: /bin/dash launcher, PATH='$p'" "$(want_probe "${p:-/usr/bin:/bin}")"
  done
else
  echo "SKIP: planted bash under /bin/dash (/bin/dash not found)"
fi

# bash started with argv0 "bash" fills $BASH by a PATH search, which can land
# in the cwd. exec -a works on bash 3.2 and 5.x.
for p in "" ".:/usr/bin"; do
  # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
  run_evil "$p" "$bash_bin" -c 'exec -a bash "$0" "$@"' "$bash_bin" "$L" probe-ok
  planted_check "planted bash: argv0 bash, PATH='$p'" "$(want_probe "${p:-/usr/bin:/bin}")"
done
# No bash on the cleaned PATH, so the $BASH fallback is reached, and $BASH is
# the planted cwd bash: it must be refused (exit 0, nothing runs).
# shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
run_evil "/nonexistent:" "$bash_bin" -c 'exec -a bash "$0" "$@"' "$bash_bin" "$L" probe-ok
planted_check "planted bash: argv0 bash, PATH='/nonexistent:' (\$BASH in cwd refused)" no
# $BASH = <cwd>/lnk/../../bash, with lnk -> a/b/c inside the project. Read
# textually, that is the directory above the cwd; exec resolves the symlink
# before the "..", so it runs <cwd>/a/bash. The check must agree with exec.
mkdir -p "$TMP/evil/a/b/c"
ln -s a/b/c "$TMP/evil/lnk"
printf '#!/bin/sh\n: > "%s/ran-dotdot"\n' "$TMP" >"$TMP/evil/a/bash"
chmod +x "$TMP/evil/a/bash"
# shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
run_evil "/nonexistent:lnk/../.." "$bash_bin" -c 'exec -a bash "$0" "$@"' "$bash_bin" "$L" probe-ok
if [ "$rc" = 0 ] && [ -z "$ran" ] && [ -z "$out" ]; then report "planted bash: \$BASH reaches the cwd through a symlink and .. (refused, silent exit)" 0 ""; else report "planted bash: \$BASH reaches the cwd through a symlink and .. (refused, silent exit)" 1 "rc=$rc planted ran:[$ran] out=$out"; fi
# The PATH clean-up is what stops this one: in POSIX mode bash's `command -v`
# turns an empty entry's hit into an absolute cwd path, which rule (a) would
# accept. The real bash sits on an absolute entry after it.
mkdir -p "$TMP/realbin"
ln -s "$bash_bin" "$TMP/realbin/bash"
run_evil ":$TMP/realbin" "$bash_bin" --posix "$L" probe-ok
planted_check "planted bash: bash --posix launcher, PATH=':<dir with a real bash>'" yes
# ...while a $BASH outside the cwd is still used when PATH has no bash.
run_evil "/nonexistent" "$bash_bin" "$L" probe-ok
planted_check "bash-less PATH falls back to an absolute \$BASH" yes

# --- containment covers the project root, not just the cwd tree ---
# A hook can run from a subdirectory of the project. With a relative ..
# entry, $BASH = <root>/sub/../bash, which resolves to <root>/bash: outside
# the cwd tree, inside the project. The project root is CLAUDE_PROJECT_DIR,
# else CURSOR_PROJECT_DIR, when absolute.
mkdir -p "$TMP/proj/sub"
printf '#!/bin/sh\n: > "%s/ran-rootbash"\n' "$TMP" >"$TMP/proj/bash"
chmod +x "$TMP/proj/bash"
for pv in CLAUDE_PROJECT_DIR CURSOR_PROJECT_DIR; do
  # shellcheck disable=SC2016 # $0/$@ are expanded by the inner bash
  out=$(cd "$TMP/proj/sub" && env -i HOME="$TMP" PWD="$TMP/proj/sub" PATH="/nonexistent:.." "$pv=$TMP/proj" \
    "$bash_bin" -c 'exec -a bash "$0" "$@"' "$bash_bin" "$L" probe-ok </dev/null 2>&1); rc=$?
  ran=$(planted_ran)
  if [ "$rc" = 0 ] && [ -z "$ran" ] && [ -z "$out" ]; then report "\$BASH inside $pv from a subdirectory cwd (refused, silent exit)" 0 ""; else report "\$BASH inside $pv from a subdirectory cwd (refused, silent exit)" 1 "rc=$rc planted ran:[$ran] out=$out"; fi
done
# A project root elsewhere still lets an outside $BASH through; a named root
# that does not resolve refuses it (fail closed).
out=$(cd "$TMP/evil" && env -i HOME="$TMP" PATH=/nonexistent CLAUDE_PROJECT_DIR="$TMP/proj" "$bash_bin" "$L" probe-ok </dev/null 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "\$BASH outside CLAUDE_PROJECT_DIR is used" 0 ""; else report "\$BASH outside CLAUDE_PROJECT_DIR is used" 1 "rc=$rc out=$out"; fi
out=$(cd "$TMP/evil" && env -i HOME="$TMP" PATH=/nonexistent CLAUDE_PROJECT_DIR="$TMP/no-such-root" "$bash_bin" "$L" probe-ok </dev/null 2>&1); rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then report "unresolvable CLAUDE_PROJECT_DIR refuses \$BASH" 0 ""; else report "unresolvable CLAUDE_PROJECT_DIR refuses \$BASH" 1 "rc=$rc out=$out"; fi

# --- cwd / contains every $BASH (bash 5.3 pattern quirk) ---
# The containment pattern strips the cwd's trailing /; at cwd / that leaves
# an empty prefix, and bash 5.3 does not match "${v%/}"/* when the expansion
# is empty (dash and bash 3.2 do). With no bash on PATH, an absolute $BASH must
# still be refused there. Run under every shell we can find.
seen=" "
for sh_bin in /opt/homebrew/bin/bash /usr/local/bin/bash /bin/bash /bin/dash "$bash_bin"; do
  if [ ! -x "$sh_bin" ]; then continue; fi
  case "$seen" in *" $sh_bin "*) continue ;; esac
  seen="$seen$sh_bin "
  out=$(cd / && env -i HOME="$TMP" PWD=/ PATH=/nonexistent BASH="$bash_bin" "$sh_bin" "$L" probe-ok </dev/null 2>&1); rc=$?
  if [ "$rc" = 0 ] && [ -z "$out" ]; then report "cwd / refuses \$BASH ($sh_bin)" 0 ""; else report "cwd / refuses \$BASH ($sh_bin)" 1 "rc=$rc out=$out"; fi
done

# --- no self re-exec (M2): an ENOEXEC fallback sets $BASH to the launcher ---
# bounded <outfile> <command...>: runs it in the background and kills it after
# 10 s (macOS has no timeout(1)); sets rc (124 on timeout).
bounded() {
  local o="$1" pid i=0; shift
  "$@" >"$o" 2>&1 </dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge 100 ]; then
      kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rc=124; return
    fi
    sleep 0.1; i=$((i + 1))
  done
  wait "$pid"; rc=$?
}
# shellcheck disable=SC2016 # $0 is expanded by the inner sh
bounded "$TMP/m2-out" env -i HOME="$TMP" PATH=/usr/bin:/bin /bin/sh -c '"$0" probe-ok' "$L"
out=$(cat "$TMP/m2-out")
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "no self re-exec: sh -c '\"\$0\" probe-ok' <launcher>" 0 ""; else report "no self re-exec: sh -c '\"\$0\" probe-ok' <launcher>" 1 "rc=$rc (124 = still running after 10 s) out=$(head -c 300 "$TMP/m2-out")"; fi
# shellcheck disable=SC2016 # $0 is expanded by the inner sh
bounded "$TMP/m2b-out" env -i HOME="$TMP" PATH=/nonexistent /bin/sh -c '"$0" probe-ok' "$L"
if [ "$rc" = 0 ] && [ ! -s "$TMP/m2b-out" ]; then report "no self re-exec, bash-less PATH: exits 0 silently" 0 ""; else report "no self re-exec, bash-less PATH: exits 0 silently" 1 "rc=$rc (124 = still running after 10 s) out=$(head -c 300 "$TMP/m2b-out")"; fi

exit $fail
