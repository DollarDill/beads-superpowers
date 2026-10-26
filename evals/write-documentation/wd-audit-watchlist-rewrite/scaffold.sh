#!/usr/bin/env bash
# Seeds one README paragraph that leans on a repeated fallback opener, plus one
# right-word use of a watchlisted term, for the wd-audit-watchlist-rewrite case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > NOTES.md <<'EOT'
# Notes for the README

datekit parses `YYYY-MM-DD` and `YYYY/MM/DD` strings and returns `null` for anything else instead of throwing. It's worth noting that every parsed date lands at UTC midnight, so `parseDate("2026-03-01")` is the same instant in every time zone. It's worth noting that `formatDate` prints in the caller's local zone unless you pass `{ utc: true }`. It's worth noting that the package has no runtime dependencies and needs Node 18 or later. It's worth noting that the test harness runs every case under three time zones: UTC, America/Los_Angeles and Asia/Tokyo.
EOT
