#!/usr/bin/env bash
# Seeds a README-only repo for the using-superpowers C1 case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > README.md <<'XEOF'
# Utilities

A small repo for personal utilities.
XEOF
