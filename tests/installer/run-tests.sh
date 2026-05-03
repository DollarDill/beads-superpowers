#!/usr/bin/env bash
# E2E installer test — host-side wrapper
# Usage: ./tests/installer/run-tests.sh
#
# Prerequisites: Docker must be installed and running.
# What it does:
#   1. Builds a local tarball from the repo checkout
#   2. Builds the Docker test image
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

# --- Preflight checks ---
if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed or not in PATH."
    echo "  Install Docker: https://docs.docker.com/get-docker/"
    echo "  Or use the built-in test mode: bash install.sh --test"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running."
    echo "  Start Docker Desktop or run: sudo systemctl start docker"
    exit 1
fi

# --- Read version from package.json ---
version=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/package.json'))['version'])")
info "Testing install.sh for beads-superpowers v$version"

# --- Build tarball ---
tarball=$(mktemp /tmp/beads-superpowers-release-XXXXXX.tar.gz)
trap 'rm -f "$tarball"' EXIT

info "Building local tarball..."
tar czf "$tarball" \
    -C "$REPO_ROOT" \
    --transform "s,^,beads-superpowers-${version}/," \
    skills/ hooks/ example-workflow/ .claude-plugin/ agents/

chmod 644 "$tarball"  # readable by container's non-root user
info "Tarball: $(du -h "$tarball" | cut -f1)"

# --- Build Docker image ---
info "Building Docker image..."
if ! docker build -t beads-installer-test "$SCRIPT_DIR" 2>&1; then
    error "Docker image build failed."
    exit 1
fi

# --- Run container ---
info "Running E2E tests in container..."
echo

exit_code=0
docker run --rm \
    -v "$REPO_ROOT/install.sh:/src/install.sh:ro" \
    -v "$tarball:/src/release.tar.gz:ro" \
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
