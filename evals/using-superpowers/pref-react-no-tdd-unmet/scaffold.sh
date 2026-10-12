#!/usr/bin/env bash
# Seeds a non-React Node CLI for the using-superpowers duration cases (B5, E1) and its P2 control.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src
cat > README.md <<'EOF'
# duration-cli

A command-line tool for working with durations.
EOF
cat > package.json <<'EOF'
{"name":"duration-cli","private":true,"bin":{"duration":"src/cli.js"},"dependencies":{"commander":"^12.0.0"}}
EOF
