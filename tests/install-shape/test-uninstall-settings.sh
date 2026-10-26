#!/usr/bin/env bash
# test-uninstall-settings.sh — install.sh --uninstall against odd settings files:
# an unparseable or unreadable file is left byte-for-byte untouched with no
# backup and a warning that the entries were NOT removed, while the rest of the
# uninstall still runs and exits 0; malformed-but-valid shapes never crash; a
# settings path with shell/Python metacharacters is handled; a normal file is
# cleaned and backed up once.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
fail=0
n=0

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# setup lays down a real install first (rest-of-uninstall evidence) and removes
# the settings file the install wrote; each case then writes the one it wants.
BSP='{"type":"command","command":"bash /x/beads-superpowers-session-start.sh"}'
FOREIGN='{"type":"command","command":"echo foreign"}'

# setup / run_uninstall set $h $log $rc for the case that follows.
setup() {
  n=$((n + 1))
  h="$SANDBOX/h$n"; log="$SANDBOX/h$n.log"
  mkdir -p "$h/.claude"
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$SANDBOX/h$n.install.log" 2>&1
  rm -f "$h/.claude/settings.json"
}
run_uninstall() {
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --uninstall >"$log" 2>&1
  rc=$?
}
backups() { find "$1/.claude" -maxdepth 1 -name 'settings.json.backup-*' -exec echo x \; | wc -l | tr -d ' '; }

untouched_case() {
  setup
  # shellcheck disable=SC2059
  printf "$2" >"$h/.claude/settings.json"
  untouched_check "$1"
}
# untouched_check runs the uninstall on the settings file already in $h.
untouched_check() {
  local name="$1" before after
  before=$(sha "$h/.claude/settings.json")
  run_uninstall
  after=$(sha "$h/.claude/settings.json")
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$after" ]; then echo "FAIL [$name]: settings file was modified"; fail=1; fi
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [$name]: a backup was created"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT removed'"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: claimed hooks were removed"; fail=1; fi
  if grep -q "Traceback" "$log"; then echo "FAIL [$name]: traceback in output"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}

untouched_case "truncated JSON" '{"hooks": '
untouched_case "not json" 'not json'
untouched_case "empty file" ''
untouched_case "whitespace only" ' \n\n'

# A BOM or a UTF-16/UTF-32 encoding is refused, as the install path refuses
# it (register_hook reads the file as text): untouched, even with our entries.
untouched_case "UTF-8 BOM" "\xef\xbb\xbf{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}]}}"
for enc in utf-16 utf-16-le utf-32; do
  setup
  python3 -I - "$h/.claude/settings.json" "$enc" "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}]}}" <<'PY'
import sys
with open(sys.argv[1], "wb") as f:
    f.write(sys.argv[3].encode(sys.argv[2]))
PY
  untouched_check "$enc"
done

# A directory at the settings path is handled like invalid JSON.
setup
mkdir -p "$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [directory]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ ! -d "$h/.claude/settings.json" ]; then echo "FAIL [directory]: settings path was modified"; fail=1; fi
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [directory]: a backup was created"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [directory]: no warning"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [directory]: traceback"; fail=1; fi
if [ -e "$h/skills/.beads-superpowers-version" ]; then echo "FAIL [directory]: rest of the uninstall did not run"; fail=1; fi

# Valid-JSON shapes that are not what we write: never crash, foreign data kept.
shape_case() {
  local name="$1" content="$2" check="$3"
  setup
  printf '%s' "$content" >"$h/.claude/settings.json"
  run_uninstall
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if grep -q "Traceback" "$log"; then echo "FAIL [$name]: traceback"; fail=1; fi
  if ! python3 -I - "$h/.claude/settings.json" "$check" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
  then echo "FAIL [$name]: settings content wrong after uninstall"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}
