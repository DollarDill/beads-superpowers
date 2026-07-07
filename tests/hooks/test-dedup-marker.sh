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

echo "PASS: dedup marker"
