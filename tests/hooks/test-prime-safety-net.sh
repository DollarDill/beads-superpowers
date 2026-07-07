#!/usr/bin/env bash
# tests/hooks/test-prime-safety-net.sh
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/run" "$TMP/home"
cat > "$TMP/bin/bd" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  config)   cat "${BSP_CFG:-/dev/null}" ;;
  memories) printf '' ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/bd"
export PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/run" HOME="$TMP/home"

# Distinct stdin per invocation — each run its own event (dedup-marker-safe)
run_hook() { printf '{"session_id":"net-%s","source":"startup"}' "$1" | bash "$HOOK" --emit-plain >/dev/null; }

# 1. no .beads → no file
mkdir -p "$TMP/w1" && cd "$TMP/w1"
run_hook w1
[ -e .beads/PRIME.md ] && { echo "FAIL: scaffolded .beads"; exit 1; }

# 2. .beads exists → file written, small, self-documenting
mkdir -p "$TMP/w2/.beads" && cd "$TMP/w2"
run_hook w2
[ -f .beads/PRIME.md ] || { echo "FAIL: net not written"; exit 1; }
[ "$(wc -c < .beads/PRIME.md)" -lt 1024 ] || { echo "FAIL: net too large"; exit 1; }
grep -q "delete this file" .beads/PRIME.md || { echo "FAIL: uninstall line missing"; exit 1; }

# 3. existing file untouched
printf 'USER CONTENT\n' > .beads/PRIME.md
run_hook w2b
[ "$(cat .beads/PRIME.md)" = "USER CONTENT" ] || { echo "FAIL: overwrote user file"; exit 1; }

# 3b. symlinked PRIME.md untouched (never write through)
mkdir -p "$TMP/w2c/.beads" && cd "$TMP/w2c"
ln -s /etc/hostname .beads/PRIME.md
run_hook w2c
[ "$(readlink .beads/PRIME.md)" = "/etc/hostname" ] || { echo "FAIL: symlink replaced"; exit 1; }

# 4. off-switch respected
mkdir -p "$TMP/w3/.beads" && cd "$TMP/w3"
printf '  custom.prime-safety-net = false (database)\n' > "$TMP/cfg"
BSP_CFG="$TMP/cfg" run_hook w3
[ -e .beads/PRIME.md ] && { echo "FAIL: off-switch ignored"; exit 1; }
echo "PASS: prime safety net"
