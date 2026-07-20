#!/usr/bin/env bash
# E2E installer test — host-side wrapper
# Usage: ./tests/installer/run-tests.sh
#
# Prerequisites: docker OR podman must be installed and running.
# What it does:
#   1. Builds a local tarball from the repo checkout
#   2. Builds the test image with the selected runtime
#   3. Runs the container with install.sh + tarball volume-mounted
#   4. Reports pass/fail from the container
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (TTY-aware)
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; BLUE=''; NC=''
fi

info()    { printf "${BLUE}info${NC}  %s\n" "$1"; }
error()   { printf "${RED}error${NC} %s\n" "$1" >&2; }
success() { printf "${GREEN}✓${NC} %s\n" "$1"; }

# --- Select container runtime ---
# shellcheck source=tests/installer/runtime-detect.sh
source "$SCRIPT_DIR/runtime-detect.sh"
RUNTIME=$(select_runtime) || exit 1
info "Using runtime: $RUNTIME"

# Podman needs SELinux confinement disabled for the read-only bind mounts
# (avoids relabeling host source files); empty for docker.
RUN_OPTS=()
if [ "$RUNTIME" = "podman" ]; then
    RUN_OPTS=(--security-opt label=disable)
fi

# --- Preflight checks ---
if ! "$RUNTIME" info >/dev/null 2>&1; then
    error "$RUNTIME is not functional (\`$RUNTIME info\` failed)."
    if [ "$RUNTIME" = "docker" ]; then
        echo "  Start Docker Desktop or run: sudo systemctl start docker"
    else
        echo "  Check your podman setup: podman info"
    fi
    echo "  Or use the built-in test mode: bash install.sh --test"
    exit 1
fi

# --- Read version from package.json ---
version=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/package.json'))['version'])")
info "Testing install.sh for beads-superpowers v$version"

# --- Build tarball ---
tarball=$(mktemp /tmp/beads-superpowers-release-XXXXXX.tar.gz)

info "Building local tarball..."
tar czf "$tarball" \
    -C "$REPO_ROOT" \
    --transform "s,^,beads-superpowers-${version}/," \
    skills/ hooks/ example-workflow/ .claude-plugin/ .codex-plugin/ .opencode/

chmod 644 "$tarball"  # readable by container's non-root user
info "Tarball: $(du -h "$tarball" | cut -f1)"

# Generate checksums.txt alongside tarball
checksums=$(mktemp /tmp/beads-superpowers-checksums-XXXXXX.txt)
sha256sum "$tarball" | sed "s|$tarball|release.tar.gz|" > "$checksums"
chmod 644 "$checksums"
info "Checksums: $(cat "$checksums")"

trap 'rm -f "$tarball" "$checksums"' EXIT

# --- Build test image ---
info "Building image with $RUNTIME..."
if ! "$RUNTIME" build -t beads-installer-test "$SCRIPT_DIR" 2>&1; then
    error "$RUNTIME image build failed."
    exit 1
fi

# --- Run container ---
info "Running E2E tests in container..."
echo

exit_code=0
"$RUNTIME" run --rm ${RUN_OPTS[@]+"${RUN_OPTS[@]}"} \
    -v "$REPO_ROOT/install.sh:/src/install.sh:ro" \
    -v "$tarball:/src/release.tar.gz:ro" \
    -v "$checksums:/src/checksums.txt:ro" \
    -v "$SCRIPT_DIR/test-installer.sh:/src/test-installer.sh:ro" \
    -e "VERSION=$version" \
    beads-installer-test \
    bash /src/test-installer.sh || exit_code=$?

echo
if [ "$exit_code" -eq 0 ]; then
    success "E2E installer test passed"
else
    error "E2E installer test failed (exit code: $exit_code)"
fi

exit "$exit_code"