shape_case "hooks null" '{"hooks": null, "keep": 1}' 'd == {"hooks": None, "keep": 1}'
if [ "$(cat "$h/.claude/settings.json")" != '{"hooks": null, "keep": 1}' ]; then echo "FAIL [hooks null]: file not byte-identical"; fail=1; fi
shape_case "hooks a list" '{"hooks": [1], "keep": 1}' 'd["hooks"] == [1] and d["keep"] == 1'
shape_case "SessionStart not a list" '{"hooks": {"SessionStart": "x", "Other": [1]}}' 'd["hooks"]["SessionStart"] == "x"'
shape_case "mixed entries" \
  "{\"hooks\": {\"SessionStart\": [1, null, {\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}" \
  'd["hooks"]["SessionStart"] == [1, None, {"hooks": [{"type": "command", "command": "echo foreign"}]}]'
shape_case "top level a list" '[1, 2]' 'd == [1, 2]'

# A normal file: entries removed, foreign kept, exactly one backup, info shown.
setup
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}], \"UserPromptSubmit\": [{\"hooks\": [$BSP]}]}}" >"$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [normal]: exit $rc"; fail=1; fi
if grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q "echo foreign" "$h/.claude/settings.json"; then echo "FAIL [normal]: wrong content"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [normal]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [normal]: no removal message"; fail=1; fi

# A settings path with a double quote, backslash and dollar in it.
n=$((n + 1))
h="$SANDBOX/h$n\"q\\\$x"; log="$SANDBOX/h$n.log"
mkdir -p "$h/.claude"
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}" >"$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [odd path]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q "echo foreign" "$h/.claude/settings.json"; then echo "FAIL [odd path]: wrong content"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [odd path]: traceback"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [odd path]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [odd path]: no removal message"; fail=1; fi

# The same with a newline in the path.
n=$((n + 1))
h="$SANDBOX/h$n"$'\n'"nl"; log="$SANDBOX/h$n.log"
mkdir -p "$h/.claude"
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}" >"$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [newline path]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if grep -q "beads-superpowers" "$h/.claude/settings.json" || ! grep -q "echo foreign" "$h/.claude/settings.json"; then echo "FAIL [newline path]: wrong content"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [newline path]: traceback"; fail=1; fi
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [newline path]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [newline path]: no removal message"; fail=1; fi

# Valid file with nothing of ours in it: byte-identical, no backup, no removal claim.
setup
printf '%s' "{\"hooks\": {\"SessionStart\": [{\"hooks\": [$FOREIGN]}]}}" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [nothing to remove]: exit $rc"; fail=1; fi
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [nothing to remove]: file was rewritten"; fail=1; fi
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [nothing to remove]: a backup was created"; fail=1; fi
if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [nothing to remove]: claimed hooks were removed"; fail=1; fi

# Failure paths on a file that HAS entries to remove: no exception text, file
# untouched, no stray backup, fixed warning, rest of the uninstall runs, exit 0.
failure_case() {
  local name="$1" before
  before=$(sha "$h/.claude/settings.json")
  run_uninstall
  chmod 755 "$h/.claude"; chmod 644 "$h/.claude/settings.json"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [$name]: settings file was modified"; fail=1; fi
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [$name]: stray backup left"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT removed'"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: claimed hooks were removed"; fail=1; fi
  if grep -Eq "Traceback|Error|File \"|errno|Permission denied" "$log"; then echo "FAIL [$name]: exception text in output"; grep -E "Traceback|Error|File \"|errno|Permission denied" "$log" | head -3; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}
WITH_ENTRIES="{\"hooks\": {\"SessionStart\": [{\"hooks\": [$BSP]}, {\"hooks\": [$FOREIGN]}]}}"

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
chmod 444 "$h/.claude/settings.json"
failure_case "read-only settings file"

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
chmod 555 "$h/.claude"
failure_case "unwritable .claude dir"

setup
python3 -I -c 'import sys; sys.stdout.write("[" * 100000)' >"$h/.claude/settings.json"
failure_case "deeply nested JSON"

