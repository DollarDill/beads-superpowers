# Assets

This directory contains static image assets used by the README and GitHub repo metadata.

## Files

| File | Dimensions | Purpose |
|------|------------|---------|
| `banner.svg` | 1280×320 | Hero banner embedded at the top of `README.md`. Hand-rolled SVG with slate→indigo gradient, mono title, two-line tagline, hexagon glyph accent. |
| `social-preview.png` | 1280×640 | GitHub social preview image shown on shared links (Twitter, Slack, etc). Rendered from `banner.svg`, padded vertically to 640px for GitHub's 2:1 social-card aspect ratio. |

## Regenerating the social preview PNG

If `banner.svg` changes, regenerate `social-preview.png` with:

```bash
rsvg-convert -w 1280 -h 640 assets/banner.svg -o assets/social-preview.png
```

Alternative with ImageMagick:

```bash
convert -density 200 assets/banner.svg -resize 1280x640 assets/social-preview.png
```

## Uploading to GitHub (manual step)

GitHub's REST API does not expose the social preview image upload endpoint, so this step must be done through the web UI:

1. Open [https://github.com/DollarDill/beads-superpowers/settings](https://github.com/DollarDill/beads-superpowers/settings)
2. Scroll to **Social preview**
3. Click **Edit** → **Upload an image**
4. Select `assets/social-preview.png`
5. Save

Once uploaded, the preview is cached by GitHub and by downstream consumers (Twitter, Slack, Discord link unfurls) — changes may take a few minutes to propagate.
