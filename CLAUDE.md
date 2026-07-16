# beads-superpowers — Claude Code Plugin

Behavioral guidelines to reduce common LLM coding mistakes, plus project-specific instructions.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```text
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Project Overview

A plugin for Claude Code, Codex, and OpenCode (verified) plus 6 best-effort harnesses — Cursor, GitHub Copilot CLI, Kimi Code, Antigravity, Factory Droid, and Pi — that merges [Superpowers](https://github.com/obra/superpowers) skills (v6.1.1) with [Beads](https://github.com/gastownhall/beads) issue tracking (v1.1.0). It gives AI coding agents composable process-discipline skills (TDD, brainstorming, systematic debugging, code review, verification) plus persistent task memory via a Dolt-backed database.

**Repository:** <https://github.com/DollarDill/beads-superpowers>
**Version:** 0.13.0
**License:** MIT (fork of obra/superpowers, also MIT)

## Architecture

- `.claude-plugin/` — Claude Code plugin manifest (`plugin.json`) and marketplace config (`marketplace.json`). Auto-discovered by Claude Code.
- `.codex-plugin/` — Codex CLI plugin manifest (`plugin.json`) and marketplace config (`marketplace.json`). Mirrors `.claude-plugin/` for Codex compatibility. The repo-root `.agents/plugins/marketplace.json` (version-less) is the Codex marketplace source manifest — without it, Codex marketplace sources find zero installable plugins.
- `skills/` — one skill per `skills/<name>/SKILL.md` directory. Some include prompt templates (`implementer-prompt.md`, `researcher-prompt.md`) or helper scripts. Auto-discovered by Claude Code — do NOT declare in `plugin.json`.
- `agents/` — Removed in v0.6.0. Code-reviewer is now dispatched via `skills/requesting-code-review/code-reviewer.md` prompt template. Subagents (implementer, researcher) use prompt templates inside their skills, not standalone agent files.
- `hooks/` — `session-start` (SessionStart: injects `using-superpowers` + composed beads context — curated memories + a `bd prime` pointer), the single recurring hook. Multi-format output supports Claude Code, Codex, Cursor, and generic CLIs. Registered in `hooks/hooks.json` (Claude Code) and `hooks/codex-hooks.json` (Codex). Auto-discovered.
- `.opencode/` — OpenCode plugin (`plugins/beads-superpowers.js`, upstream-parity base + beads graft) + `INSTALL.md`. Git-install only via the opencode.json plugin spec; `install.sh` no longer copies OpenCode artifacts (its `--uninstall` still cleans pre-0.12 copies).
- `example-workflow/` — Ready-to-use project template: `CLAUDE.md` (Karpathy behavioral principles + beads integration) and `agents/yegge.md` (lean router — triages requests and routes to skills). `install.sh --with-yegge` installs `yegge.md` globally (opt-in; not installed by default).
- `docs/` — Docs content only (6 EN + 6 ZH pages + assets): source of truth for the site's prose. The site itself is built and published from the private the-factory-website repo (`tenants/beads-superpowers/`), not from this repo (ADR-0050).
- `docs/decisions/` — Architecture Decision Records (ADRs). Local working docs (gitignored).
- `.internal/` — Working docs (gitignored): specs from brainstorming, plans from writing-plans, research output, audits, reference docs, `.internal/sdd/` (SDD scratch), and `.internal/brainstorm/` (brainstorm server sessions).
- `tests/` — deterministic suites (hooks, manifests, skills contracts, install-shape, installer Docker E2E, brainstorm-server Node tests) run via the `just` surface; the LLM-driven suites (claude-code, explicit-skill-requests, skill-triggering, subagent-driven-dev) are deprecated in place — see `tests/*/DEPRECATED.md`.
- `scripts/` — `bump-version.sh` (sync version across 7 files), `check-skill-count.sh` (guard: forbid hardcoded skill counts + structural self-consistency), `check-agent-bead-stamp.sh`, `check-zh-docs.sh`, `check-convention-sync.sh` (verify shared convention blocks are byte-identical across skills), `lint-shell.sh` (shellcheck gate over tracked `.sh` with committed baseline; visible SKIP when shellcheck absent), `check-askuser-genericization.sh` (guard: skills use generic question-tool phrasing — ADR-0041).
- `install.sh` — curl installer with 3-tier fallback chain (plugin system → npx → tarball/git clone). SHA-256 checksum validation, atomic rollback via staging directory, lazy prerequisites. Auto-detects Claude Code, Codex, OpenCode, and 6 more CLIs (Cursor, Copilot, Droid, Antigravity, Kimi, Pi).

## Key Design Decisions

- **Skills are pure Markdown** — No executable code in skills. Claude Code auto-discovers `skills/*/SKILL.md`. Platform-agnostic by design. (See: upstream superpowers architecture)
- **Prompt templates over standalone agent files** — Subagent prompts (`implementer-prompt.md`, `researcher-prompt.md`) live inside their skills. Only the orchestrator (`yegge.md`) is a standalone agent file. Prevents drift between skill and dispatch instructions. (See: ADR-0003)
- **`bd` replaces TodoWrite everywhere** — Every `TodoWrite` reference in upstream superpowers replaced with `bd` commands. Beads provides persistent cross-session memory that TodoWrite lacks.
- **Three-layer architecture for example workflow** — `CLAUDE.md` (behavioral principles + project context) + `agents/yegge.md` (orchestration — triage + skill routing) + prompt templates (subagent dispatch). Each layer has a distinct responsibility. (See: ADR-0003, ADR-0032)
- **MkDocs Material for docs site** — HashiCorp/Terraform-style sidebar, dark theme, Mermaid diagrams. Template variables via macros plugin avoid hardcoded counts; the config and macros now live in the-factory-website repo, not here. (See: ADR-0001, ADR-0050)
- **Per-task worktree isolation for parallel SDD** — Independent plan tasks execute in parallel (max 5), each in its own `bd worktree`. Prevents merge conflicts between concurrent subagents. (See: ADR-0002)

## Common Gotchas

- **Embedded Dolt mode** — `.beads/metadata.json` `dolt_mode: embedded` runs the Dolt engine **in-process** (no separate sql-server). This does NOT disable sync: `bd dolt status/show/push/pull` all work. The remote is the dedicated private repo `DollarDill/beads-superpowers-beads` (slug only — content is auth-gated), decoupled from this public code repo (ADR-0057); the code repo itself carries **zero** dolt refs — any reappearing is a regression (`bash skills/project-init/scripts/diagnose.sh` flags it). New-machine bootstrap: clone this repo, then `bd init --non-interactive --prefix beads-superpowers --remote "git+ssh://git@github.com/DollarDill/beads-superpowers-beads.git"` — hydrates the full DB from the private remote. Genuine push failures are setup-specific (diverged history, GitHub push-protection if a token is in Dolt history) — see the `project-init` skill, not a blanket "embedded fails".
- **Zero-remote `bd dolt push` silently adopts git origin (bd v1.1.0)** — with NO Dolt remote configured, `bd dolt push` does not error; it silently pushes the beads DB to the git origin instead (a real, reproduced ADR-0057 incident). Always chain remote swaps in one command — `bd dolt remote remove origin && bd dolt remote add origin <url>` — never leave the remote empty between the two.
- **Remote swaps: collision guard + stale `sync.remote`** — bd releases after v1.1.0 refuse `bd dolt remote add` with a URL matching git origin unless `--allow-git-origin` is passed (upstream PR #4153, merged post-v1.1.0-tag); don't fight this for a deliberate same-repo setup, pass the flag. Separately, `bd dolt remote remove` can leave `sync.remote` stale or commented out in `.beads/config.yaml` — verify it after any swap and repair with `bd config set sync.remote <url>` if it's wrong.
- **Reference-class knowledge lives in beads, not `bd memories`** — the `memory-curator` taxonomy makes `@type` the routing decision: `research`/`design`/`decision` notes (pointers to docs/ADRs) become **deferred knowledge-beads** (`status=deferred`, far-future `defer_until`, GC-safe, hidden from `bd ready`) tagged with the `kb` label + 1–3 topic labels, while `lesson`/`pattern`/`root-cause`/`correction` stay injected memories. Retrieve by topic with `bd list --label <topic> --status all` or by keyword with `bd search "<keyword>" --status all`; retire stale entries with `bd supersede <old> --with <new>`. `bd memories <keyword>` only covers injected memories.
- **`export.git-add` pollutes branches (v1.0.2 and earlier)** — In beads v1.0.2 and earlier, `export.git-add` defaulted to `true`, auto-staging `issues.jsonl` on every commit. Workaround: `bd config set export.git-add false` before branch work. In **v1.0.4+**, auto-export is opt-in by default — no workaround needed. Check with `bd config show`.
- **DCI only works in SKILL.md** — The `!` backtick syntax (Dynamic Context Injection) only works in `SKILL.md` and `.claude/commands/*.md`. NOT in agent `.md` files, `CLAUDE.md`, or rules files.
- **Never run `npx skills add` from inside this repo** — It replaces real skill files in `skills/` with symlinks to `.agents/skills/`, destroying the source. Use `-g` flag from `/tmp` or another directory.
- **Never chain `open` after `bd` commands** — `open <file>` hangs when chained in the same Bash invocation with `bd` commands. Always run `open` as a standalone call.
- **Worktree path default** — `bd worktree create <name>` creates at `./<name>` (sibling to repo files), NOT `.worktrees/<name>`. Pass the full path: `bd worktree create .worktrees/<name>`.
- **Worktree detection** — Use `git rev-parse --is-inside-work-tree`, NOT `[ -d .git ]`. In a worktree, `.git` is a file, not a directory.
- **Plugin cache goes stale** — After modifying skills, the installed plugin cache is outdated. Symlink the cache to this repo (see "Syncing Source" section below). `claude plugin update` has a [cache bug](https://github.com/anthropics/claude-code/issues/14061).
- **Skill `description` field trap** — Putting workflow descriptions in skill `description` frontmatter causes Claude to follow the description instead of reading the full skill body (SDO problem). Descriptions should state trigger conditions only.
- **Codex plugin channel doesn't register hooks** — codex-cli (verified 0.142.5) rejects a populated `hooks` object in the plugin manifest ("ignoring hooks: … found object") and auto-discovers nothing usable, so plugin/marketplace installs get skills but NO SessionStart hook. `install.sh` wires the hook explicitly — it is the supported Codex hook path.
- **`gh-pages` is a frozen SEO redirect bridge (ADR-0050)** — 1:1 instant-meta-refresh stubs → algocents.com, live until the sunset-gate bead (≥ 2027-07) closes. NEVER delete the branch, disable GitHub Pages, or "clean up" the stale-looking branch. Verify anytime: `bash scripts/verify-ghpages-stubs.sh live`.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging:

```bash
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

## Plugin Structure

```text
.agents/plugins/
  marketplace.json         # Codex marketplace source manifest (version-less by design)
.claude-plugin/
  plugin.json              # Claude Code plugin manifest (auto-discovered)
  marketplace.json         # Claude Code marketplace config
.codex-plugin/
  plugin.json              # Codex CLI plugin manifest (mirrors .claude-plugin/)
  marketplace.json         # Codex CLI marketplace config
.opencode/
  plugins/beads-superpowers.js  # OpenCode plugin (upstream-parity base + beads graft)
  INSTALL.md               # Version pinning, migration, troubleshooting
agents/                    # Removed in v0.6.0 (code-reviewer consolidated to skill template)
assets/                    # Banner SVG
docs/                      # Docs content only — built/published by the-factory-website (ADR-0050)
  index.md, getting-started.md, methodology.md, skills.md, workflow.md, tips.md
  index.zh.md, getting-started.zh.md, methodology.zh.md, skills.zh.md, workflow.zh.md, tips.zh.md
  assets/                  # Banner SVG
docs/decisions/            # Architecture Decision Records (gitignored, local-only)
.internal/                 # Working docs (gitignored)
  specs/                   # Design specs from brainstorming
  plans/                   # Implementation plans from writing-plans
  research/                # Research output from research-driven-development
  audits/                  # Upstream drift audit reports
  reference/               # Upstream design docs
  sdd/                     # SDD scratch — briefs, reports, diffs
  brainstorm/              # Brainstorm server sessions
  windows/                 # Windows polyglot hook docs
  SETUP-GUIDE.md           # Installation and setup guide
  testing.md               # Test infrastructure docs
example-workflow/
  CLAUDE.md                # Karpathy behavioral principles + beads integration (generic project template)
  agents/yegge.md          # Orchestrator agent — lean router (triage + skill routing)
hooks/
  hooks.json               # Claude Code hook registration
  codex-hooks.json         # Codex CLI hook registration (refs same scripts)
  session-start            # Bash: injects using-superpowers + composed beads context (multi-format output)
  run-hook.cmd             # Windows polyglot wrapper
scripts/
  bump-version.sh          # Sync version across package.json + plugin manifests
  check-skill-count.sh     # Guard: forbid hardcoded skill counts + structural self-consistency
  check-agent-bead-stamp.sh  # Verify agent-filed bead discipline convention
  check-zh-docs.sh           # Verify zh docs structure/term parity
  check-convention-sync.sh   # Verify shared convention blocks are byte-identical across skills
  lint-shell.sh              # Shellcheck gate over tracked .sh (baseline + visible-SKIP)
  lint-shell-baseline.txt    # Committed lint baseline (empty at adoption — repo is clean)
  check-askuser-genericization.sh  # Guard: literal AskUserQuestion only under using-superpowers/references/ (ADR-0041)
  generate-ghpages-stubs.sh        # ADR-0050: regenerate gh-pages redirect stubs from ghpages-stub-titles.tsv
  ghpages-stub-titles.tsv          # Stub slug→title map (input to the generator)
  verify-ghpages-stubs.sh          # Battery: verify the gh-pages redirect bridge (worktree or `live` mode)
skills/                    # beads-native skills (auto-discovered, each has SKILL.md;
                           #   branch-only reference files in per-skill references/ subdirs)
.claude/skills/            # maintainer-only skills (git-tracked, NOT distributed — ADR-0044)
tests/                     # Test infrastructure (deterministic suites via `just`; 4 LLM suites deprecated in place)
install.sh                 # curl installer — 3-tier fallback (plugin → npx → tarball/git), checksums, atomic rollback
```

**Important:** Claude Code auto-discovers `skills/`, `agents/`, and `hooks/` directories by convention. Do NOT declare these paths in `plugin.json` — it causes validation failures.

## Beads Integration

This plugin uses `bd` (beads) for ALL task tracking.

### Commands Used in Skills

| Action                            | Command                                                 |
| --------------------------------- | ------------------------------------------------------- |
| Create epic                       | `bd create "Epic: name" -t epic -p 2`                   |
| Create task                       | `bd create "Task: title" -t task --parent <epic-id>`    |
| Quick capture                     | `bd q "title"`                                          |
| Claim work                        | `bd update <id> --claim`                                |
| Complete work                     | `bd close <id> --reason "description"`                  |
| Check remaining                   | `bd ready --parent <epic-id>`                           |
| Explain ready/blocked             | `bd ready --explain`                                    |
| Show blocked                      | `bd blocked`                                            |
| Compound query (replaces list+jq) | `bd query "status=open AND priority<=1"`                |
| Count, grouped                    | `bd count --by-status` (or `--by-priority`/`--by-type`) |
| Epic status                       | `bd epic status <id>`                                   |
| Add dependency                    | `bd dep add <child> <depends-on>`                       |
| Store learning                    | `bd remember "insight"`                                 |
| Remove stale memory               | `bd forget <id>`                                        |
| Search memories                   | `bd memories <keyword>`                                 |
| Search knowledge base             | `bd list --label <topic> --status all` / `bd search "<kw>" --status all` |
| Append note to bead               | `bd note <id> "context"`                                |
| Find duplicate beads              | `bd find-duplicates`                                    |
| Lint issue sections               | `bd lint [id...]`                                       |
| Defer work                        | `bd defer <id> --until="<date>"`                        |
| Flag for human decision           | `bd label add <id> human`                               |
| Validate parallel readiness       | `bd swarm validate <epic-id>`                           |
| Atomic batch operations           | `bd batch` (stdin or `-f file`)                         |
| Run in another directory          | `bd -C <path> <command>`                                |
| Sync beads                        | `bd dolt push`                                          |
| Sync to GitHub Issues             | `bd github push`                                        |

### Rules

- Use `bd` for ALL task tracking — never TodoWrite, TaskCreate, or markdown TODOs
- Never guess bd syntax — on first use of a command or flag this session, read `bd <cmd> --help` (the binary is SSOT)
- Only the orchestrating agent manages beads — subagents do NOT touch beads
- Include bead IDs in commit messages: `git commit -m "Add feature (bd-a1b2)"`
- Every session ends with Land the Plane: `bd close` → `bd dolt push` → `git push`
- Beads *policy* is embedded where it's read — using-superpowers' Beads section plus inline own-operation kernels (no dedicated policy skill); bd *commands* defer to `bd human` — don't restate command tables in skills

## Skills

| Skill                          | Purpose                                                                                                                     |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| using-superpowers              | Bootstrap — loaded at session start, routes to other skills                                                                 |
| brainstorming                  | Socratic design before code — creates session beads                                                                         |
| stress-test                    | Adversarial design interrogation with recommended answers                                                                   |
| writing-plans                  | Bite-sized task plans — each task becomes a bead                                                                            |
| subagent-driven-development    | Fresh agent per task + single task review (spec + quality verdicts); parallel batch mode for independent tasks              |
| executing-plans                | Batch execution in single session                                                                                           |
| test-driven-development        | RED-GREEN-REFACTOR — Iron Law: no code without failing test                                                                 |
| systematic-debugging           | 4-phase root cause analysis before proposing fixes                                                                          |
| verification-before-completion | Evidence before claims — bd close requires evidence                                                                         |
| requesting-code-review         | Dispatches code reviewer subagent                                                                                           |
| receiving-code-review          | Anti-sycophancy review reception                                                                                            |
| using-git-worktrees            | Isolated development branches                                                                                               |
| finishing-a-development-branch | Merge/PR + Land the Plane (Step 6)                                                                                          |
| document-release               | Post-ship documentation audit and sync                                                                                      |
| project-init                   | Beads/Dolt DB setup, bootstrap, and recovery                                                                                |
| dispatching-parallel-agents    | 2+ independent tasks without shared state                                                                                   |
| auditing-upstream-drift (maintainer-only — `.claude/skills/`, not distributed) | Detect staleness vs upstream superpowers/beads                             |
| getting-up-to-speed            | Session orientation — reads latest session-handoff doc + bd context + adaptive codebase deep-dive + structured current-state summary |
| research-driven-development    | Parallel research agents → blinded citation-grounding verify → synthesized knowledge base document. Triggers on "research this", "what is X", "how does Y work" |
| write-documentation            | Human-quality prose for all human-facing text — 14-rule writing system with context-first drafting and required checks      |
| memory-curator                 | Session-close/on-demand memory consolidation — quality-gated extract, dedup, consolidate, prune (evidence-led)              |
| session-handoff                | **Human-invoked only** — grounded session-handoff doc + continuation memory (not agent-routed)            |

## Modifying Skills

### Modifying an Existing Skill

1. **Do NOT remove** anti-rationalization tables, Iron Laws, or Red Flags sections in upstream-inherited skills. Fork-only skills follow the composition pattern (ADR-0049): compress to the strongest rows, positive-framed — never remove to zero
2. **Do NOT add** TodoWrite references — use `bd` commands
3. Verify after changes: run `bash scripts/check-todowrite.sh` — must report "No active TodoWrite references"

### Key Anti-Patterns

- Putting workflow descriptions in skill `description` fields (causes Claude to follow description instead of reading full skill — see SDO in docs/methodology.md)
- Softening bright-line rules ("consider" instead of "MUST")
- Adding platform-specific code to skills (skills are pure Markdown)

## Build & Test

Skills are plain Markdown. Docs content lives in `docs/`; the site is built and published by the-factory-website (ADR-0050).

### Validation — the `just` surface (tool, not gate)

Run `just check` after touching harness plumbing (hooks/, install.sh, manifests, .opencode/).
Pre-commit covers commit-time hygiene; nothing here is CI-enforced by design.

```bash
just            # = just check: guards + hooks + manifests + contracts + shape
just guards     # all guard scripts (todowrite, bead-stamp, zh-docs, convention-sync,
                #   skill-count + KNOWN_SKILLS drift, version sync, frontmatter, shell lint,
                #   askuser-genericization)
just lint       # shellcheck gate alone (tracked .sh, baseline'd; SKIPs if shellcheck absent)
just hooks      # tests/hooks/* (node tests SKIP visibly if node absent)
just shape      # install-shape: 9 harnesses (Tier A full artifacts; Tier B hint+manifest)
just shape codex  # one harness
just selftest   # guard-the-guards: 4 mutations that must fail
just server     # brainstorm-server Node tests (opt-in)
just docker     # installer Docker E2E (opt-in, slow)
```

docs preview: from the-factory-website repo (tenants/beads-superpowers)

```bash
# Verify beads integration (should be 30+)
grep -r "bd create\|bd close\|bd ready" skills/ | wc -l
```

For a quick, no-Docker installer smoke test outside the `just` surface: `bash install.sh --test`
(installs to `/tmp`, verifies, cleans up).

Skill *behavior* testing (the 4 LLM suites under tests/) is deprecated in place —
successor: the external eval-harness project. See tests/*/DEPRECATED.md.