# A rewrite that fails after the file was opened (file-size limit hit partway):
# the file must stay byte-identical, no backup or temp file is left, and the
# message must not claim a removal. `ulimit -f 1` is 1024 bytes in bash's
# default mode. The limit applies only inside the subshell; the log is written
# by `cat` outside it.
setup
F3="{\"hooks\":{\"SessionStart\":[{\"hooks\":[$BSP]}"
for _ in 1 2 3 4 5 6 7 8; do F3="$F3,{\"hooks\":[$FOREIGN]}"; done
printf '%s' "$F3]}}" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
if ! python3 -I - "$h/.claude/settings.json" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
d["hooks"]["SessionStart"] = d["hooks"]["SessionStart"][1:]
sys.exit(0 if os.path.getsize(sys.argv[1]) < 1024 < len(json.dumps(d, indent=2)) + 1 else 1)
PY
then echo "FAIL [write fails partway]: fixture does not straddle the 1024-byte limit"; fail=1; fi
( ulimit -f 1; HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" bash "$REPO_ROOT/install.sh" --uninstall 2>&1 ) | cat >"$log"
rc=${PIPESTATUS[0]}
# bash before 5.1 writes heredocs to a temp file, which the limit also blocks,
# so python never runs and the rewrite is not reached: say so, don't fail.
if grep -q "cannot create temp file for here document" "$log"; then
  echo "SKIP [write fails partway]: this bash cannot create a heredoc under the limit; the settings file is still checked"
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [write fails partway]: settings file was modified"; fail=1; fi
else
  if [ "$rc" != 0 ]; then echo "FAIL [write fails partway]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [write fails partway]: settings file was modified ($(wc -c <"$h/.claude/settings.json") bytes now)"; fail=1; fi
  if [ "$(backups "$h")" != 0 ]; then echo "FAIL [write fails partway]: stray backup left"; fail=1; fi
  if [ -n "$(find "$h/.claude" -maxdepth 1 -name '*.tmp' -print)" ]; then echo "FAIL [write fails partway]: temp file left"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*left unchanged.*NOT removed" "$log"; then echo "FAIL [write fails partway]: no warning naming the file, 'left unchanged' and 'NOT removed'"; fail=1; fi
  # The in-place write is cut off after 1024 bytes; the original (562 bytes,
  # under the limit) is written back and checked byte-for-byte.
  if ! grep -q "$h/.claude/settings.json.*original contents were restored" "$log"; then echo "FAIL [write fails partway]: no warning saying the original contents were restored"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [write fails partway]: claimed hooks were removed"; fail=1; fi
  if grep -Eq "Traceback|Error|File \"|errno" "$log"; then echo "FAIL [write fails partway]: exception text in output"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [write fails partway]: rest of the uninstall did not run"; fail=1
  fi
fi

# A symlinked settings file stays a symlink; its target is cleaned.
setup
mkdir -p "$h/dotfiles"
printf '%s' "$WITH_ENTRIES" >"$h/dotfiles/settings.json"
ln -s "$h/dotfiles/settings.json" "$h/.claude/settings.json"
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [symlink]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ ! -L "$h/.claude/settings.json" ]; then echo "FAIL [symlink]: settings.json is no longer a symlink"; fail=1; fi
if grep -q "beads-superpowers" "$h/dotfiles/settings.json" || ! grep -q "echo foreign" "$h/dotfiles/settings.json"; then echo "FAIL [symlink]: target not cleaned"; fail=1; fi
if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [symlink]: no removal message"; fail=1; fi

# A read-only backup that already has this run's one-second name is not ours:
# it must survive, byte-identical. Names are pre-made for the next 30 seconds.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
python3 -I - "$h/.claude/settings.json" <<'PY'
import os, sys, time
now = time.time()
for i in range(30):
    p = sys.argv[1] + ".backup-" + time.strftime("%Y%m%d-%H%M%S", time.localtime(now + i))
    with open(p, "w") as f:
        f.write("pre-existing\n")
    os.chmod(p, 0o444)
