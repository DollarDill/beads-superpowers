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

# empty stdin: TTL-only dedup still suppresses an immediate duplicate
out4=$(bash "$HOOK" </dev/null)
echo "$out4" | grep -q 'additionalContext' || { echo "FAIL: empty-stdin first run did not inject"; exit 1; }
out5=$(bash "$HOOK" </dev/null)
echo "$out5" | grep -q 'additionalContext' && { echo "FAIL: empty-stdin duplicate injected"; exit 1; }

# marker dir permissions (dual-form stat: GNU then BSD)
dir="$TMP/run/beads-superpowers-$(id -u)"
perms=$(stat -c %a "$dir" 2>/dev/null || stat -f %Lp "$dir")
[ "$perms" = "700" ] || { echo "FAIL: marker dir not 0700 (got $perms)"; exit 1; }

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

echo "PASS: dedup marker"
