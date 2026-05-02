#!/usr/bin/env bash
# build-docs.sh — Full docs build: sync skill counts + mkdocs build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Syncing skill counts ==="
bash scripts/sync-skill-count.sh

echo "=== Building MkDocs site ==="
mkdocs build --strict

echo "=== Done ==="
echo "Site built to site/"
echo "To serve locally: mkdocs serve"
echo "To deploy: mkdocs gh-deploy --force"
