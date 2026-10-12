#!/usr/bin/env bash
# Seeds an empty URL-shortener repo for the using-superpowers spec-location case (B6) and its P2 control.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > README.md <<'EOF'
# URL shortener service
EOF
