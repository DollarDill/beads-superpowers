#!/usr/bin/env bash
# Verify the gh-pages SEO redirect-stub tree (ADR-0050).
# Usage: verify-ghpages-stubs.sh local <dir>   — file-based checks on a generated tree
#        verify-ghpages-stubs.sh live          — HTTP checks against the served old site
set -euo pipefail
MODE="${1:?usage: verify-ghpages-stubs.sh local <dir> | live}"
DIR="${2:-}"
OLD_BASE="https://dollardill.github.io/beads-superpowers"
NEW_BASE="https://algocents.com/beads-superpowers"
PATHS=( "" "getting-started/" "methodology/" "skills/" "tips/" "workflow/" \
        "zh/" "zh/getting-started/" "zh/methodology/" "zh/skills/" "zh/tips/" "zh/workflow/" )
fail=0
say() { printf '%s\n' "$*"; }
get() {  # get <path-suffix> -> page HTML on stdout
  if [ "$MODE" = live ]; then curl -sf "$OLD_BASE/$1"; else cat "$DIR/${1}index.html"; fi
}
for p in "${PATHS[@]}"; do
  html=$(get "$p") || { say "FAIL $p: unreadable"; fail=1; continue; }
  new_url="$NEW_BASE/$p"
  echo "$html" | grep -qF "content=\"0; url=$new_url\""        || { say "FAIL $p: missing/wrong 0s refresh"; fail=1; }
  echo "$html" | grep -qF "rel=\"canonical\" href=\"$new_url\"" || { say "FAIL $p: missing/wrong canonical"; fail=1; }
  echo "$html" | grep -q  "<title>..*</title>"                  || { say "FAIL $p: empty title"; fail=1; }
  echo "$html" | grep -qF "<a href=\"$new_url\""                || { say "FAIL $p: missing visible link"; fail=1; }
  echo "$html" | grep -qi "noindex"                             && { say "FAIL $p: contains noindex"; fail=1; }
done
if [ "$MODE" = live ]; then
  curl -sf "$OLD_BASE/sitemap.xml" | grep -q "<loc>$OLD_BASE/" || { say "FAIL: old sitemap missing/wrong"; fail=1; }
  curl -sfo /dev/null "$OLD_BASE/googlec875b47c36713f6b.html"  || { say "FAIL: GSC token not served"; fail=1; }
else
  [ -f "$DIR/.nojekyll" ]                        || { say "FAIL: .nojekyll missing"; fail=1; }
  grep -q "<loc>$OLD_BASE/" "$DIR/sitemap.xml"   || { say "FAIL: sitemap missing/not old-URLs"; fail=1; }
  for f in sitemap.xml.gz sitemap_index.xml sitemap_index.xml.gz robots.txt googlec875b47c36713f6b.html; do
    [ -f "$DIR/$f" ] || { say "FAIL: $f missing"; fail=1; }
  done
  [ -f "$DIR/404.html" ]                         || { say "FAIL: 404.html missing"; fail=1; }
fi
[ "$fail" -eq 0 ] && say "PASS: all stub checks green ($MODE)"
exit "$fail"
