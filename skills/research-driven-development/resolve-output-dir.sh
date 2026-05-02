#!/usr/bin/env bash
# Resolve the research output directory.
# Priority: bd config (per-project) → env var (global) → default
DIR=$(bd config get custom.research-output-dir 2>/dev/null | grep -v "not set" | head -1)
echo "${DIR:-${RESEARCH_OUTPUT_DIR:-./docs/research}}"
