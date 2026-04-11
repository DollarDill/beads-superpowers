# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

> **Forked from:** [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 (2026-03-31)
> **Beads integration based on:** [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.0 (2026-04-03)

## [Unreleased]

(none yet)

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
