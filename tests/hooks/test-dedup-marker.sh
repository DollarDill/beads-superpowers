#!/usr/bin/env bash
# tests/hooks/test-dedup-marker.sh
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/run" "$TMP/home"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/bd"; chmod +x "$TMP/bin/bd"
export PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/run" HOME="$TMP/home"   # HOME isolated: real ~/.claude settings must not trip the bd-prime guard
cd "$TMP"

payload='{"session_id":"sess-abc","source":"startup"}'
out1=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
echo "$out1" | grep -q 'additionalContext' || { echo "FAIL: first run did not inject"; exit 1; }
out2=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
echo "$out2" | grep -q 'additionalContext' && { echo "FAIL: duplicate event injected twice"; exit 1; }

# different source (compact) same session → must inject
out3=$(printf '{"session_id":"sess-abc","source":"compact"}' | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
echo "$out3" | grep -q 'additionalContext' || { echo "FAIL: compact re-injection suppressed"; exit 1; }

# empty stdin: TTL-only dedup still suppresses an immediate duplicate.
# File-redirect, NOT $() capture: the nosid fallback is keyed on $PPID (same parent
# process = same event bucket), and bash forks a fresh subshell per $() capture,
# which would split the buckets. Direct children of THIS shell share its PID as
# their PPID — same shape as a harness firing duplicate registrations from one
# parent process.
bash "$HOOK" </dev/null > "$TMP/out4"
grep -q 'additionalContext' "$TMP/out4" || { echo "FAIL: empty-stdin first run did not inject"; exit 1; }
bash "$HOOK" </dev/null > "$TMP/out5"
grep -q 'additionalContext' "$TMP/out5" && { echo "FAIL: empty-stdin duplicate injected"; exit 1; }

# different parent processes (= different sessions on a no-stdin harness) → BOTH inject.
# Each wrapper shell is a distinct parent (trailing ':' prevents bash's exec-collapse
# of a lone command, keeping the wrapper alive as the hook's parent), so the PPID-keyed
# nosid fallback puts them in distinct buckets — no cross-session collision.
bash -c 'bash "$1" </dev/null > "$2"; :' _ "$HOOK" "$TMP/out4b"
bash -c 'bash "$1" </dev/null > "$2"; :' _ "$HOOK" "$TMP/out4c"
grep -q 'additionalContext' "$TMP/out4b" || { echo "FAIL: session-A nosid run did not inject"; exit 1; }
grep -q 'additionalContext' "$TMP/out4c" || { echo "FAIL: session-B nosid run suppressed by session-A (nosid bucket collision)"; exit 1; }

# marker dir permissions (dual-form stat: GNU then BSD)
dir="$TMP/run/beads-superpowers-$(id -u)"
perms=$(stat -c %a "$dir" 2>/dev/null || stat -f %Lp "$dir")
[ "$perms" = "700" ] || { echo "FAIL: marker dir not 0700 (got $perms)"; exit 1; }

# nosid marker filenames must embed a PID-like discriminator, one per parent process
# (test shell + 2 wrapper shells = at least 3 distinct nosid markers by this point)
nosid_markers=$(printf '%s\n' "$dir"/m-nosid-*-unknown | grep -cE '/m-nosid-[0-9]+-unknown$' || true)
[ "$nosid_markers" -ge 3 ] || { echo "FAIL: expected >=3 distinct PID-keyed nosid markers, got $nosid_markers"; exit 1; }

# symlinked marker → fail open (inject), don't write through
ln -s /etc/hostname "$dir/m-sess-lnk-startup"
out6=$(printf '{"session_id":"sess-lnk","source":"startup"}' | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
echo "$out6" | grep -q 'additionalContext' || { echo "FAIL: symlink case did not fail open"; exit 1; }
[ "$(readlink "$dir/m-sess-lnk-startup")" = "/etc/hostname" ] || { echo "FAIL: symlink replaced"; exit 1; }

# suppressed JSON run prints valid empty object
# shellcheck disable=SC2034  # out7 only establishes the marker; out8 is the assertion
out7=$(printf '{"session_id":"sess-json","source":"startup"}' | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
out8=$(printf '{"session_id":"sess-json","source":"startup"}' | CLAUDE_PLUGIN_ROOT=x bash "$HOOK")
[ "$out8" = "{}" ] || { echo "FAIL: suppressed JSON run printed '$out8' not '{}'"; exit 1; }

# suppressed plain-mode run: EMPTY output, exit 0 (no JSON no-op in plain dialect)
outp1=$(printf '{"session_id":"sess-plain","source":"startup"}' | bash "$HOOK" --emit-plain)
[ -n "$outp1" ] || { echo "FAIL: first plain run did not inject"; exit 1; }
rc=0
outp2=$(printf '{"session_id":"sess-plain","source":"startup"}' | bash "$HOOK" --emit-plain) || rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: suppressed plain run exited $rc, not 0"; exit 1; }
[ -z "$outp2" ] || { echo "FAIL: suppressed plain run produced output: $outp2"; exit 1; }

# never-EOF stdin must not prevent injection (bounded stdin read — hook must not
# block waiting for EOF). timeout runs the wrapper in its own process group and
# signals the whole group, so a hook stuck draining stdin dies output-less → grep
# fails. The `|| true` tolerates exit 124: the writer's sleep outlives the hook by
# design, so timeout always fires — the contract is output-present, not exit-0.
# shellcheck disable=SC2016  # $0/$1 are the inner bash -c shell's positional args — single quotes intentional
out9=$(timeout 5 bash -c '{ printf "%s" "$0"; sleep 30; } | CLAUDE_PLUGIN_ROOT=x bash "$1"' '{"session_id":"sess-hang","source":"startup"}' "$HOOK") || true
echo "$out9" | grep -q 'additionalContext' || { echo "FAIL: never-EOF stdin prevented injection (hook hung on stdin)"; exit 1; }

# envelope_ok <file>: the Claude envelope carrying the bootstrap was emitted.
envelope_ok() {
  python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert "Production-Grade Doctrine" in d["hookSpecificOutput"]["additionalContext"]' <"$1" 2>/dev/null
}

# The two checks below report every failure before exiting.
hard=0

# uid from the environment: with `id` unresolvable the hook falls back to a
# bash variable, and bash imports UID and EUID from the environment. A value
# that is not all digits must skip the dedup marker (inject), never build a
# marker path from it. The PATH dir holds mkdir and chmod but no id, plus
# sed, tr and cut so the session id is extracted and the uid check is reached.
mkdir -p "$TMP/noid-bin"
for t in mkdir chmod sed tr cut; do
  t_path=$(command -v "$t")
  ln -s "$t_path" "$TMP/noid-bin/$t"
done
for uid_env in "UID=/../../x EUID=" "UID=/../../x EUID=/../../x"; do
  rm -rf "$TMP/uidbase"; mkdir -p "$TMP/uidbase/rt"
  # shellcheck disable=SC2086 # uid_env is two assignments, split on purpose
  env -i HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/uidbase/rt" CLAUDE_PLUGIN_ROOT=x PATH="$TMP/noid-bin" $uid_env \
    "$BASH" "$HOOK" </dev/null >"$TMP/uid-out" 2>/dev/null \
    || { echo "FAIL: hook failed with $uid_env and no id"; hard=1; }
  outside=$(cd "$TMP/uidbase" && find . -mindepth 1 -maxdepth 1 ! -name rt)
  [ -z "$outside" ] || { echo "FAIL: $uid_env put a marker dir outside the runtime base: $outside"; hard=1; }
  envelope_ok "$TMP/uid-out" || { echo "FAIL: $uid_env with no id did not inject"; hard=1; }
done

# pre-created marker dir that is a symlink (another local user can plant
# ${XDG_RUNTIME_DIR:-/tmp}/beads-superpowers-<uid> pointing at a directory the
# victim owns): refuse it (no chmod, no marker written through it), inject.
mkdir -p "$TMP/lnkrt" "$TMP/victim"
chmod 755 "$TMP/victim"
: > "$TMP/victim/keep"
ln -s "$TMP/victim" "$TMP/lnkrt/beads-superpowers-$(id -u)"
printf '{"session_id":"sess-dirlnk","source":"startup"}' \
  | XDG_RUNTIME_DIR="$TMP/lnkrt" CLAUDE_PLUGIN_ROOT=x bash "$HOOK" >"$TMP/dirlnk-out"
vperms=$(stat -c %a "$TMP/victim" 2>/dev/null || stat -f %Lp "$TMP/victim")
[ "$vperms" = "755" ] || { echo "FAIL: symlinked marker dir: victim dir mode changed to $vperms"; hard=1; }
victim_files=$(cd "$TMP/victim" && find . -mindepth 1 | tr '\n' ' ')
[ "$victim_files" = "./keep " ] || { echo "FAIL: symlinked marker dir: victim dir contents changed: $victim_files"; hard=1; }
envelope_ok "$TMP/dirlnk-out" || { echo "FAIL: symlinked marker dir did not fail open (inject)"; hard=1; }

# session id / source extraction unavailable (sed, tr, cut missing; mkdir and
# find present): dedup may only degrade to duplicate injection, never suppress.
# Two different events (startup, then clear) from one parent process: without
# the extracted ids both would share the nosid-$PPID-unknown marker, and the
# second would be suppressed. Direct children with file redirects, so both runs
# share this shell as their parent (see the empty-stdin case above).
mkdir -p "$TMP/nosed-bin" "$TMP/nosedrt"
for t in cat mkdir find id chmod touch; do
  t_path=$(command -v "$t")
  ln -s "$t_path" "$TMP/nosed-bin/$t"
done
printf '{"session_id":"sess-nosed","source":"startup"}' \
  | env -i HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/nosedrt" CLAUDE_PLUGIN_ROOT=x PATH="$TMP/nosed-bin" \
    "$BASH" "$HOOK" >"$TMP/nosed-out1" 2>/dev/null \
  || { echo "FAIL: no-sed startup run failed"; hard=1; }
printf '{"session_id":"sess-nosed","source":"clear"}' \
  | env -i HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/nosedrt" CLAUDE_PLUGIN_ROOT=x PATH="$TMP/nosed-bin" \
    "$BASH" "$HOOK" >"$TMP/nosed-out2" 2>/dev/null \
  || { echo "FAIL: no-sed clear run failed"; hard=1; }
envelope_ok "$TMP/nosed-out1" || { echo "FAIL: no-sed startup run did not inject"; hard=1; }
envelope_ok "$TMP/nosed-out2" || { echo "FAIL: no-sed clear run suppressed (got: $(head -c 80 "$TMP/nosed-out2"))"; hard=1; }
[ "$hard" = 0 ] || exit 1

echo "PASS: dedup marker"