**Release process (no GHA):** `./scripts/bump-version.sh <ver>` → update CHANGELOG →
tag `v<ver>` → `git push --tags` → **publish the GitHub Release**:
`gh release create v<ver> --title "v<ver>" --latest --notes-file <changelog-section> checksums.txt`.
The last step is NOT optional — `install.sh` resolves its default version from `releases/latest`,
so a pushed tag without a published Release leaves installers on the previous version. Attach
`checksums.txt` (`sha256sum` of the tag tarball `archive/refs/tags/v<ver>.tar.gz`) or
`verify_checksum` silently skips. Docs deploy is no longer part of this repo's release process — the site publishes from the private the-factory-website repo (ADR-0050).

### Running Skill Tests

Deprecated in place (see "Validation" above) — skill *behavior* measurement now lives in the
external eval-harness project. Each suite's `DEPRECATED.md` explains why it was pulled out of `just check`.

## Version Management

Version is declared in 7 files that must stay in sync:

- `package.json`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `.codex-plugin/plugin.json`
- `.codex-plugin/marketplace.json`
- `.cursor-plugin/plugin.json`
- `.kimi-plugin/plugin.json`

Use `scripts/bump-version.sh` to update all at once:

```bash
./scripts/bump-version.sh 0.5.3        # Bump to new version
./scripts/bump-version.sh --check      # Detect version drift
```

## Example Workflow

The `example-workflow/` directory provides a ready-to-use development workflow:

| File              | Purpose                                                                                                                                                                              |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `CLAUDE.md`       | Karpathy's 4 behavioral principles + beads integration (generic template for any project)                                                                                            |
| `agents/yegge.md` | Orchestrator agent — lean router: triage table, full-flow routing, always-true rules, session protocol. Named after Steve Yegge (beads creator). Optional add-on — installed globally only via `install.sh --with-yegge`. |

## Upstream Sources

| Source                                                    | Version           | What We Track                               |
| --------------------------------------------------------- | ----------------- | ------------------------------------------- |
| [obra/superpowers](https://github.com/obra/superpowers)   | v6.1.1 (baseline) | Skill content, new skills, hook changes     |
| [gastownhall/beads](https://github.com/gastownhall/beads) | v1.1.0 (baseline) | CLI commands, new features, bd prime format |

Use the `auditing-upstream-drift` skill (maintainer-only — `.claude/skills/auditing-upstream-drift/SKILL.md`, not distributed) to check for staleness.
