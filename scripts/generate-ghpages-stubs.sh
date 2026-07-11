#!/usr/bin/env bash
# Generate the gh-pages SEO redirect-stub tree (ADR-0050). Deterministic:
# titles come from scripts/ghpages-stub-titles.tsv (captured 2026-07-11,
# before the old site was replaced). Usage: generate-ghpages-stubs.sh <out-dir>
set -euo pipefail
OUT="${1:?usage: generate-ghpages-stubs.sh <out-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
NEW_BASE="https://algocents.com/beads-superpowers"
TSV="$HERE/ghpages-stub-titles.tsv"
[ -f "$TSV" ] || { echo "missing $TSV" >&2; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT"
while IFS= read -r line; do
  # NOTE: not `IFS=$'\t' read -r p title` — bash treats tab as "IFS
  # whitespace" even when IFS is set to tab-only, so a leading tab (the
  # root path's empty first field) gets stripped instead of producing an
  # empty $p, corrupting the homepage stub. Split by parameter expansion
  # instead, which has no such whitespace-collapse behavior.
  p="${line%%$'\t'*}"
  title="${line#*$'\t'}"
  new_url="$NEW_BASE/$p"
  lang=en; case "$p" in zh/*|zh) lang=zh ;; esac
  mkdir -p "$OUT/$p"
  cat > "$OUT/${p}index.html" <<EOF
<!doctype html>
<html lang="$lang">
<head>
<meta charset="utf-8">
<title>$title</title>
<meta http-equiv="refresh" content="0; url=$new_url">
<link rel="canonical" href="$new_url">
<script>location.replace("$new_url");</script>
</head>
<body>
<p>This page has moved to <a href="$new_url">$new_url</a>.</p>
</body>
</html>
EOF
done < "$TSV"
touch "$OUT/.nojekyll"
# All 6 preserved files verbatim from /tmp/oldsite (captured in Task 1 Step 1):
# both sitemap variants + gz twins (old GSC/robots reference sitemap_index too),
# the inert-but-served subpath robots.txt, and the GSC verification token.
for f in sitemap.xml sitemap.xml.gz sitemap_index.xml sitemap_index.xml.gz robots.txt googlec875b47c36713f6b.html; do
  cp -f "/tmp/oldsite/$f" "$OUT/$f" || { echo "missing /tmp/oldsite/$f — run Task 1 Step 1" >&2; exit 1; }
done
cat > "$OUT/404.html" <<EOF
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Page moved — beads-superpowers</title></head>
<body><p>The beads-superpowers docs have moved to
<a href="$NEW_BASE/">$NEW_BASE/</a>.</p></body></html>
EOF
echo "OK: stub tree at $OUT"
