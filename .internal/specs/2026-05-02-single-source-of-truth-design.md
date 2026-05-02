# Design: Single Source of Truth for Docs and Skill Counts

**Date:** 2026-05-02
**Status:** Approved
**Bead:** bd-crk (brainstorming), bd-ipm (epic)
**ADR:** [ADR-0001](../../decisions/ADR-0001-mkdocs-material-for-docs-site.md)

## Overview

Migrate the beads-superpowers docs site from hand-written HTML to MkDocs Material with Markdown as the single source of truth. Add a context-aware sed script to keep skill counts synchronized across all non-docs files. Eliminate the maintenance burden of updating 15+ files on every skill addition.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Docs site generator | MkDocs Material | Only SSG that natively handles computed variables, Mermaid, dark theme, sidebar, and GitHub Pages with minimal config (1 YAML) |
| Template variables | mkdocs-macros-plugin | `main.py` with `define_env()` runs Python at build time. `{{ skill_count }}` in Markdown. |
| Non-docs file sync | Context-aware sed script | `sync-skill-count.sh` uses contextual patterns ("N skills", "N composable skills") to update CLAUDE.md, README, plugin.json, install.sh, CI. Idempotent, no markers. |
| Deployment | gh-pages branch | MkDocs' official pattern. `mkdocs gh-deploy --force` via GitHub Actions. `docs/` on main reverts to internal reference docs only. |
| Markdown source dir | `docs-src/` | Separates site source from internal reference docs in `docs/` |

## System Architecture

```
Layer 1: Source of Truth
├── docs-src/           ← Markdown source files for docs site
│   ├── index.md
│   ├── getting-started.md
│   ├── methodology.md
│   ├── skills.md
│   ├── workflow.md
│   └── tips.md
├── mkdocs.yml          ← Theme, nav, plugins config
└── main.py             ← Macros: skill_count, version, skill_names

Layer 2: Build Pipeline
├── scripts/build-docs.sh       ← Entry point: sync-skill-count + mkdocs build
├── scripts/sync-skill-count.sh ← Idempotent: count skills, sed all files
└── .github/workflows/deploy-docs.yml ← CI: build + gh-deploy

Layer 3: Output
└── site/               ← MkDocs output (gitignored, deployed to gh-pages)
```

## Computed Variables

Defined in `main.py`, available as `{{ var }}` in all Markdown pages:

| Variable | Source | Example |
|----------|--------|---------|
| `skill_count` | `len(os.listdir('skills/'))` filtered to dirs | `22` |
| `invocable_count` | `skill_count - 1` (minus using-superpowers) | `21` |
| `version` | `package.json` → version field | `0.5.1` |
| `skill_names` | Sorted list of `skills/*/` dir names | `['auditing-upstream-drift', ...]` |

## Non-Docs File Sync

`scripts/sync-skill-count.sh` counts `skills/*/` directories and uses context-aware sed patterns:

| File | Pattern | Example |
|------|---------|---------|
| CLAUDE.md | `N composable skills`, `N beads-native skills`, `Skills (N Total)` | `22 composable skills` |
| README.md | `N skills are now active`, `All N skills` | `22 skills are now active` |
| plugin.json | `N skills +` | `22 skills +` |
| install.sh | `N skills in`, `N skills to`, `N+ skills available` | `22 skills to` |
| ci.yml | `-lt N` | `-lt 22` |

The script is idempotent: running it when counts are already correct changes nothing.

CI runs `sync-skill-count.sh --check` to validate — fails if any file has a stale count.

## MkDocs Configuration

```yaml
site_name: beads-superpowers
site_url: https://dollardill.github.io/beads-superpowers
docs_dir: docs-src
repo_url: https://github.com/DollarDill/beads-superpowers

theme:
  name: material
  palette:
    scheme: slate
    primary: indigo
  features:
    - navigation.sections
    - navigation.expand
    - toc.integrate

plugins:
  - search
  - macros

markdown_extensions:
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Methodology: methodology.md
  - Skills Reference: skills.md
  - Example Workflow: workflow.md
  - Tips & Tricks: tips.md
```

## Macros Plugin

```python
import os, json

def define_env(env):
    skill_dirs = sorted([
        d for d in os.listdir('skills/')
        if os.path.isdir(f'skills/{d}')
    ])
    with open('package.json') as f:
        version = json.load(f)['version']

    env.variables['skill_count'] = len(skill_dirs)
    env.variables['invocable_count'] = len(skill_dirs) - 1
    env.variables['version'] = version
    env.variables['skill_names'] = skill_dirs
```

## GitHub Pages Deployment

New workflow `.github/workflows/deploy-docs.yml`:

```yaml
name: Deploy Docs

on:
  push:
    branches: [main]
    paths:
      - 'docs-src/**'
      - 'mkdocs.yml'
      - 'main.py'
      - 'skills/**'

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - run: pip install mkdocs-material mkdocs-macros-plugin
      - run: mkdocs gh-deploy --force
```

## Migration: HTML → Markdown

Each HTML page is converted to Markdown:

| HTML Page | Markdown Source | Key Changes |
|-----------|----------------|-------------|
| `docs/index.html` | `docs-src/index.md` | Card grid → Material grid extension or custom CSS |
| `docs/getting-started.html` | `docs-src/getting-started.md` | Straightforward: mostly code blocks |
| `docs/methodology.html` | `docs-src/methodology.md` | Already rewritten as Markdown (METHODOLOGY.md). Merge. |
| `docs/skills.html` | `docs-src/skills.md` | Largest page. Skill trigger table, category map, chaining diagram. |
| `docs/workflow.html` | `docs-src/workflow.md` | Multiple Mermaid diagrams + code blocks |
| `docs/tips.html` | `docs-src/tips.md` | Tables + code blocks |

For all pages:
- `<div class="mermaid">...</div>` → ` ```mermaid ... ``` `
- Hardcoded `22 skills` → `{{ skill_count }} skills`
- Hardcoded `v0.5.1` → `v{{ version }}`
- Shared sidebar nav → handled by MkDocs nav config
- Custom CSS (lightbox panzoom) → evaluate Material equivalents or add as `extra_css`

## What Stays in `docs/`

After migration, `docs/` on main contains only internal reference docs:

- `docs/METHODOLOGY.md` — Delete (superseded by `docs-src/methodology.md`)
- `docs/SETUP-GUIDE.md`, `docs/testing.md` — Internal reference (not on site)
- `docs/01-09 analysis files` — Research deep dives
- `docs/decisions/` — ADRs
- `docs/beads-superpowers/specs/` — Design specs
- `docs/audits/` — Upstream drift audits

The 6 HTML files, `styles.css`, `nav.js`, `sitemap.xml`, and `robots.txt` are deleted (MkDocs generates its own).

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Custom HTML features (card grids, lightbox) don't translate | Medium | Medium | Material has grid support. Panzoom can be added as extra JS. Evaluate during migration. |
| Python dependency added to contributor workflow | Low | Low | Only needed for building docs locally. CI handles deployment. `pip install` is one command. |
| Broken links during migration | Medium | Low | Run `mkdocs build --strict` which fails on broken links. Add link check to CI. |
| SEO impact from URL change | Low | Low | Old URLs (docs/*.html) redirect. Material generates sitemap.xml. |
