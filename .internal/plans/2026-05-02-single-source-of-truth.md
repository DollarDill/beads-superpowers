# Single Source of Truth Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Each Task becomes a bead (`bd create -t task --parent <epic-id>`). Steps within tasks use checkbox (`- [ ]`) syntax for human readability.

**Goal:** Migrate the docs site from hand-written HTML to MkDocs Material with computed template variables, and add a sync script to keep skill counts correct across all project files.

**Architecture:** Markdown source files in `docs-src/` are rendered to HTML by MkDocs Material and deployed to a `gh-pages` branch via GitHub Actions. A `main.py` macros file computes `skill_count`, `version`, and `skill_names` at build time. A separate `sync-skill-count.sh` script updates non-docs files (CLAUDE.md, README, install.sh, etc.) using context-aware sed patterns.

**Tech Stack:** MkDocs Material (Python), mkdocs-macros-plugin, bash (sync script), GitHub Actions (deployment).

**Spec:** `docs/beads-superpowers/specs/2026-05-02-single-source-of-truth-design.md`
**Epic bead:** bd-ipm

---

## File Structure

```
New files:
  mkdocs.yml                          # MkDocs config
  main.py                             # Macros plugin (skill_count, version)
  docs-src/index.md                   # Home page (from docs/index.html)
  docs-src/getting-started.md         # Getting Started (from docs/getting-started.html)
  docs-src/methodology.md             # Methodology (from docs/methodology.html)
  docs-src/skills.md                  # Skills Reference (from docs/skills.html)
  docs-src/workflow.md                # Example Workflow (from docs/workflow.html)
  docs-src/tips.md                    # Tips & Tricks (from docs/tips.html)
  docs-src/assets/banner.svg          # Copied from assets/
  docs-src/stylesheets/extra.css      # Custom overrides for Material theme
  scripts/sync-skill-count.sh         # Idempotent skill count updater
  scripts/build-docs.sh               # Orchestrator: sync + mkdocs build
  .github/workflows/deploy-docs.yml   # GitHub Actions: mkdocs gh-deploy

Modified files:
  .gitignore                          # Add site/ directory
  .github/workflows/ci.yml            # Add sync-skill-count --check validation

Deleted files:
  docs/index.html
  docs/getting-started.html
  docs/methodology.html
  docs/skills.html
  docs/workflow.html
  docs/tips.html
  docs/styles.css
  docs/nav.js
  docs/sitemap.xml
  docs/robots.txt
  docs/METHODOLOGY.md                 # Superseded by docs-src/methodology.md
```

---

### Task 1: Create sync-skill-count.sh

The sync script is independent of MkDocs and solves the immediate pain point. Ship this first so it works even before the docs migration.

**Files:**
- Create: `scripts/sync-skill-count.sh`

- [ ] **Step 1: Write the sync script**

```bash
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
        local file="$1" pattern="$2" expected="$3"
        if ! grep -qE "$pattern" "$file" 2>/dev/null; then
            echo "STALE: $file does not match pattern: $pattern"
            ERRORS=$((ERRORS + 1))
        fi
    }

    check_pattern "CLAUDE.md" "$COUNT composable skills" "$COUNT"
    check_pattern "CLAUDE.md" "$COUNT beads-native skills" "$COUNT"
    check_pattern "CLAUDE.md" "Skills \($COUNT Total\)" "$COUNT"
    check_pattern "README.md" "$COUNT skills are now active" "$COUNT"
    check_pattern "README.md" "All $COUNT skills" "$COUNT"
    check_pattern ".claude-plugin/plugin.json" "$COUNT skills" "$COUNT"
    check_pattern "install.sh" "$COUNT skills" "$COUNT"
    check_pattern ".github/workflows/ci.yml" "-lt $COUNT" "$COUNT"

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
sed -i -E "s/[0-9]+ composable skills/$COUNT composable skills/g" CLAUDE.md
sed -i -E "s/[0-9]+ beads-native skills/$COUNT beads-native skills/g" CLAUDE.md
sed -i -E "s/Skills \([0-9]+ Total\)/Skills ($COUNT Total)/g" CLAUDE.md

# README.md
sed -i -E "s/[0-9]+ skills are now active/$COUNT skills are now active/g" README.md
sed -i -E "s/All [0-9]+ skills/All $COUNT skills/g" README.md

# plugin.json — "N skills +"
sed -i -E "s/[0-9]+ skills \+/$COUNT skills +/g" .claude-plugin/plugin.json

# install.sh
sed -i -E "s/[0-9]+ skills in/$COUNT skills in/g" install.sh
sed -i -E "s/[0-9]+ skills to/$COUNT skills to/g" install.sh
sed -i -E "s/Expected >= [0-9]+ skills/Expected >= $COUNT skills/g" install.sh
sed -i -E "s/[0-9]+\+ skills available/$COUNT+ skills available/g" install.sh

# CI
sed -i -E "s/-lt [0-9]+/-lt $COUNT/g" .github/workflows/ci.yml
sed -i -E "s/at least [0-9]+ skills/at least $COUNT skills/g" .github/workflows/ci.yml

echo "Updated all files to skill count $COUNT"
```