PY
run_uninstall
if [ "$rc" != 0 ]; then echo "FAIL [pre-existing backup]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ "$(backups "$h")" != 30 ]; then echo "FAIL [pre-existing backup]: expected the 30 pre-existing backups, found $(backups "$h")"; fail=1; fi
if grep -L -x "pre-existing" "$h/.claude/settings.json.backup-"* 2>/dev/null | grep -q .; then echo "FAIL [pre-existing backup]: a pre-existing backup was overwritten"; fail=1; fi
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [pre-existing backup]: settings file was modified"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [pre-existing backup]: no warning naming the file and 'NOT removed'"; fail=1; fi
if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [pre-existing backup]: claimed hooks were removed"; fail=1; fi

# The file itself is rewritten in place (same inode), so what hangs off the
# inode is kept: hard links, the group, ACL entries, extended attributes.
cleaned() {
  if grep -q "beads-superpowers" "$1" || ! grep -q "echo foreign" "$1"; then return 1; fi
}
meta_ok() {
  local name="$1"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if ! cleaned "$h/.claude/settings.json"; then echo "FAIL [$name]: settings not cleaned"; fail=1; fi
  if [ "$(backups "$h")" != 1 ]; then echo "FAIL [$name]: expected exactly one backup, got $(backups "$h")"; fail=1; fi
  if ! grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: no removal message"; fail=1; fi
}
gid() { python3 -I -c 'import os, sys; print(os.stat(sys.argv[1]).st_gid)' "$1"; }

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
ln "$h/.claude/settings.json" "$h/settings.hardlink"
run_uninstall
meta_ok "hard link"
if [ ! "$h/.claude/settings.json" -ef "$h/settings.hardlink" ]; then echo "FAIL [hard link]: the two names no longer share an inode"; fail=1; fi
if ! cleaned "$h/settings.hardlink"; then echo "FAIL [hard link]: the other name does not see the cleaned content"; fail=1; fi

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
g0=$(gid "$h/.claude/settings.json"); g1=""
for g in $(id -G); do
  if [ "$g" != "$g0" ] && chgrp "$g" "$h/.claude/settings.json" 2>/dev/null; then g1=$g; break; fi
done
if [ -z "$g1" ]; then
  echo "SKIP [group]: this user has no second group to set on the file"
else
  run_uninstall
  meta_ok "group"
  if [ "$(gid "$h/.claude/settings.json")" != "$g1" ]; then echo "FAIL [group]: group changed from $g1 to $(gid "$h/.claude/settings.json")"; fail=1; fi
fi

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
if chmod +a "user:_www deny read" "$h/.claude/settings.json" 2>/dev/null; then
  run_uninstall
  meta_ok "ACL"
  acl=$(ls -le "$h/.claude/settings.json")  # macOS shows ACL entries only via ls -le
  case "$acl" in
    *"user:_www deny read"*) ;;
    *) echo "FAIL [ACL]: the deny-read ACL entry was dropped"; fail=1 ;;
  esac
elif command -v setfacl >/dev/null 2>&1 && setfacl -m u:nobody:r "$h/.claude/settings.json" 2>/dev/null; then
  run_uninstall
  meta_ok "ACL"
  if ! getfacl -p "$h/.claude/settings.json" 2>/dev/null | grep -q "^user:nobody:r"; then echo "FAIL [ACL]: the user:nobody ACL entry was dropped"; fail=1; fi
else
  echo "SKIP [ACL]: neither 'chmod +a' nor setfacl can set an ACL here"
fi

setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
if xattr -w com.example.tag kept "$h/.claude/settings.json" 2>/dev/null; then
  run_uninstall
  meta_ok "xattr"
  if [ "$(xattr -p com.example.tag "$h/.claude/settings.json" 2>/dev/null)" != kept ]; then echo "FAIL [xattr]: the extended attribute was dropped"; fail=1; fi
