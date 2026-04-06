# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

> **Forked from:** [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 (2026-03-31)
> **Beads integration based on:** [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.0 (2026-04-03)

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
