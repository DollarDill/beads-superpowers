#!/usr/bin/env bash
# Asserts hooks/run-hook.cmd (the polyglot launcher) dispatches on Unix with an
# empty PATH, propagates exit codes, and matches the pinned upstream v7.0.1 hash.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PINNED=d1fcecfe19df2d083994803f73417710f745bd96c0938f594f87096005b1e403
fail=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
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

actual=$(python3 -I -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$ROOT/hooks/run-hook.cmd")
if [ "$actual" = "$PINNED" ]; then report "sha256 pin" 0 ""; else report "sha256 pin" 1 "got $actual"; fi

out=$(env -i HOME="$TMP" PATH= "$bash_bin" "$root/hooks/run-hook.cmd" probe-ok 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "empty PATH dispatches" 0 ""; else report "empty PATH dispatches" 1 "rc=$rc out=$out"; fi

out=$(env -i HOME="$TMP" PATH= "$bash_bin" "$root/hooks/run-hook.cmd" probe-exit 2>&1); rc=$?
if [ "$rc" = 7 ] && [[ "$out" == *probe-ran* ]]; then report "exit code propagates under empty PATH" 0 ""; else report "exit code propagates under empty PATH" 1 "rc=$rc out=$out"; fi

out=$("$bash_bin" -c 'cd "$1" && exec "$2" run-hook.cmd probe-ok' _ "$root/hooks" "$bash_bin" 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "bare name from hooks/" 0 ""; else report "bare name from hooks/" 1 "rc=$rc out=$out"; fi

ln -s "$root/hooks/run-hook.cmd" "$root/hooks\\run-hook.cmd"
out=$(cd "$root" && "$bash_bin" 'hooks\run-hook.cmd' probe-ok 2>&1); rc=$?
if [ "$rc" = 0 ] && [[ "$out" == *probe-ran* ]]; then report "backslash in \$0" 0 ""; else report "backslash in \$0" 1 "rc=$rc out=$out"; fi

exit $fail
