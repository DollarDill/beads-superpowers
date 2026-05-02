#!/usr/bin/env bash
# Resolve the research output directory and list category subdirectories.
# Priority: bd config (per-project) → env var (global) → default
DIR=$(bd config get custom.research-output-dir 2>/dev/null | grep -v "not set" | head -1)
RESOLVED="${DIR:-${RESEARCH_OUTPUT_DIR:-./docs/research}}"
echo "$RESOLVED"

# List category subdirectories (if any exist) so the agent can route by topic
SUBDIRS=$(find "$RESOLVED" -maxdepth 1 -mindepth 1 -type d ! -name '.*' ! -name 'node_modules' -exec basename {} \; 2>/dev/null | sort)
if [ -n "$SUBDIRS" ]; then
  echo "---categories---"
  echo "$SUBDIRS"
fi
