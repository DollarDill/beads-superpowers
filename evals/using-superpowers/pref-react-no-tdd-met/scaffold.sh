#!/usr/bin/env bash
# Seeds a React storefront for the using-superpowers React case (B4), where the no-TDD preference applies.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src
cat > README.md <<'EOF'
# duration-cli

A command-line tool for working with durations.
EOF
cat > package.json <<'EOF'
{"name":"storefront","private":true,"dependencies":{"react":"^18.2.0","react-dom":"^18.2.0"},"devDependencies":{"vite":"^5.0.0"}}
EOF