elif python3 -I -c 'import os, sys; os.setxattr(sys.argv[1], "user.example", b"kept")' "$h/.claude/settings.json" 2>/dev/null; then
  run_uninstall
  meta_ok "xattr"
  if ! python3 -I -c 'import os, sys; sys.exit(os.getxattr(sys.argv[1], "user.example") != b"kept")' "$h/.claude/settings.json" 2>/dev/null; then echo "FAIL [xattr]: the extended attribute was dropped"; fail=1; fi
else
  echo "SKIP [xattr]: no extended attribute can be set here"
fi

# Fault injection into the in-place write: install.sh runs python3 -I, which
# ignores PYTHONPATH, so a python3 wrapper first on PATH loads inject.py (it
# wraps os calls for the settings file or its backup only) before running the
# script install.sh pipes to `python3 -I -`. Other python3 runs pass through.
# BSP_FAULT_MODE is a comma-separated set of faults:
#   partial         the first write stops halfway with an error
#   restore-fails   every later write fails
#   restore-raises  every later write completes, then raises
#   fsync           every fsync of the settings file raises
#   close           closing the settings file closes it, then raises
#   unlink          removing a backup raises
#   unlink-removes  removing a backup removes it, then raises
#   trace           no fault; append write / dirsync / fullfsync to $BSP_FAULT_LOG
FI="$SANDBOX/fi"; mkdir -p "$FI"
cat >"$FI/inject.py" <<'PY'
import errno, os, stat
_path = os.environ.get("BSP_FAULT_PATH")
_mode = set((os.environ.get("BSP_FAULT_MODE") or "").split(","))
_log = os.environ.get("BSP_FAULT_LOG")
def _note(what):
    if "trace" in _mode and _log:
        with open(_log, "a") as f:
            f.write(what + "\n")
def _kind(fd):
    try:
        st = os.fstat(fd)
    except OSError:
        return None
    if stat.S_ISDIR(st.st_mode):
        try:
            return "dir" if os.path.samestat(st, os.stat(os.path.dirname(_path))) else None
        except (OSError, TypeError):
            return None
    return "file" if stat.S_ISREG(st.st_mode) else None
try:
    import fcntl
    _fcntl = fcntl.fcntl
    def _fc(fd, op, *a):
        if op == getattr(fcntl, "F_FULLFSYNC", None) and _kind(fd) == "file" and not _ours(fd):
            _note("fullfsync")
        return _fcntl(fd, op, *a)
    fcntl.fcntl = _fc
except ImportError:
    pass
_write, _fsync, _close, _remove, _unlink = os.write, os.fsync, os.close, os.remove, os.unlink
_hits = [0]
def _ours(fd):
    try:
        return _path is not None and os.path.samestat(os.fstat(fd), os.stat(_path))
    except OSError:
        return False
def _fail():
    raise OSError(errno.EIO, "injected")
