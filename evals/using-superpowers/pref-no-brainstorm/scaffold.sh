#!/usr/bin/env bash
# Seeds a near-empty repo for the using-superpowers B1 case and its P2 control.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > README.md <<'EOF'
# Todo app

A new project. Nothing is built yet.
EOF
