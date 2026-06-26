# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

> **Forked from:** [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 (2026-03-31)
> **Beads integration based on:** [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.4 (2026-05-09)

## [Unreleased]

### Changed

- **Stress-test is now offered at every approval gate.** The `brainstorming` spec-review and `writing-plans` plan-review gates include an "Approved + stress-test" option (listed first, recommended), so the optional adversarial design review is surfaced every time — not only when a design was judged "complex." Choose it to run `stress-test` on the spec or plan before continuing; plain "Approved" skips it. (ADR-0020)
- **`research-driven-development` now decomposes, verifies, and right-sizes its research.** Instead of handing the raw topic to a fixed pair of agents, it breaks the topic into sub-questions and dispatches one researcher each (each with an objective, output format, sources, and boundaries), scales the agent count to the question (a hard cap of 5), verifies every load-bearing claim against a verbatim source quote, tags each finding's confidence, and runs one capped gap-closing round when a claim rests on a single source. Grounded in a study of the most-adopted deep-research systems. (ADR-0021)

## [0.7.1] - 2026-06-26

### Changed

- **Installation reframed around native per-CLI plugin install.** Native plugin install is now the primary, recommended path in the README and docs; `curl | bash` is documented as a scoped "scripted / advanced install" fallback (its unique roles: beads/Dolt bootstrap, hook registration for the npx/scripted path, optional `yegge.md` agent, version pinning via `--version`, and CI). The curl installer remains fully functional — behavior unchanged, only its framing. (ADR-0015)
- **Tiered platform support.** README and `docs/getting-started.md` now present a two-tier Supported Platforms table: **Verified** (Claude Code, Codex, OpenCode — install-tested) and **Best-effort / community** (Cursor, Gemini CLI, GitHub Copilot CLI), each Best-effort row stamped "community-verified, not tested by us — last reviewed 2026-06"; the long tail delegates to `npx skills add` + upstream's install list. (ADR-0016)
- **README restructured** to the upstream section order: Quickstart → How it works → Prerequisites → Installation → What's Inside (skills grouped by category) → Updating, with a prominent prerequisite note that native install does not bootstrap the beads/Dolt database (`brew install beads` → install plugin → `bd init`).
- `docs/index.md` now reflects the Verified/Best-effort tiers and links to Getting Started for per-platform install paths.
- **Full public-documentation audit + prose pass.** Every human-facing surface (README, all six docs-site pages, CONTRIBUTING, the example-workflow README) was run through the `write-documentation` checks for clarity and register, preserving all facts, install commands, and MkDocs macros. Stale references were corrected (CI release skill-count floor 15 → 22, PR-template count 20 → 22, `SECURITY.md` supported versions 0.6.x → 0.7.x, root `CLAUDE.md` version + cache paths 0.7.0 → 0.7.1), and the GitHub repository description and topics were refreshed.

### Added

- **`auditing-upstream-drift`:** registered CLI-only beads integration (direct `bd` CLI + one SessionStart `bd prime` hook; no beads Claude plugin or `beads-mcp` server) as a Known Deliberate Divergence. (ADR-0017)
- **`hooks/session-start`:** emits a one-line hint when `bd` is absent, and a non-fatal collision warning when obra/superpowers is detected alongside this plugin (skill names collide). Covered by a new CI-wired test `tests/hooks/test-session-start-warnings.sh`.

## [0.7.0] - 2026-06-25

### Added

- "Known Deliberate Divergences" registry in `auditing-upstream-drift` — a table of the shared skills that intentionally differ from upstream (beads-as-ledger across all skills, the `bd worktree` Iron Law, Land the Plane, the SDD beads ledger, and the multi-CLI `references/` approach), plus a pointer from the Phase 5 drift check. A future audit now marks these as a deliberate SKIP instead of re-flagging them as drift to revert.
- DCI-injected `$VISUAL`/`$EDITOR` preference in `brainstorming` and `writing-plans` User Review Gates — injects the user's preferred editor at skill load time via `!`echo ${VISUAL:-${EDITOR:-not-configured}}``; fallback chain: `$VISUAL` → `$EDITOR` → `open` (macOS) → `xdg-open` (Linux).
- `bd lint` deterministic checks in `writing-plans` self-review — runs `bd lint` on epic and all child tasks, plus `bd ready --explain` for dependency ordering, before manual judgment checks.
- Global Constraints, Interfaces, and Task Right-Sizing blocks in `writing-plans` (from upstream superpowers v6.0.3) — plans now carry a Global Constraints section (project-wide rules copied verbatim into the header so they reach isolated implementers and reviewers), each task gets a Consumes/Produces Interfaces block (exact neighbor signatures for context-isolated implementers), and a Task Right-Sizing definition draws task boundaries at the smallest unit worth its own test cycle and reviewer gate.
- "Match the Form to the Failure" and "Micro-Test Wording" sections in `writing-skills` (from upstream superpowers v6.0.3) — a table for choosing the right guidance form (prohibition, recipe, structural, or conditional) by the baseline failure it must fix, and a cheap per-iteration wording check against a no-guidance control before committing to expensive full pressure scenarios.
- `bd query` and `bd count` (beads v1.0.5) adopted across `getting-up-to-speed`, the `using-superpowers` quick reference, and the `CLAUDE.md` command table — `bd query` is a compound query language (`status=open AND priority<=1`, boolean operators, date-relative expressions, wildcards) that replaces `bd list` piped through `jq`, and `bd count --by-status`/`--by-priority`/`--by-type` returns grouped counts that feed the orientation state summary.
- `bd merge-slot` (beads v1.0.5) documented as an optional concurrent-orchestrator guard in `subagent-driven-development` parallel batch mode and `dispatching-parallel-agents` — the single orchestrator already serializes merges, so the slot is only needed when two or more orchestrators or sessions run against the same repo at once; `bd merge-slot acquire`/`release` then serialize their merges so conflicts are resolved one at a time.
- Structured blocker types in `executing-plans` — three-type taxonomy (`bd defer` for time-based, `bd create` + `bd dep add` for missing work, `bd human` for human decisions) replaces undifferentiated "STOP when blocked."
- Description quality gate in `executing-plans` — check task description before claiming; bare titles with no context are flagged.
- Richer `bd create` flags in `executing-plans` — documents `--body-file`, `--acceptance`, `--design-file`, `--notes`, and `--silent` for programmatic bead creation.
- Claim-before-worktree ordering in `using-git-worktrees` — claim the bead before creating the worktree to prevent ownerless work.
- "If Verification Cannot Run" section in `verification-before-completion` — handles edge cases where no verification command exists (no test suite, CI down, external dependency unavailable).
- Skill override acknowledgment in `using-superpowers` — name the skipped skill and acknowledge the override when user asks to bypass.
- `bd swarm validate` pre-step in `subagent-driven-development` parallel batch mode — analyzes the work graph for wave structure, max parallelism, and dependency warnings before dispatching subagents.
- Structured `AskUserQuestion` interaction in `stress-test` — replaces plain-text "Do you agree?" with Agree / Disagree / Discuss further options per branch. Includes branch tracking status lines and re-ask confirmation gates after disagreement iteration.
- Mode A/B findings output in `stress-test` — Mode A edits the source artifact inline (specs, plans in `.internal/`); Mode B writes a standalone report to `.internal/stress-tests/`. `AskUserQuestion` disambiguates when target is unclear.
- Reflexion self-review (Phase 4.5) in `stress-test` — internal self-critique pass after documenting findings. Checks coverage, depth, and missed angles; loops back to interrogation if gaps found. Capped at one pass to prevent infinite recursion.
- DCI-injected `$VISUAL`/`$EDITOR` preference in `stress-test` Mode B — same fallback chain as `brainstorming` and `writing-plans`.
- Phase 1 restore point in `stress-test` — commits or stashes the target artifact before inline edits begin, preserving a clean rollback point.
- Docs-site SEO: links shared from [dollardill.github.io/beads-superpowers](https://dollardill.github.io/beads-superpowers/) now render rich previews. The MkDocs social plugin generates Open Graph and Twitter card images, every page carries a meta description, and the site ships a `robots.txt` plus Google Search Console verification. (The Search Console verification file removed in 0.5.0 returns as part of that setup.)

### Changed

- `brainstorming` visual companion: adopted upstream superpowers v6.0.3's auth-hardened server. Every HTTP and WebSocket request now requires a per-session key (via `?key=` or an `HttpOnly; SameSite=Strict` cookie, constant-time compared); WebSocket upgrades also enforce an Origin check (anti-DNS-rebinding); the `/files/` server rejects symlinks, dotfiles, and path traversal; responses carry `X-Frame-Options: DENY` and `Content-Security-Policy: frame-ancestors 'none'`; `stop-server.sh` verifies process ownership; idle timeout raised 30 min → 4 h. Rebranded the companion wordmark to `beads-superpowers` (text-only) and removed the third-party `primeradiant.com` logo fetch. Test suite made auth-aware and expanded (`server.test.js`, `auth.test.js`, `ws-protocol.test.js`, `windows-lifecycle.test.sh`).
- `brainstorming` now offers the visual companion just-in-time instead of upfront (upstream superpowers v6.0.3) — it is no longer offered preemptively when a visual topic is anticipated; it's offered the first time a specific question would genuinely be clearer shown than told, and never offered if no visual question arises. The process-flow diagram drops the upfront "Visual questions ahead?" gate accordingly.
- `subagent-driven-development` adopted upstream superpowers v6.0.3's review model (selectively — see ADR-0013). The two sequential reviewer prompts (`spec-reviewer-prompt.md` + `code-quality-reviewer-prompt.md`) are replaced by one read-only `task-reviewer-prompt.md` that returns a spec-compliance verdict (✅/❌/⚠️) and a code-quality verdict in a single pass. Added three pure-bash file-handoff scripts (`sdd-workspace`, `task-brief`, `review-package`) that pass task briefs, implementer reports, and review diffs as files under a per-worktree `.superpowers/sdd/` directory; a Pre-Flight Plan Review; a mandatory model-per-dispatch rule; a banned-coaching Red Flag; and a "cannot-verify-from-diff" handling section. Beads remains the durable ledger (the upstream markdown progress ledger was deliberately not adopted), and the Parallel Batch Mode (one `bd worktree` per task) is preserved.
- Skill vocabulary made vendor-neutral and the discovery concept renamed (from upstream superpowers v6.0.3) — "Claude Search Optimization (CSO)" is now "Skill Discovery Optimization (SDO)" across `writing-skills`, `docs/methodology.md`, `docs/skills.md`, and `CLAUDE.md`, and the generic-stand-in "Claude" prose in `writing-skills` and `docs/methodology.md` now reads as "agent"/"your agent" so the guidance fits any harness. Factual Claude Code platform references (built-in agent names, the `EnterWorktree` tool) are kept verbatim, the `writing-skills` SDO worked example restores "two-stage review process" so it stays internally consistent, and the `using-superpowers` Platform Adaptation note now lists all four reference tool-maps shipped (`codex`, `copilot`, `gemini`, `opencode`). The vendored `anthropic-best-practices.md` is left unchanged as cited Anthropic source material; baseline version bumps are deferred.
- `finishing-a-development-branch` PR/MR step is now forge-aware instead of GitHub-only — the "Create a Pull Request" option detects the forge from the `origin` remote and runs `gh pr create` for GitHub, `glab mr create` for GitLab, or prints an actionable "open via your forge's web UI" message otherwise (the PR body template is preserved). Worktree detection in `finishing-a-development-branch` and `using-git-worktrees` now canonicalizes git paths with `pwd -P`, so it classifies correctly when run from a subdirectory. These are selective cherry-picks from upstream superpowers v6.0.3; the `bd worktree` Iron Law and the Land-the-Plane session-close ritual are deliberately retained, and upstream's native-tool-first worktree selection (which would bypass beads-database sharing across worktrees) is **not** adopted — `using-git-worktrees` carries a note recording the divergence (see ADR-0014).
- Documented upstream baselines bumped to reflect the completed adoption — `obra/superpowers` v5.1.0 → **v6.0.3** and `gastownhall/beads` v1.0.4 → **v1.0.5** across the `CLAUDE.md` Upstream Sources table and Project Overview, the `docs/methodology.md` and `docs/tips.md` source lists, and the `auditing-upstream-drift` skill's baseline so future drift is measured from v6.0.3/v1.0.5. Historical and since-version references are intentionally preserved (the CHANGELOG fork/provenance lines, the `export.git-add` "v1.0.4+" gotcha, and `bd init --force` "deprecated in v1.0.4" notes all record when a behavior changed and stay as-is).
- Public identity metadata aligned with the multi-CLI reality — the `.claude-plugin` and `.codex-plugin` marketplace descriptions now read "Plugin for Claude Code, Codex, and OpenCode" instead of "Claude Code plugin", and `CODE_OF_CONDUCT.md` routes enforcement reports to the current maintainer's GitHub contact rather than the upstream author's email.

### Removed

- `bd preflight` references from `CLAUDE.md`, `finishing-a-development-branch`, `using-superpowers`, and `docs/tips.md` — command outputs beads-project-specific Go instructions, not applicable to this project.

### Fixed

- `subagent-driven-development`: completed the file-handoff adoption that v6.0.3 introduced. The skill had contradicted itself — the "File Handoffs" section said to hand the implementer a task brief *file*, while `implementer-prompt.md` and an "Efficiency gains" bullet still said to paste the full task text and "don't make subagent read file." Both are now reconciled to the file-based model: the implementer reads its task brief at `[BRIEF_FILE]` (written by `scripts/task-brief`), matching upstream.
- `claude-code` skill tests: the SDD fast test never reached clean completion. The cause was brittle assertions, not latency — `assert_contains` matched model prose case-sensitively (so "Do Not Trust" missed `not trust` and "skepticism" missed `skeptical`). Made `assert_contains` case-insensitive, broadened the reviewer-mindset assertions to the vocabulary the model actually uses (skeptic/distrust/unverified/adversarial; code/diff/ground truth), and updated the task-handoff test to the brief-file model. The suite now runs green end-to-end (verified across two consecutive full runs); the nine sequential model calls need a generous outer timeout (≥600 s).
- `auditing-upstream-drift`: corrected the skill's own stale self-checks — the skill-count check expected 15 skills (now 22), the version-consistency check covered 3 manifests (now all 6, including the Codex and OpenCode manifests), and Check 3.1 no longer false-fails on the `getting-up-to-speed` "TodoWrite is forbidden" prohibition line.
- `systematic-debugging` no longer silently switches Claude Code into extended-thinking mode every time it loads. The skill contained the literal token `Ultrathink`, which Claude Code scans for to enable extended thinking; hyphenating it to `Ultra-think` (matching upstream superpowers v6.0.3) keeps the word in the prose without tripping the trigger.

## [0.6.0] - 2026-06-03

### Added

- E2E container test for `install.sh` — Docker-based test runs install/re-install/uninstall in a clean debian:12-slim container with 48 assertions across 7 test groups. Entry point: `./tests/installer/run-tests.sh`.
- `BEADS_SUPERPOWERS_TARBALL_URL` env var in `install.sh` — overrides the GitHub tarball download URL for local testing.
- ADR-0004: E2E Container Testing for install.sh.
- Dynamic per-page "last updated" dates via `mkdocs-git-revision-date-localized-plugin` — dates sourced from git commit history, no hardcoding.
- Material theme footer restored — copyright, social links, and prev/next page navigation. The 0-byte `footer.html` override that suppressed the footer was removed.
- `mkdocs-panzoom-plugin` for Mermaid diagrams — Alt+scroll to zoom, Alt+drag to pan, fullscreen toggle. Replaces the custom panzoom implementation lost in the v0.5.2 MkDocs migration.
- Critical Rule #8 in `yegge.md`: always use `AskUserQuestion` for design choices with 2+ options — never present options as plain text.
- **Codex CLI plugin support** — `.codex-plugin/plugin.json` and `marketplace.json` mirror the Claude Code plugin manifest. `hooks/codex-hooks.json` references the same hook scripts via `${CODEX_PLUGIN_ROOT}`. Skills auto-discovered from plugin bundle.
- **OpenCode native TypeScript plugin** — `opencode/beads-superpowers-plugin.ts` provides 3 in-process hooks: session start (bd prime + skill injection), prompt reminders, and compaction resilience. Distributed via `install.sh`.
- **OpenCode tool mapping reference** — `skills/using-superpowers/references/opencode-tools.md` maps Claude Code tool names to OpenCode equivalents (subagent dispatch, environment detection).
- ADR-0007: Multi-CLI Plugin Architecture (Codex + OpenCode).
- E2E tests for multi-CLI install/uninstall and hook format validation (6 scenarios: CC/Codex/generic × session-start/reminder).
- **3-tier fallback chain** in `install.sh` — tries plugin system (Claude Code/Codex marketplace) first, then `npx skills add`, then tarball download, then git clone. Each tier cleans up on failure before trying the next.
- **SHA-256 checksum validation** for tarball downloads — 3-tool fallback (`sha256sum` → `shasum` → `openssl`), on by default, `--skip-checksum` to bypass. `checksums.txt` published as a GitHub Release asset.
- **Atomic rollback** via staging directory — skills install to a temp dir first, only move to final location on complete success. No partial installs on failure.
- `BEADS_SUPERPOWERS_CHECKSUMS_URL` env var in `install.sh` — overrides the checksums.txt download URL for local testing.
- ADR-0008: Installer Hardening — 3-Tier Fallback Chain with Checksums and Atomic Rollback.
- E2E tests for checksum validation (valid/corrupted/missing/skip), fallback chain (PATH stub-based tool hiding), atomic rollback (read-only target dir), and `bd` integration (hook JSON with bd in PATH).
- Claude Code CLI, `bd`, and `wget` added to E2E Docker test container.
- GitHub Action step in release workflow to generate and upload `checksums.txt` alongside release tarballs.
- **Upstream drift audit** — obra/superpowers v5.0.7→v5.1.0 and gastownhall/beads v1.0.2→v1.0.4. ADR-0009, ADR-0010.
- Pre-flight checks in `using-git-worktrees` — environment detection (already in worktree?), submodule guard, conditional consent flow (manual=ask, SDD=skip), `EnterWorktree` note for non-beads contexts. `bd worktree` remains Iron Law.
- Environment detection in `finishing-a-development-branch` — detects normal repo / named-branch worktree / detached HEAD. Detached HEAD gets reduced 3-option menu (no merge). Provenance-based worktree cleanup only removes `.worktrees/` paths.
- Security-bug reviewer test (`tests/claude-code/test-requesting-code-review.sh`) — plants SQL injection, plaintext passwords, and credential logging bugs, verifies the reviewer catches them.
- `bd batch` atomic operations documented in `subagent-driven-development`, `executing-plans`, and `finishing-a-development-branch` for atomic close/dep/create transactions.
- `bd -C <path>` documented in `using-git-worktrees` and `subagent-driven-development` for cross-worktree commands without cd.
- `bd ready --explain` added to `systematic-debugging` (Phase 1 evidence gathering) and `executing-plans` (task selection) for dependency reasoning.

### Changed

- `install.sh`: refactored from monolithic `do_install` to 4 tier functions (`try_plugin_install`, `try_npx_install`, `try_tarball_install`, `try_git_install`) with a cascade orchestrator.
- `install.sh`: prerequisites are now lazy — each tier checks its own deps instead of a global hard-fail at startup. `python3` only required for Tiers 2/3 (settings.json registration).
- `install.sh`: version file now stores `version:tier` format (e.g., `0.5.3:tarball`). Tier-aware uninstall reads the tier and cleans up the right paths. Auto-uninstalls the previous tier on tier-switch reinstall.
- `install.sh`: `--version X.Y.Z` now forces Tier 3 (tarball) since plugin/npx can't pin versions.
- `install.sh`: `resolve_version` uses `grep`+`sed` instead of `python3` for GitHub API JSON parsing.

- `brainstorming`: optional stress-test step between spec approval and writing-plans — offers adversarial review when design is complex or high-risk
- `brainstorming`: added `## Integration` section documenting skill relationships
- `brainstorming` + `writing-plans`: standalone `open` call warning in User Review Gate — prevents hang when chained after `bd` commands
- S9 renamed `DOCUMENT_RELEASE` → `DOCUMENT` — now conditionally invokes `write-documentation` when `document-release` flags major prose rewrites.
- S11 renamed `LAND_PLANE` → `SESSION_CLOSE` — fires only on non-branch paths (research queries). Branch paths terminate at S10, which includes Land the Plane as Step 6 of `finishing-a-development-branch`.
- All 8 Mermaid diagrams across docs site audited for content accuracy and updated with increased `nodeSpacing`/`rankSpacing` (70) for readability.
- Docs site content audit: 3 pages updated (methodology, workflow, getting-started), 3 verified accurate (index, skills, tips).
- `hooks/session-start`: added `CODEX_PLUGIN_ROOT` detection — Codex gets the same `hookSpecificOutput` format as Claude Code. Removed stale `COPILOT_CLI` guard.
- `hooks/superpowers-reminder.sh`: rewritten with multi-format output (Cursor/Claude Code+Codex/generic) instead of hardcoded Claude Code JSON.
- `install.sh`: auto-detects Codex CLI and OpenCode, installs skills to `~/.codex/skills/` and `~/.config/opencode/skills/` respectively. OpenCode plugin copied to `~/.config/opencode/plugins/`.
- Version sync expanded from 3 to 6 files — added `.codex-plugin/plugin.json`, `.codex-plugin/marketplace.json`, `opencode/package.json` to `.version-bump.json`.
- `requesting-code-review`: consolidated to template-only dispatch. `agents/code-reviewer.md` deleted (matching upstream v5.1.0). Skills now dispatch `Task (general-purpose)` with template from `skills/requesting-code-review/code-reviewer.md`.
- `code-quality-reviewer-prompt.md`: dispatch changed from `superpowers:code-reviewer` to `Task (general-purpose)` with template.
- `project-init`: `bd init --force` references updated for v1.0.4 deprecation — recovery paths now recommend `--reinit-local` or `--discard-remote`.
- Upstream baseline versions updated: superpowers v5.0.7→v5.1.0, beads v1.0.2→v1.0.4 across all documentation files.
- Cross-CLI tool mapping references (codex-tools.md, opencode-tools.md, copilot-tools.md) updated from named agent dispatch to template-based dispatch.

### Fixed

- `agent_count` unbound variable in `install.sh` `--test` mode — variable was local to `do_install()` but referenced in `print_next_steps()`.
- Hardcoded "21 invocable skills" in getting-started.md → `{{ invocable_count }}` template variable.
- Review gate diagram in workflow.md: "Merge to main" → "Merge to epic branch" (tasks merge into epic worktree, not main).
- `decisions/` was tracked in git despite being gitignored — untracked all files, fixed stale CLAUDE.md references.
- `{PLAN_REFERENCE}` → `{PLAN_OR_REQUIREMENTS}` placeholder inconsistency in `skills/requesting-code-review/code-reviewer.md`.
- `export.git-add` gotcha in CLAUDE.md now version-aware — notes v1.0.4+ changed default to opt-in.
- `auditing-upstream-drift` beads baseline was v1.0.0 (should have been v1.0.2) — corrected to v1.0.4.

## [0.5.3] - 2026-05-03

### Added

- `bd remember` prompts in 17 of 22 skills — agents are now prompted to capture persistent learnings at each skill's natural completion point. Hybrid approach: mandatory capture in 3 high-signal skills (`systematic-debugging`, `receiving-code-review`, `brainstorming`), conditional in 13 others, stale memory cleanup in `getting-up-to-speed`. Prefix conventions match the orchestrator's pattern (`root cause:`, `lesson:`, `design:`, `review:`, etc).
- Integration cross-references across skills — standardized `## Integration` sections documenting skill-to-skill relationships.

### Fixed

- Removed 13 `.internal/` files that were tracked in git despite being gitignored — this caused the v0.5.2 release workflow to fail (259 markdownlint errors on internal plan/spec files).
- Fixed Integration cross-references and simplified worktree directory selection.
- Pre-commit hooks, docs site enhancements, gitignore cleanup, lint fixes.
- Stale version references (0.5.1/0.5.2 → 0.5.3) across documentation.

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
