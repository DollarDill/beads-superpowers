#!/usr/bin/env bash
# Seeds a corporate-work portal for the using-superpowers corp-path met case (B2).
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p corporate-work/acme-portal
cat > corporate-work/acme-portal/README.md <<'EOF'
Client portal for Acme Corp (consultancy engagement). Built to the agreed statement of work.
EOF