- [ ] **Step 2: Make it executable and test**

```bash
chmod +x scripts/sync-skill-count.sh
./scripts/sync-skill-count.sh
```

Expected: `Skill count: 22 (invocable: 21)` followed by `Updated all files to skill count 22`. No files should change (counts are already 22).

- [ ] **Step 3: Test --check mode**

```bash
./scripts/sync-skill-count.sh --check
```

Expected: `OK: All files match skill count 22`

- [ ] **Step 4: Test detection of stale counts**

```bash
# Temporarily break one file
sed -i 's/22 composable skills/99 composable skills/' CLAUDE.md
./scripts/sync-skill-count.sh --check
echo "Exit code: $?"
# Restore
./scripts/sync-skill-count.sh
```

Expected: `STALE: CLAUDE.md does not match pattern...` with exit code 1, then sync restores it.

- [ ] **Step 5: Commit**

```bash
git add scripts/sync-skill-count.sh
git commit -m "feat: add sync-skill-count.sh — idempotent skill count updater (bd-qck)"
```

---

### Task 2: Add sync validation to CI

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add sync-skill-count --check step to CI**

Add after the existing "Verify skill count" step in `.github/workflows/ci.yml`:

```yaml
      - name: Validate skill count consistency
        run: ./scripts/sync-skill-count.sh --check
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add sync-skill-count validation to CI workflow (bd-qck)"
```

---

### Task 3: Create MkDocs config and macros plugin

**Files:**
- Create: `mkdocs.yml`
- Create: `main.py`
- Create: `docs-src/` directory

- [ ] **Step 1: Create mkdocs.yml**

```yaml
site_name: beads-superpowers
site_url: https://dollardill.github.io/beads-superpowers
docs_dir: docs-src
site_dir: site
repo_url: https://github.com/DollarDill/beads-superpowers
repo_name: DollarDill/beads-superpowers
edit_uri: edit/main/docs-src/

theme:
  name: material
  palette:
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to light mode
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to dark mode
  features:
    - navigation.sections
    - navigation.expand
    - navigation.top
    - toc.integrate
    - content.code.copy
  icon:
    repo: fontawesome/brands/github

plugins:
  - search
  - macros

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - tables
  - attr_list
  - md_in_html

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Methodology: methodology.md
  - Skills Reference: skills.md
  - Example Workflow: workflow.md
  - Tips & Tricks: tips.md

extra:
  social:
    - icon: fontawesome/brands/github
      link: https://github.com/DollarDill/beads-superpowers
```

- [ ] **Step 2: Create main.py**

```python
"""MkDocs macros plugin — computes template variables at build time."""
import os
import json


def define_env(env):
    """Define variables available as {{ var }} in all Markdown pages."""
    # Count skill directories
    skill_dirs = sorted([
        d for d in os.listdir('skills/')
        if os.path.isdir(os.path.join('skills/', d))
    ])

    # Read version from package.json
    with open('package.json', encoding='utf-8') as f:
        version = json.load(f)['version']

    env.variables['skill_count'] = len(skill_dirs)
    env.variables['invocable_count'] = len(skill_dirs) - 1  # minus using-superpowers
    env.variables['version'] = version
    env.variables['skill_names'] = skill_dirs
```

- [ ] **Step 3: Create docs-src/ directory with a test page**

```bash
mkdir -p docs-src
```

Create `docs-src/index.md`:

```markdown
# beads-superpowers

Process discipline and persistent memory for AI coding agents.

This plugin includes **{{ skill_count }}** composable skills and a Dolt-backed
task database. Version: **v{{ version }}**.

## Quick Start

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
\`\`\`

Then in any project:

\`\`\`bash
bd init
\`\`\`

That's it. {{ skill_count }} skills are now active. Run `/skills` in Claude Code to verify.
```

- [ ] **Step 4: Add site/ to .gitignore**

Append to `.gitignore`:

```
# MkDocs build output
site/
```

- [ ] **Step 5: Install MkDocs Material and test locally**

```bash
pip install mkdocs-material mkdocs-macros-plugin
mkdocs build --strict
```

Expected: Build succeeds, `site/index.html` exists and contains `22` (not `{{ skill_count }}`).

- [ ] **Step 6: Verify variable rendering**

