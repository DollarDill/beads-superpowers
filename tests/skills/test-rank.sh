#!/usr/bin/env bash
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: test-rank (python3 absent)"; exit 0
fi
exec python3 "$(dirname "$0")/rank_invariants.py"
