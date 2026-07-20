#!/usr/bin/env bash
# tests/installer/test-select-runtime.sh — unit test for select_runtime (no container).
# run: bash tests/installer/test-select-runtime.sh
set -euo pipefail
LIB="$(cd "$(dirname "$0")" && pwd)/runtime-detect.sh"
[ -f "$LIB" ] || { echo "FAIL: runtime-detect.sh missing"; exit 1; }
# shellcheck source=tests/installer/runtime-detect.sh
source "$LIB"
unset CONTAINER_RUNTIME  # hermetic: auto-detect cases must not see the caller's env

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
# Fake engines — never executed; only presence on PATH matters for `command -v`.
make_stub() { printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/$1"; chmod +x "$TMP/bin/$1"; }

# Case 1: CONTAINER_RUNTIME override wins even when both are present.
make_stub docker; make_stub podman
out=$(CONTAINER_RUNTIME=podman PATH="$TMP/bin" select_runtime)
[ "$out" = "podman" ] || { echo "FAIL: override not honored (got '$out')"; exit 1; }

# Case 2: docker-first when both present and no override.
out=$(PATH="$TMP/bin" select_runtime)
[ "$out" = "docker" ] || { echo "FAIL: docker-first not honored (got '$out')"; exit 1; }

# Case 3: podman fallback when only podman is present.
rm -f "$TMP/bin/docker"
out=$(PATH="$TMP/bin" select_runtime)
[ "$out" = "podman" ] || { echo "FAIL: podman fallback not honored (got '$out')"; exit 1; }

# Case 4: neither present -> non-zero, message on stderr, empty stdout.
rm -f "$TMP/bin/podman"
if out=$(PATH="$TMP/bin" select_runtime 2>"$TMP/err4"); then
  echo "FAIL: expected non-zero when neither runtime present"; exit 1
fi
[ -z "$out" ] || { echo "FAIL: stdout not empty on error (got '$out')"; exit 1; }
grep -q "neither docker nor podman" "$TMP/err4" || { echo "FAIL: no error message on stderr (neither present)"; exit 1; }

# Case 5: override set but binary missing -> non-zero, message on stderr, empty stdout.
make_stub docker
if out=$(CONTAINER_RUNTIME=nope PATH="$TMP/bin" select_runtime 2>"$TMP/err"); then
  echo "FAIL: expected non-zero for missing override binary"; exit 1
fi
[ -z "$out" ] || { echo "FAIL: stdout not empty on override error (got '$out')"; exit 1; }
grep -q "not found" "$TMP/err" || { echo "FAIL: no error message on stderr"; exit 1; }

echo "PASS: select_runtime"
