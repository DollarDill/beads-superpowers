#!/usr/bin/env bash
# sync-skill-count.sh — Idempotent skill count updater
# Counts skills/ directories and updates all files with hardcoded counts.
# Usage: ./scripts/sync-skill-count.sh          (update in place)
#        ./scripts/sync-skill-count.sh --check   (validate only, exit 1 if stale)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

COUNT=$(find skills/ -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
INVOCABLE=$((COUNT - 1))

if [ "${1:-}" = "--check" ]; then
    ERRORS=0

    check_pattern() {
        local file="$1" pattern="$2"
        if ! grep -qE -- "$pattern" "$file" 2>/dev/null; then
            echo "STALE: $file does not match pattern: $pattern"
            ERRORS=$((ERRORS + 1))
        fi
    }

    check_pattern "CLAUDE.md" "$COUNT composable process-discipline skills" "$COUNT"
    check_pattern "CLAUDE.md" "$COUNT beads-native skills" "$COUNT"
    check_pattern "CLAUDE.md" "Skills \($COUNT Total\)" "$COUNT"
    check_pattern "README.md" "$COUNT skills enforce" "$COUNT"
    check_pattern ".claude-plugin/plugin.json" "$COUNT skills" "$COUNT"
    check_pattern "install.sh" "$COUNT skills" "$COUNT"
    check_pattern ".github/workflows/ci.yml" "at least $COUNT skills" "$COUNT"

    if [ "$ERRORS" -gt 0 ]; then
        echo "FAILED: $ERRORS file(s) have stale skill counts (expected $COUNT)"
        exit 1
    else
        echo "OK: All files match skill count $COUNT"
        exit 0
    fi
fi

echo "Skill count: $COUNT (invocable: $INVOCABLE)"

# CLAUDE.md
sed -i -E "s/[0-9]+ composable process-discipline skills/$COUNT composable process-discipline skills/g" CLAUDE.md
sed -i -E "s/[0-9]+ beads-native skills/$COUNT beads-native skills/g" CLAUDE.md
sed -i -E "s/Skills \([0-9]+ Total\)/Skills ($COUNT Total)/g" CLAUDE.md

# README.md
sed -i -E "s/[0-9]+ skills enforce/$COUNT skills enforce/g" README.md

# plugin.json — "N skills +"
sed -i -E "s/[0-9]+ skills \+/$COUNT skills +/g" .claude-plugin/plugin.json

# install.sh
sed -i -E "s/[0-9]+ skills in/$COUNT skills in/g" install.sh
sed -i -E "s/[0-9]+ skills to/$COUNT skills to/g" install.sh
sed -i -E "s/Expected >= [0-9]+ skills/Expected >= $COUNT skills/g" install.sh
sed -i -E "s/[0-9]+\+ skills available/$COUNT+ skills available/g" install.sh

# CI — only update the skill count check, not other numeric thresholds (e.g. beads density)
# Use python3 for context-aware multi-line replacement to avoid clobbering beads density -lt
python3 -c "
import re, pathlib
count = $COUNT
path = pathlib.Path('.github/workflows/ci.yml')
content = path.read_text()
# Match: -lt N on the if line, followed within 2 lines by 'Expected at least N skills'
pattern = r'(-lt )\d+(\]; then\n\s+echo \"::error::Expected at least )\d+( skills)'
replacement = rf'\g<1>{count}\g<2>{count}\g<3>'
content = re.sub(pattern, replacement, content)
path.write_text(content)
"

echo "Updated all files to skill count $COUNT"
