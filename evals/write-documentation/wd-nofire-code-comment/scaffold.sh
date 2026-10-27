#!/usr/bin/env bash
# Seeds a tiny date-parsing library with a change list for the write-documentation eval cases.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src
cat > README.md <<'EOT'
# datekit

A small library for parsing and formatting dates.
EOT
cat > package.json <<'EOT'
{
  "name": "datekit",
  "version": "1.4.0",
  "type": "module"
}
EOT
cat > src/parse.js <<'EOT'
export function parseDate(input) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(input);
  if (!m) return null;
  return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
}
EOT
cat > CHANGES.md <<'EOT'
# Changes since 1.4.0

- `parseDate` now accepts `YYYY/MM/DD` as well as `YYYY-MM-DD` (issue #31).
- `parseDate` returns `null` instead of throwing on an empty string. Callers that relied on the exception must check for `null`.
- Fixed `formatDate` printing the previous day for users west of UTC when the input was a date-only string (issue #44).
- Dropped Node 16 support; the minimum is now Node 18.
EOT
