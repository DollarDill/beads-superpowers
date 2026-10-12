#!/usr/bin/env bash
# Seeds a side-project portal for the using-superpowers corp-path cases (B3) and its P2 control.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p side-projects/acme-portal
cat > side-projects/acme-portal/README.md <<'EOF'
A personal side project.
EOF
