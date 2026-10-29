#!/usr/bin/env bash
# Seeds an empty URL-shortener repo for the using-superpowers cold-approved-design-routes-brainstorming case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > README.md <<'EOF'
# URL shortener service
EOF
