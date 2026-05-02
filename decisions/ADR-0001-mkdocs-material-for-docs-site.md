# ADR-0001: Use MkDocs Material for Documentation Site

**Date:** 2026-05-02
**Status:** Accepted
**Deciders:** Dillon Frawley

## Context

The docs site (6 HTML pages at dollardill.github.io/beads-superpowers) is hand-written HTML with a shared sidebar nav, dark theme CSS, and Mermaid diagrams. Two problems have compounded over time:

1. The skill count is hardcoded as "22 skills" in 15+ files (CLAUDE.md, README, plugin.json, install.sh, CI, 6 HTML pages). Every skill addition requires a manual find-and-replace across all files.
2. HTML pages are maintained separately from Markdown documentation. Content drifts, prose must be updated in two places, and there is no single source of truth.

We evaluated 7 static site generators: MkDocs Material, Eleventy, VitePress, Docusaurus, Jekyll, mdBook, and Docsify.

## Decision

Use **MkDocs Material** with the **mkdocs-macros-plugin** for the documentation site. Markdown files become the single source of truth, rendered to HTML at build time with computed template variables.

## Rationale

MkDocs Material is the only option that natively satisfies all six requirements without custom code:

- **Computed template variables:** `mkdocs-macros-plugin` runs Python at build time. A 5-line `main.py` counts `skills/*/` directories and exposes `{{ skill_count }}` in any Markdown page.
- **Mermaid diagrams:** Built into Material theme with automatic dark/light adaptation. No plugin needed.
- **Dark theme + sidebar navigation:** Built-in toggle and auto-generated nav from file structure.
- **Lightweight:** ~50MB Python install vs. Eleventy (~80MB Node), VitePress (~150MB), Docusaurus (~300MB).
- **GitHub Pages deployment:** Official 15-line GitHub Actions workflow.
- **Actively maintained:** 22k+ GitHub stars, maintained by squidfunk.

Eleventy was the runner-up but requires building your own theme, finding a Mermaid community plugin, and writing 3-5 config files instead of 1 YAML.

## Consequences

- **Positive:** Skill count and version are computed at build time. Adding a skill no longer requires updating 15+ files. Markdown is the single source of truth for all doc pages.
- **Positive:** Existing styles.css and nav.js can be retired. Material theme handles layout, navigation, and theming.
- **Negative:** Adds a Python build dependency (`pip install mkdocs-material mkdocs-macros-plugin`). CI must run `mkdocs build` before deploying.
- **Negative:** Migration effort: 6 HTML pages must be converted to Markdown. Mermaid diagrams use fenced code blocks (already the Markdown standard) rather than `<div class="mermaid">` tags.
- **Risk:** The current hand-written HTML has custom layout touches (card grids, lightbox panzoom) that may need Material theme overrides or custom CSS to preserve.
