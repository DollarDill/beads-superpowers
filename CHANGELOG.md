# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

> **Forked from:** [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 (2026-03-31)
> **Beads integration based on:** [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.2 (2026-04-15)

## [Unreleased]

### Added

- `bd remember` prompts in 17 of 22 skills — agents are now prompted to capture persistent learnings at each skill's natural completion point. Hybrid approach: mandatory capture in 3 high-signal skills (`systematic-debugging`, `receiving-code-review`, `brainstorming`), conditional in 13 others, stale memory cleanup in `getting-up-to-speed`. Prefix conventions match the orchestrator's pattern (`root cause:`, `lesson:`, `design:`, `review:`, etc).

## [0.5.2] - 2026-05-03

### Added

- Parallel Batch Mode in `subagent-driven-development` — up to 5 independent tasks execute concurrently, each in its own `bd worktree`, with automatic mode selection via `bd ready --parent`.
- DCI for `research-driven-development` output path — resolves research directory at skill load time via `!` backtick syntax. Configurable per-project (`bd config`), per-env (`RESEARCH_OUTPUT_DIR`), or default (`.internal/research`).
- `example-workflow/agents/yegge.md` — 11-state FSM orchestrator agent with request triage, verification hard gate, ADR workflow, and session protocol. Named after Steve Yegge.
- `researcher-prompt.md` — researcher subagent prompt template. Replaces standalone agent file — the skill owns the prompt. Named after Jesse Vincent.
- Agent installation in `install.sh` — copies `yegge.md` to `~/.claude/agents/` for global availability.
- Karpathy behavioral principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) added to project `CLAUDE.md` and `AGENTS.md`. Based on [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (MIT).
- `skills/setup/get-reminder-hook.sh` — DCI resolver so the setup skill includes reminder content dynamically instead of hardcoding it.

### Changed

- `subagent-driven-development` parallel guardrails: require per-task worktree, max 5 cap, no Claude `isolation: "worktree"` parameter.
- `dispatching-parallel-agents` generalized from bug-fixing to any independent parallel work.
- `implementer-prompt.md` rewritten — now includes beads lifecycle, mandatory skill invocations (TDD, debugging, verification), and LSP-first code navigation.
- `research-driven-development` researcher dispatch uses `subagent_type: "general-purpose"` (not `"researcher"` — built-in type overrides the prompt).
- `example-workflow/CLAUDE.md` — Karpathy behavioral guidelines + project scaffolding sections + beads integration.
- `install.sh` — installs agents alongside skills; `write_reminder_script()` copies from tarball instead of hardcoding.
- Docs structure consolidated: `docs-src/` → `docs/` (website only), `docs/decisions/` → `decisions/` (tracked), internal KB → `.internal/` (gitignored). Updated `mkdocs.yml`, deploy workflow, and all skill/test path references.
- UserPromptSubmit reminder DRY'd — `hooks/superpowers-reminder.sh` is the single source of truth. `install.sh` and `setup/SKILL.md` reference it instead of hardcoding copies.
- All 8 documentation files rewritten for human readers: README.md (45% shorter), CONTRIBUTING.md (55%), docs/index.md (expanded from stub), getting-started.md (57%), methodology.md (31%), skills.md (35%), workflow.md (58%), tips.md (64%). Removed ceremony, admonitions, and redundant sections while preserving all substance.

### Removed

- `agents/implementer.md` — all implementer instructions now in `implementer-prompt.md`.
- `example-workflow/agents/implementer.md`, `researcher.md`, `jesse.md` — replaced by prompt templates in their respective skills.
- `docs-src/` directory — website source moved to `docs/`.

### Fixed

- `yegge.md` DCI syntax was broken in agent `.md` files — delegated to research skill's DCI instead.
- `CLAUDE.md` plugin structure tree was stale — updated with full directory layout.
- SDD implementer dispatch used `subagent_type: "implementer"` which overrides the prompt template. Changed to `"general-purpose"`.
- 18 staleness issues across 5 docs pages: broken links, wrong skill references, outdated claims.

## [0.5.1] - 2026-05-01

### Added

- Click-to-expand lightbox with pan/zoom for all Mermaid diagrams on docs site. Click any diagram to open fullscreen; scroll to zoom, drag to pan. Uses [panzoom](https://github.com/anvaka/panzoom) (CDN, ~14KB).
- "Last updated" date on each docs page, fetched from GitHub API (git commit history per file). Graceful degradation if API unavailable.

### Changed

- UserPromptSubmit reminder hook expanded from 9 to 20 skills (all 21 minus auto-loaded `using-superpowers`). Tiered format: 12 high-frequency skills with explicit trigger mappings + 7 "also available" skills. New triggers: `stress-test`, `research-driven-development`, `receiving-code-review`. Updated in `hooks/superpowers-reminder.sh`, `install.sh`, and `skills/setup/SKILL.md`.
- Docs site Mermaid diagrams render larger (fontSize 16, increased node/rank spacing, SVGs scale to container width).

### Fixed

- Mermaid diagrams on docs site too small and hard to read — increased font size, spacing, and CSS scaling.
- 3 Mermaid diagrams did not match surrounding page content: methodology walkthrough (was FSM states, now matches Steps 1-7), skills category map (was 14 skills, now all 21), skills chaining (added missing `document-release`).

## [0.5.0] - 2026-05-01

### Added

- Wiki-style documentation site at `dollardill.github.io/beads-superpowers` — 6 pages with HashiCorp/Terraform-style left sidebar navigation, dark theme, auto-generated TOC, and 9 Mermaid diagrams: Home, Getting Started, Methodology, Skills Reference, Example Workflow, Tips & Tricks.
- `research-driven-development` skill (#21) — dispatches parallel `@researcher` + `@explore` agents, synthesizes findings into persistent documents. Iron Law: NO RESEARCH WITHOUT A DOCUMENT.
- `example-workflow/` directory — ready-to-use CLAUDE.md with the full 11-state FSM development lifecycle, plus `researcher.md` and `implementer.md` agent configurations. Copy into any project for the complete workflow.
- `UserPromptSubmit` hook (`hooks/superpowers-reminder.sh`) — injects skill trigger reminders on every user message, preventing mid-session drift. Registered in `hooks/hooks.json` alongside SessionStart.
- `install.sh --test` flag — runs install → verify → uninstall in `/tmp/`, reports pass/fail on 5 checks, cleans up automatically.
- `bd forget`, `bd note`, and `bd find-duplicates` integrated into skills: using-superpowers quick reference, verification-before-completion evidence trail, finishing-a-development-branch pre-merge gate.
- GitHub Sponsor button via `.github/FUNDING.yml` (Buy Me a Coffee).
- Community suggestions issue (#26) for skill proposals.

### Changed

- README simplified — stripped from 255 to 67 lines. All detail now on the docs site. Quick Start + docs table + attribution + contributing invite.
- Upstream audit synced with superpowers `dev` branch (pre-v5.1.0): removed deprecated `commands/` directory (3 slash commands), removed legacy Integration sections from finishing + worktrees skills, added SDD "continuous execution" directive, updated requesting-code-review agent type and review cadence.
- `install.sh` updated: installs 21 skills (was 20), writes both SessionStart and UserPromptSubmit hooks, fallback version bumped to 0.4.1.
- `setup` skill updated to install both hooks (SessionStart + UserPromptSubmit).
- Skill count updated from 20 → 21 across all docs, HTML pages, SEO meta tags, CI workflow, and install script.
- All docs pages now have "View on GitHub" button in sidebar (replaces text link).
- Each skill tag on home page links to its SKILL.md on GitHub.

### Fixed

- `windows-lifecycle.test.sh` — fixed 2 fatal bugs: `server.js` → `server.cjs` (file was renamed), `.server-info` → `state/server-info` (path changed in server refactor).
- README incorrectly attributed 20 skills to upstream superpowers (correct: 15 upstream, 21 in fork).
- CONTRIBUTING.md falsely claimed no CODE_OF_CONDUCT.md exists (it does).
- AGENTS.md used `bd github sync` (correct: `bd github push`).
- SECURITY.md supported versions table listed 0.1.x (updated to 0.4.x).
- PR template skill count validation: 15 → 21.
- Stale claims fixed across 12+ doc files: skill counts, version numbers, TodoWrite refs, OpenViking refs, .beads/redirect refs, steveyegge org URLs.

### Removed

- `commands/` directory — 3 deprecated slash commands (brainstorm, execute-plan, write-plan). Upstream removed in superpowers v5.1.0 dev.
- `docs/beads-superpowers/` — 4 AI-generated plan/spec files from shipped features.
- `docs/googlec875b47c36713f6b.html` — Google Search Console verification file.

## [0.4.1] - 2026-04-25

### Added

- `install.sh` — curl-pipe-bash one-command installer. Downloads skills, configures SessionStart hook, and registers in settings.json in one step. Replaces the 7-step npx + setup-skill flow. Supports `--yes`, `--version`, `--dry-run`, and `--uninstall`.
- GitHub Pages site at `dollardill.github.io/beads-superpowers` — SEO-optimized landing page with Open Graph, Twitter Card, JSON-LD structured data (`SoftwareApplication` schema), sitemap.xml, and robots.txt. Source: `docs/` folder on `main` branch.
- 15 GitHub topic tags for search discoverability: `claude-code`, `claude-code-plugin`, `ai-coding-agent`, `ai-agent`, `task-tracking`, `tdd`, `code-review`, `developer-tools`, `beads`, `superpowers`, `issue-tracker`, `productivity`, `systematic-debugging`, `brainstorming`, `markdown`.
- curl install path documented in SETUP-GUIDE.md (Method 2).

## [0.4.0] - 2026-04-25

### Changed

- Updated `using-git-worktrees` skill to reflect bd v1.0.2 worktree mechanism (git common directory discovery replaces obsolete `.beads/redirect`)
- Added `bd epic status` and `bd epic close-eligible` references to executing-plans, subagent-driven-development, and finishing-a-development-branch skills
- Added `bd preflight` quality gate to finishing-a-development-branch (runs after tests pass, before merge options)
- Expanded `using-superpowers` quick reference with 6 new bd commands: `bd q`, `bd blocked`, `bd epic status`, `bd memories`, `bd recall`, `bd preflight`
- Updated CLAUDE.md beads commands table for bd v1.0.2 (5 new commands, github sync → push/pull, baseline bumped to v1.0.2)

### Added

- `getting-up-to-speed` skill — depth-adaptive session orientation: parallel `bd` context commands, parallel codebase deep-dive (light/medium/heavy paths selected by tracked-file count), top-3-open-beads drilldown, mandated structured "current state" summary, terminating without auto-claim. Brings skill total from 19 → 20.
- `document-release` skill — 9-step post-ship documentation audit (adapted from [garrytan/gstack](https://github.com/garrytan/gstack/tree/main/document-release))
- `project-init` skill — beads/Dolt database setup and recovery with 6 diagnostic paths (based on [beads SYNC_SETUP.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_SETUP.md))
- `stress-test` skill — adversarial design interrogation with recommended answers (inspired by [mattpocock/grill-me](https://github.com/mattpocock/skills/blob/main/grill-me/SKILL.md))
- `setup` skill — post-npx hook installation with settings.json backup, global/project scope selection
- CI validation workflow with 7 checks (markdownlint, plugin.json, skill count, TodoWrite residue, beads density, version sync, hook JSON)
- `release.yml` workflow — creates GitHub Release on tag push (v*) with changelog extraction
- npx installation method via Vercel Skills CLI (`npx skills add DollarDill/beads-superpowers`)
- `CODE_OF_CONDUCT.md` (Contributor Covenant, from upstream superpowers)
- Validation commands section in PR template
- Retroactive version tags: v0.1.0, v0.1.1, v0.2.0
- Upstream drift audit report and update plan in `docs/audits/` (git-ignored)

## [0.1.1] - 2026-04-11

### Added

- `assets/banner.svg` — 1280×320 hero banner SVG (slate→indigo gradient, mono text, hexagon accent)
- `.github/workflows/ci.yml` — markdownlint + plugin.json schema validation
- `.github/dependabot.yml` — weekly grouped Dependabot for github-actions and npm
- `.github/ISSUE_TEMPLATE/` — bug report and feature request templates plus blank-issue config
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist
- `CONTRIBUTING.md` — contributor guide
- `SECURITY.md` — vulnerability reporting policy (private disclosure via GitHub Security Advisories)
- `.markdownlint.json`, `.markdownlint-cli2.jsonc`, and `.markdownlintignore` — lint config + scope (excludes upstream-derived skill content)
- README hero band: banner image, tagline, badge row (license, version, CI, stars)
- README dual-path block: "Try it in 60 seconds" + "Why it exists" side by side
- README `## Architecture` section with Mermaid diagram and orchestrator-only design summary

### Changed

- 5 skills refactored to use `AskUserQuestion` tool for structured user input instead of text-based prompts:
  - `brainstorming` — multiple-choice clarifying questions, approach selection, section approval, spec review gate, visual companion offer
  - `finishing-a-development-branch` — branch completion options (merge/PR/keep/discard)
  - `receiving-code-review` — investigate/ask/proceed choice when can't verify a suggestion
  - `using-git-worktrees` — worktree directory selection, baseline test failure handling
  - `writing-plans` — execution handoff (subagent-driven vs inline)
- `brainstorming` and `writing-plans` spec/plan review gates now auto-open file in user's editor (`open`/`xdg-open`) before approval prompt
- `writing-plans` now has an explicit User Review Gate section (plan approval) before the execution handoff
- `using-git-worktrees` now enforces `bd worktree` commands over raw `git worktree` — added Iron Law section, command mapping table, and updated all creation/cleanup steps
- `finishing-a-development-branch` Step 5 (worktree cleanup) updated to use `bd worktree info`/`bd worktree remove`
- README restructured: hero band, badges, dual-path layout, Architecture section, trimmed project tree
- `plugin.json` description rewritten to match the GitHub repo description (single source of truth)
- `scripts/bump-version.sh` fixed: `declared_files()` was reading `.field` from `.version-bump.json` but the config uses `.key`, causing `null` keys to be written instead of updating versions
- Default branch renamed from `master` → `main`

### Deprecated

- `commands/brainstorm.md`, `commands/execute-plan.md`, `commands/write-plan.md` slash command stubs — will be removed in **v0.2.0**. Use the corresponding skills via the `Skill` tool instead.

### Moved

- `SESSION-SUMMARY.md` working file is now gitignored. The `.sessions/` directory exists for future session-summary files but is not tracked. (`SESSION-SUMMARY.md` itself was never tracked in git.)

### Security

- GitHub-side toggles enabled: Dependabot alerts, Dependabot security updates, secret scanning, push protection
- `SECURITY.md` policy added for private vulnerability disclosure

## [0.1.0] - 2026-04-06

### Added

- Claude Code plugin infrastructure (`.claude-plugin/plugin.json`, hooks, package.json)
- SessionStart hook that injects skills + runs `bd prime` (subsumes `bd setup claude`)
- Duplicate hook detection — warns if `bd setup claude` hooks are still installed
- "Beads Issue Tracking" section in `using-superpowers` bootstrap skill
- "Land the Plane" protocol as Step 6 in `finishing-a-development-branch`
- "Beads Completion" section in `verification-before-completion`
- Epic/child bead pattern in `subagent-driven-development` and `executing-plans`
- Dependency tracking via `bd dep add` in execution skills
- Context forwarding in `brainstorming` via `bd dep add --type discovered-from`
- Comprehensive documentation: README, METHODOLOGY, SETUP-GUIDE
- 9 analysis documents covering Superpowers and Beads architecture
- Test infrastructure from upstream (skill triggering, explicit requests, integration tests)
- Upstream reference docs (skills improvements feedback, document review system design)
- Marketplace configuration for Claude Code plugin discovery
- `auditing-upstream-drift` skill — 4-phase structured audit for detecting staleness and capability drift
- Test infrastructure from upstream: brainstorm server, skill triggering, explicit requests, subagent-driven-dev, claude-code helpers
- `scripts/bump-version.sh` for version drift detection across manifests
- `.gitattributes` for cross-platform line ending normalization
- `LICENSE` (MIT — required for fork attribution)
- `docs/testing.md` — adapted test methodology guide
- `docs/windows/polyglot-hooks.md` — cross-platform hook engineering reference
- `docs/upstream-reference/` — key design docs from upstream (skills improvements, document review system)

### Changed

- All 14 Superpowers skills: replaced TodoWrite with `bd` commands throughout
- `using-superpowers` flowchart: TodoWrite nodes → `bd create` nodes
- `subagent-driven-development` flowchart: TodoWrite → epic/child bead lifecycle
- `executing-plans` task loop: TodoWrite → `bd update --claim` / `bd close --reason`
- `writing-plans` header template: references beads creation for task tracking
- `brainstorming` checklist: creates session beads + child beads per step
- `writing-skills` checklist: TodoWrite → `bd create`
- Platform reference files (Gemini, Copilot, Codex): TodoWrite → `bd` CLI mappings
- `CLAUDE.md` and `AGENTS.md`: rewritten for plugin context

### Removed

- All active TodoWrite references (2 prohibition references retained: "Do NOT use TodoWrite")
- Upstream community management files (CODE_OF_CONDUCT, issue templates, funding)
- Platform-specific files for Cursor, Codex, OpenCode, Gemini (Claude Code only)

### Attribution

- Superpowers skills: [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent (MIT)
- Beads issue tracker: [gastownhall/beads](https://github.com/gastownhall/beads) by Steve Yegge (MIT)
