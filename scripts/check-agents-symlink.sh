#!/usr/bin/env bash
# Verify AGENTS.md is committed as a symlink to CLAUDE.md (ADR-0063).
# Git-level check — immune to Windows working-tree materialization.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

mode="$(git ls-files -s AGENTS.md | awk '{print $1}')"
if [ "$mode" != "120000" ]; then
  echo "AGENTS.md is not committed as a symlink (mode=$mode, expected 120000)"
  echo "  → a Windows checkout may have materialized it; re-create with: ln -s CLAUDE.md AGENTS.md"
  exit 1
fi

target="$(git cat-file blob :AGENTS.md)"
if [ "$target" != "CLAUDE.md" ]; then
  echo "AGENTS.md symlink target is '$target', expected 'CLAUDE.md'"
  exit 1
fi

echo "AGENTS.md: symlink → CLAUDE.md (mode 120000)"