```bash
grep "22 composable skills" site/index.html || grep "22" site/index.html | head -3
```

Expected: The rendered HTML contains the computed number, not the Jinja2 placeholder.

- [ ] **Step 7: Commit**

```bash
git add mkdocs.yml main.py docs-src/index.md .gitignore
git commit -m "feat: add MkDocs Material config, macros plugin, and test index page (bd-oyr)"
```

---

### Task 4: Convert getting-started.html to Markdown

**Files:**
- Create: `docs-src/getting-started.md`
- Reference: `docs/getting-started.html` (source for content extraction)

- [ ] **Step 1: Extract prose from HTML**

Read `docs/getting-started.html` and convert its `<article>` content to Markdown. Rules:
- Strip all HTML boilerplate (head, nav, sidebar, scripts)
- Convert `<h2 id="x">` to `## Title {#x}`
- Convert `<h3>` to `###`
- Convert `<code>` to backticks
- Convert `<pre><code>` to fenced code blocks
- Convert `<div class="mermaid">` to ` ```mermaid ` fenced blocks
- Convert `<table>` to Markdown tables
- Convert `<ul>/<ol>` to Markdown lists
- Convert `<blockquote>` to `>`
- Replace hardcoded `22 skills` with `{{ skill_count }} skills`
- Replace hardcoded `v0.5.1` with `v{{ version }}`
- Add page navigation at bottom if desired (MkDocs handles this via nav config)

Write the result to `docs-src/getting-started.md`.

- [ ] **Step 2: Build and verify**

```bash
mkdocs build --strict
```

Expected: No errors. Check `site/getting-started/index.html` renders correctly.

- [ ] **Step 3: Commit**

```bash
git add docs-src/getting-started.md
git commit -m "docs: convert getting-started to Markdown source (bd-oyr)"
```

---

### Task 5: Convert methodology.html to Markdown

**Files:**
- Create: `docs-src/methodology.md`
- Reference: `docs/methodology.html` (source), `docs/METHODOLOGY.md` (reference — already rewritten with write-documentation skill)

- [ ] **Step 1: Merge content from both sources**

The HTML version was recently rewritten with the write-documentation skill and has better prose. Use `docs/methodology.html` as primary source, cross-reference with `docs/METHODOLOGY.md` for any additional content (design decisions, TDD applied recursively, "What This Enables" sections).

Convert to Markdown following the same rules as Task 4. The page has 2 Mermaid diagrams — convert both to fenced blocks.

Write to `docs-src/methodology.md`.

- [ ] **Step 2: Build and verify**

```bash
mkdocs build --strict
```

Expected: No errors. Mermaid diagrams render in `site/methodology/index.html`.

- [ ] **Step 3: Commit**

```bash
git add docs-src/methodology.md
git commit -m "docs: convert methodology to Markdown source (bd-oyr)"
```

---

### Task 6: Convert skills.html to Markdown

This is the largest page (627 lines) with skill trigger tables, category tables, two Mermaid diagrams, and individual skill detail sections.

**Files:**
- Create: `docs-src/skills.md`
- Reference: `docs/skills.html`

- [ ] **Step 1: Extract and convert**

Convert `docs/skills.html` article content to Markdown. Special considerations:
- The skill trigger table should use `{{ skill_count }}` and `{{ invocable_count }}`
- Individual skill sections (22 of them) should keep their `id` attributes as `{#skill-name}` for anchor links
- Both Mermaid diagrams (category map, chaining) convert to fenced blocks
- The beads commands table converts to a Markdown table

Write to `docs-src/skills.md`.

- [ ] **Step 2: Build and verify**

```bash
mkdocs build --strict
```

Expected: No errors. Both Mermaid diagrams render. All anchor links work.

- [ ] **Step 3: Commit**

```bash
git add docs-src/skills.md
git commit -m "docs: convert skills reference to Markdown source (bd-oyr)"
```

---

### Task 7: Convert workflow.html to Markdown

**Files:**
- Create: `docs-src/workflow.md`
- Reference: `docs/workflow.html`

- [ ] **Step 1: Extract and convert**

Convert `docs/workflow.html`. Has 3 Mermaid diagrams and multiple code blocks. Follow same conversion rules as Task 4.

Write to `docs-src/workflow.md`.

- [ ] **Step 2: Build and verify**

```bash
mkdocs build --strict
```

- [ ] **Step 3: Commit**

```bash
git add docs-src/workflow.md
git commit -m "docs: convert workflow to Markdown source (bd-oyr)"
```

---

### Task 8: Convert tips.html to Markdown

**Files:**
- Create: `docs-src/tips.md`
- Reference: `docs/tips.html`

- [ ] **Step 1: Extract and convert**

Convert `docs/tips.html`. Mostly tables and code blocks, no Mermaid diagrams.

Write to `docs-src/tips.md`.

- [ ] **Step 2: Build and verify**

```bash
mkdocs build --strict
```

- [ ] **Step 3: Commit**

```bash
git add docs-src/tips.md
git commit -m "docs: convert tips to Markdown source (bd-oyr)"
```

---

### Task 9: Create build-docs.sh orchestrator and deploy workflow

**Files:**
- Create: `scripts/build-docs.sh`
- Create: `.github/workflows/deploy-docs.yml`

- [ ] **Step 1: Create build-docs.sh**

```bash
#!/usr/bin/env bash
# build-docs.sh — Full docs build: sync skill counts + mkdocs build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Syncing skill counts ==="
bash scripts/sync-skill-count.sh

echo "=== Building MkDocs site ==="
mkdocs build --strict

echo "=== Done ==="
echo "Site built to site/"
echo "To serve locally: mkdocs serve"
echo "To deploy: mkdocs gh-deploy --force"
```

- [ ] **Step 2: Create deploy-docs.yml**

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
      - 'package.json'

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: Install dependencies
        run: pip install mkdocs-material mkdocs-macros-plugin

      - name: Build and deploy
        run: mkdocs gh-deploy --force
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x scripts/build-docs.sh
```

- [ ] **Step 4: Test full build pipeline**

```bash
./scripts/build-docs.sh
```

Expected: Sync reports all counts correct, MkDocs builds successfully with `--strict`, all 6 pages render.

- [ ] **Step 5: Commit**

```bash
git add scripts/build-docs.sh .github/workflows/deploy-docs.yml
git commit -m "feat: add build-docs.sh orchestrator and deploy-docs GitHub Action (bd-oyr)"
```

---

### Task 10: Delete old HTML files and update GitHub Pages config

**Files:**
- Delete: `docs/index.html`, `docs/getting-started.html`, `docs/methodology.html`, `docs/skills.html`, `docs/workflow.html`, `docs/tips.html`, `docs/styles.css`, `docs/nav.js`, `docs/sitemap.xml`, `docs/robots.txt`
- Delete: `docs/METHODOLOGY.md` (superseded by `docs-src/methodology.md`)
- Copy: `assets/banner.svg` to `docs-src/assets/banner.svg`

- [ ] **Step 1: Copy assets needed by docs-src**

```bash
mkdir -p docs-src/assets
cp -f assets/banner.svg docs-src/assets/banner.svg
```

- [ ] **Step 2: Delete old HTML files**

```bash
rm -f docs/index.html docs/getting-started.html docs/methodology.html
rm -f docs/skills.html docs/workflow.html docs/tips.html
rm -f docs/styles.css docs/nav.js docs/sitemap.xml docs/robots.txt
rm -f docs/METHODOLOGY.md
```

- [ ] **Step 3: Update GitHub Pages source**

Go to GitHub repo Settings → Pages → change source from "Deploy from a branch: main /docs" to "Deploy from a branch: gh-pages / (root)". This cannot be done via CLI — must be done in the GitHub UI or via API:

```bash
gh api repos/DollarDill/beads-superpowers/pages \
  --method PUT \
  --field source='{"branch":"gh-pages","path":"/"}' \
  2>/dev/null || echo "NOTE: Update GitHub Pages source to gh-pages branch manually in Settings → Pages"
```

- [ ] **Step 4: Trigger initial deployment**

```bash
mkdocs gh-deploy --force
```

This pushes the built site to the `gh-pages` branch.

- [ ] **Step 5: Verify site is live**

```bash
curl -s -o /dev/null -w "%{http_code}" https://dollardill.github.io/beads-superpowers/
```

Expected: `200`

- [ ] **Step 6: Commit deletions**

```bash
git add -A docs/ docs-src/assets/
git commit -m "chore: remove old HTML docs, switch to MkDocs gh-pages deployment (bd-oyr)"
```

---

### Task 11: Update CLAUDE.md and project docs

**Files:**
- Modify: `CLAUDE.md` — Update validation commands, docs references
- Modify: `CONTRIBUTING.md` — Add docs build instructions

- [ ] **Step 1: Update CLAUDE.md validation section**

In the "Validation" section of CLAUDE.md, replace the skill count check comment and add docs build:

The skill count comment `# Verify skill count (should be 20)` should say `# Verify skill count (run sync to update)`. Add:

```bash
# Sync skill counts across all files
./scripts/sync-skill-count.sh

# Build docs site locally
pip install mkdocs-material mkdocs-macros-plugin
mkdocs serve  # Preview at http://localhost:8000
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with MkDocs build instructions (bd-oyr)"
```
