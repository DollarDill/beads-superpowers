#!/usr/bin/env bash
# tests/hooks/test-prime-safety-net.sh
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/run" "$TMP/home"
cat > "$TMP/bin/bd" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  --version|version) printf 'bd version %s (test)\n' "${BSP_BD_VERSION:-1.3.0}"; exit 0 ;;
esac
case "$1 ${2:-}" in
  "config set") shift 2; printf '%s\n' "$*" >>"${BSP_SETLOG:-/dev/null}" ;;
  "config get") printf '%s\n' "${BSP_CAP_GET:-prime.max-memories (not set in config.yaml)}" ;;
  config*)      cat "${BSP_CFG:-/dev/null}" ;;
  memories*)    printf '' ;;
esac
exit 0
FAKE
chmod +x "$TMP/bin/bd"
export PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/run" HOME="$TMP/home"

# Distinct stdin per invocation — each run its own event (dedup-marker-safe)
run_hook() { printf '{"session_id":"net-%s","source":"startup"}' "$1" | bash "$HOOK" --emit-plain >/dev/null; }

# bd >= 1.3.0 appends memories to a custom PRIME.md instead of letting it
# override output, so the net pairs the file with a prime.max-memories cap.
# The fake bd logs every `config set` here; assertions read it.
export BSP_SETLOG="$TMP/setlog"
: > "$BSP_SETLOG"
caps_set() { grep -c '^prime\.max-memories ' "$BSP_SETLOG" || true; }

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

# 2b. writing the net also caps prime's appended memories section
[ "$(caps_set)" = "1" ] || { echo "FAIL: net written without a prime.max-memories cap"; exit 1; }

# 3. existing file untouched
printf 'USER CONTENT\n' > .beads/PRIME.md
run_hook w2b
[ "$(cat .beads/PRIME.md)" = "USER CONTENT" ] || { echo "FAIL: overwrote user file"; exit 1; }

# 3a. an effective cap is never re-set, and an operator's own value is kept.
#     `bd config get` is the probe: it reports what viper actually honors, so
#     it covers the nested spelling (`prime:` / `  max-memories:`) that a
#     flat-key grep of config.yaml would miss and then overwrite.
: > "$BSP_SETLOG"
BSP_CAP_GET=1 run_hook w2b2
[ "$(caps_set)" = "0" ] || { echo "FAIL: re-set an effective cap"; exit 1; }
: > "$BSP_SETLOG"
BSP_CAP_GET=25 run_hook w2b3
[ "$(caps_set)" = "0" ] || { echo "FAIL: overrode the operator's own cap value"; exit 1; }
: > "$BSP_SETLOG"
BSP_CAP_GET=0 run_hook w2b3b
[ "$(caps_set)" = "0" ] || { echo "FAIL: overrode an explicit 0 (operator chose unlimited)"; exit 1; }

# 3c. UPGRADE PATH: an older bd wrote the cap to the DATABASE, so `bd config
#     show` lists it, but 1.3.0 reads config.yaml and ignores it. `config get`
#     reports it as not set, and the hook must write a real one.
: > "$BSP_SETLOG"
printf '  prime.max-memories = 1 (database)\n' > "$TMP/cfg-db-only"
BSP_CFG="$TMP/cfg-db-only" run_hook w2b4
[ "$(caps_set)" = "1" ] || { echo "FAIL: db-only cap treated as effective; 1.3.0 would stay uncapped"; exit 1; }

# 3d. bd <= 1.2.2 never gets the cap - PRIME.md still overrides fully there,
#     and the write would land in the database on every session.
: > "$BSP_SETLOG"
BSP_BD_VERSION=1.2.2 run_hook w2b5
[ "$(caps_set)" = "0" ] || { echo "FAIL: capped on a bd that does not honor it"; exit 1; }
: > "$BSP_SETLOG"
BSP_BD_VERSION=1.4.0 run_hook w2b6
[ "$(caps_set)" = "1" ] || { echo "FAIL: version gate refused a bd newer than 1.3.0"; exit 1; }

# 3e. an unparseable `bd --version` must NOT abort the hook. Under
#     `set -euo pipefail` a bare assignment from a failing pipeline kills the
#     whole SessionStart before any context is emitted - trading a memory
#     budget nicety for a dead skill bootstrap.
: > "$BSP_SETLOG"
out=$(printf '{"session_id":"net-w2b7","source":"startup"}' \
      | BSP_BD_VERSION="unparseable" bash "$HOOK" --emit-plain) \
  || { echo "FAIL: hook aborted on an unparseable bd --version"; exit 1; }
[ -n "$out" ] || { echo "FAIL: hook emitted no context on an unparseable bd --version"; exit 1; }
case "$out" in *using-superpowers*) ;; *) echo "FAIL: bootstrap missing from output"; exit 1 ;; esac
[ "$(caps_set)" = "0" ] || { echo "FAIL: capped without knowing the bd version"; exit 1; }

# 3b. symlinked PRIME.md untouched (never write through)
mkdir -p "$TMP/w2c/.beads" && cd "$TMP/w2c"
ln -s /etc/hostname .beads/PRIME.md
run_hook w2c
[ "$(readlink .beads/PRIME.md)" = "/etc/hostname" ] || { echo "FAIL: symlink replaced"; exit 1; }

# 4. off-switch respected — for the file AND the cap
mkdir -p "$TMP/w3/.beads" && cd "$TMP/w3"
: > "$BSP_SETLOG"
printf '  custom.prime-safety-net = false (database)\n' > "$TMP/cfg"
BSP_CFG="$TMP/cfg" run_hook w3
[ -e .beads/PRIME.md ] && { echo "FAIL: off-switch ignored"; exit 1; }
[ "$(caps_set)" = "0" ] || { echo "FAIL: off-switch ignored for the cap"; exit 1; }

# 5. no .beads → no cap either (never touch a non-beads workspace)
: > "$BSP_SETLOG"
mkdir -p "$TMP/w4" && cd "$TMP/w4"
run_hook w4
[ "$(caps_set)" = "0" ] || { echo "FAIL: capped a workspace with no .beads"; exit 1; }

echo "PASS: prime safety net"