def write(fd, data):
    if _ours(fd):
        _note("write")
        _hits[0] += 1
        if _hits[0] == 1 and "partial" in _mode:
            _write(fd, bytes(data)[: max(1, len(data) // 2)])
            _fail()
        if _hits[0] > 1 and "restore-fails" in _mode:
            _fail()
        if _hits[0] > 1 and "restore-raises" in _mode:
            view = memoryview(data)
            while view:
                view = view[_write(fd, view):]
            _fail()
    return _write(fd, data)
def fsync(fd):
    if _kind(fd) == "dir":
        _note("dirsync")
    if "fsync" in _mode and _ours(fd):
        _fail()
    return _fsync(fd)
def close(fd):
    ours = "close" in _mode and _ours(fd)
    _close(fd)
    if ours:
        _fail()
def _rm(real):
    def rm(p, *a, **k):
        if "unlink" in _mode and ".backup-" in str(p):
            _fail()
        if "unlink-removes" in _mode and ".backup-" in str(p):
            real(p, *a, **k)
            _fail()
        return real(p, *a, **k)
    return rm
os.write, os.fsync, os.close = write, fsync, close
os.remove, os.unlink = _rm(_remove), _rm(_unlink)
PY
mkdir -p "$FI/bin"
{
  printf '#!/bin/bash\n'
  printf 'py=%q\n' "$(command -v python3)"
  printf 'inject=%q\n' "$FI/inject.py"
  cat <<'SH'
if [ "${1:-}" = -I ] && [ "${2:-}" = - ]; then
  shift 2
  exec "$py" -I -c 'import sys
exec(open(sys.argv.pop(1)).read())
sys.argv[0] = "-"
exec(compile(sys.stdin.read(), "<stdin>", "exec"), {"__name__": "__main__"})' "$inject" "$@"
fi
exec "$py" "$@"
SH
} >"$FI/bin/python3"
chmod +x "$FI/bin/python3"
fault_run() {
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" PATH="$FI/bin:$PATH" \
    BSP_FAULT_PATH="$h/.claude/settings.json" BSP_FAULT_MODE="$1" BSP_FAULT_LOG="$h.trace" \
    bash "$REPO_ROOT/install.sh" --uninstall >"$log" 2>&1
  rc=$?
}
fault_common() {
  local name="$1"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT removed" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT removed'"; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: claimed hooks were removed"; fail=1; fi
  if grep -Eq "Traceback|Error|File \"|errno|injected" "$log"; then echo "FAIL [$name]: exception text in output"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
}

# Restore works: the file is byte-identical again and the backup is removed.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
fault_run partial
fault_common "write fails, restored"
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [write fails, restored]: settings file not byte-identical to the original"; fail=1; fi
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [write fails, restored]: stray backup left"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*original contents were restored" "$log"; then echo "FAIL [write fails, restored]: no message saying the original was restored"; fail=1; fi

# Restore impossible: the backup is kept, holds the original bytes, and the
# message names it and says the restore failed.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
fault_run partial,restore-fails
fault_common "write fails, restore fails"
if [ "$(backups "$h")" != 1 ]; then echo "FAIL [write fails, restore fails]: expected the backup to be kept, found $(backups "$h")"; fail=1; fi
for b in "$h/.claude/settings.json.backup-"*; do
  if [ ! -f "$b" ]; then continue; fi
  if [ "$before" != "$(sha "$b")" ]; then echo "FAIL [write fails, restore fails]: backup is not byte-identical to the original"; fail=1; fi
  if ! grep -qF "$b" "$log"; then echo "FAIL [write fails, restore fails]: message does not name the backup $b"; fail=1; fi
done
if ! grep -q "$h/.claude/settings.json.*could not be restored" "$log"; then echo "FAIL [write fails, restore fails]: message does not say the restore failed"; fail=1; fi

# A kept backup holds the original bytes and the message names it; every
# backup path any message names exists. $1 case name, $2 sha of the original.
kept_backup() {
  local name="$1" orig="$2" b
  if [ "$(backups "$h")" != 1 ]; then echo "FAIL [$name]: expected the backup to be kept, found $(backups "$h")"; fail=1; fi
  for b in "$h/.claude/settings.json.backup-"*; do
    if [ ! -f "$b" ]; then continue; fi
    if [ "$orig" != "$(sha "$b")" ]; then echo "FAIL [$name]: backup is not byte-identical to the original"; fail=1; fi
    if ! grep -qF "$b" "$log"; then echo "FAIL [$name]: message does not name the backup $b"; fail=1; fi
  done
  named_exist "$name"
}
named_exist() {
  local b
  while IFS= read -r b; do
    if [ ! -e "$h/.claude/$b" ]; then echo "FAIL [$1]: a message names $b, which does not exist"; fail=1; fi
  done < <(grep -o 'settings\.json\.backup-[0-9-]*' "$log" | sort -u)
}
# close(2) fails after a write (network/FUSE filesystems report write-back
# errors there): the file may have changed, so the backup is kept and named,
# no removal is claimed and no exception text is printed.
close_case() {
  local name="$1" mode="$2"
  setup
  printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
  before=$(sha "$h/.claude/settings.json")
  fault_run "$mode"
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if grep -Eq "Traceback|Error|File \"|errno|injected" "$log"; then echo "FAIL [$name]: exception text in output"; grep -E "Traceback|Error|File \"|errno|injected" "$log" | head -3; fail=1; fi
  if grep -q "Removed hooks from settings.json" "$log"; then echo "FAIL [$name]: claimed hooks were removed"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*closing it failed.*may have changed" "$log"; then echo "FAIL [$name]: message does not say closing failed and the file may have changed"; fail=1; fi
  if [ -e "$h/skills/.beads-superpowers-version" ] || ! grep -q "beads-superpowers uninstalled" "$log"; then
    echo "FAIL [$name]: rest of the uninstall did not run"; fail=1
  fi
  kept_backup "$name" "$before"
}
close_case "close fails after rewrite" close
close_case "close fails after restore" partial,close

# The restore's own write or fsync raises although the bytes read back match:
# the restore did not complete cleanly, so the backup is kept and named.
for mode in partial,restore-raises partial,fsync; do
  setup
  printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
  before=$(sha "$h/.claude/settings.json")
  fault_run "$mode"
  name="restore raises ($mode)"
  fault_common "$name"
  kept_backup "$name" "$before"
  if grep -q "restored and checked" "$log"; then echo "FAIL [$name]: claimed a clean restore"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*could not be restored or the restore could not be confirmed" "$log"; then echo "FAIL [$name]: message does not say the restore could not be confirmed"; fail=1; fi
done

# The backup cannot be removed after a clean restore: the message says an
# identical copy remains and names it.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
fault_run partial,unlink
name="backup removal fails"
fault_common "$name"
kept_backup "$name" "$before"
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [$name]: settings file not byte-identical to the original"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*original contents were restored" "$log"; then echo "FAIL [$name]: no message saying the original was restored"; fail=1; fi
if ! grep -q "identical copy.*remains" "$log"; then echo "FAIL [$name]: message does not say an identical copy remains"; fail=1; fi

# Removing the backup reports a failure but did remove it: no message may
# point at the backup, which no longer exists.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
before=$(sha "$h/.claude/settings.json")
fault_run partial,unlink-removes
name="backup removal reports failure but removed it"
fault_common "$name"
if [ "$(backups "$h")" != 0 ]; then echo "FAIL [$name]: expected no backup, found $(backups "$h")"; fail=1; fi
if [ "$before" != "$(sha "$h/.claude/settings.json")" ]; then echo "FAIL [$name]: settings file not byte-identical to the original"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*original contents were restored" "$log"; then echo "FAIL [$name]: no message saying the original was restored"; fail=1; fi
named_exist "$name"

# The backup's directory entry is fsynced (and on macOS the backup gets
# F_FULLFSYNC) before the settings file is first written.
setup
printf '%s' "$WITH_ENTRIES" >"$h/.claude/settings.json"
fault_run trace
name="backup durable before rewrite"
meta_ok "$name"
first_write=$(grep -n -m1 -x write "$h.trace" 2>/dev/null | cut -d: -f1)
dirsync=$(grep -n -m1 -x dirsync "$h.trace" 2>/dev/null | cut -d: -f1)
if [ -z "$first_write" ]; then echo "FAIL [$name]: trace saw no write to the settings file"; fail=1; fi
if [ -z "$dirsync" ] || [ -z "$first_write" ] || [ "$dirsync" -gt "$first_write" ]; then echo "FAIL [$name]: the directory was not fsynced before the first write"; fail=1; fi
if [ "$(uname -s)" = Darwin ]; then
  full=$(grep -n -m1 -x fullfsync "$h.trace" 2>/dev/null | cut -d: -f1)
  if [ -z "$full" ] || [ -z "$first_write" ] || [ "$full" -gt "$first_write" ]; then echo "FAIL [$name]: the backup did not get F_FULLFSYNC before the first write"; fail=1; fi
fi

if [ "$fail" -eq 0 ]; then echo "PASS: --uninstall handles the settings file safely"; fi
exit "$fail"
