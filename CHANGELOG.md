# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

> **Forked from:** [obra/superpowers](https://github.com/obra/superpowers) v5.0.7 (2026-03-31)
> **Beads integration based on:** [gastownhall/beads](https://github.com/gastownhall/beads) v1.0.4 (2026-05-09)

## [Unreleased]

### Added

- Three new docs-site pages, each in English and Chinese: **Philosophy** (why the system behaves the way it does - the design decisions as an adopter's mental model, with citations into the research page), **Research** (the evidence behind the design - external literature verified against primary sources, plus this project's own measurements), and **Memory & Sessions** (what happens to memory across a session's life, with sequence, lifecycle, and session-loop diagrams).

- A platform-support issue template for new-harness requests, and a "Questions & Help" Discussions contact link on the issue chooser.
- README sections: **The Basic Workflow** (numbered, skill-mapped pipeline), **Philosophy**, and **Community** (Discussions, Issues, and maintainer contact at <dillon@algocents.com>). EN + ZH.
- `bump-version.sh` now covers prose version surfaces: `.version-bump.json` gains a `prose` entry type (`{path, prefix}` — the version is the token after a literal prefix), with CLAUDE.md's `**Version:**` line as the first entry. `.internal` is audit-excluded, and the behavior is pinned by a sandboxed round-trip test in the contracts suite. README badges need no sync — they've been dynamic since the redesign.
- Manifest validation now covers the marketplace manifests and the Pi extension. All three `marketplace.json` files are JSON-validated (and the two versioned ones checked against `package.json`), the version-less `.agents/plugins/` Codex *source* manifest is asserted distinct from the versioned `.codex-plugin/` distributable so the two can't silently converge, and `.pi/extensions/superpowers.ts` gets structural validation — it exports an extension and its bootstrap skill resolves on disk. A new `tests/manifests/selftest.sh` (wired into `just selftest`) mutates each new check to prove it fires.

### Changed

- The convention-sync guard (`check-convention-sync.sh`) now enforces **true cross-site byte-identity** for its multi-site canonical blocks — the post-work Capture gate and the memory-capture convention — instead of only checking that a signature slice is present. A reworded *non-signature* line could previously drift silently at one site while the guard stayed green; the guard now extracts each block and diffs it across every site, with an anti-vacuous check so a uniformly-stripped anchor can't slip through as "all empty." Three new guard-the-guards mutations prove it goes red on real drift. The per-site kernels and the shared knowledge-base fragment keep signature-presence checks — they're per-site by design, not byte-identical.
- The Capture gate (shown after brainstorm / plan / stress-test / debug) now speaks plain outcome-language to whoever drives the session — the question becomes "Worth keeping anything from this?" and the options are Skip / **Record the decision** / **Remember the lesson** / **Both**, with the criteria stated as plain "pick this when…" guidance (hard to undo, non-obvious in hindsight, real trade-offs). The internal terms — *ADR*, *capture bar*, *3 marks* — leave the user's view; the mechanism (which ADR file, the knowledge-bead, the secret/PII scan) and the anti-over-capture rigor move to the agent-facing Route paragraph, which carries a "clears the bar" rigor check and defers to the user if they insist on a full ADR. Applied byte-identically across `brainstorming`, `writing-plans`, `stress-test`, and `systematic-debugging`; the convention-sync signature re-anchors to `"Worth keeping anything"`. Refines the earlier Skip-default reframe (retains it; fixes legibility for adopters who have never seen an ADR).
- A Pocock deletion-test pass pruned duplicated and sediment prose from the agent-facing auxiliary docs. `CLAUDE.md` drops its Plugin Structure ASCII tree (the Architecture section already documents the layout) and the restated `bd` command table (superseded by `bd human`, the command SSOT), and loses a dangling cross-reference — 372 → 288 lines, with every guard- and test-anchored line preserved. The `brainstorming` visual-companion guide loses a duplicate File Naming section. The subagent prompt templates and small skill references were audited and found already lean, so they were left unchanged.
- The Capture gate (presented after brainstorm / stress-test / plan / debug) is reframed to a **Skip-default**: the question ("Did this clear the capture bar?") and options no longer presuppose value — Skip is the expected outcome, and the ADR/memory options now carry the capture bar as checkable criteria (the 3 ADR marks; a durable evidence-backed lesson). Applied byte-identically across `brainstorming`, `writing-plans`, `stress-test`, and `systematic-debugging`; aligns the gate with the `Capturing Decisions` doctrine's threshold instead of over-prompting.
- The repo's two agent-instruction files are unified: `CLAUDE.md` is now the single canonical file (de-branded to harness-neutral framing), and `AGENTS.md` is a committed symlink to it — eliminating the drift between them (a stale hand-maintained summary). A `just guards` integrity check keeps `AGENTS.md` a symlink; Windows contributors need `core.symlinks` enabled.
- The docs tree moved to an i18n folder layout - `docs/en/` and `docs/zh/` - and every existing page was audited claim-by-claim against the shipped code: the landing page became a thin router with no rot-prone claims, the workflow page now walks the real ten-stage pipeline, the skills reference was reconciled to the shipped skill set, getting-started re-verified every install claim (and fixed a dead link), tips re-verified every `bd` command against the live binary, and methodology was slimmed to the mechanism story with decisions, evidence, and memory detail migrated to the pages that own them. The Chinese-parity guard now derives page pairs structurally from the folders, so adding a page pair registers itself. (The migration guide, initially kept unlisted, was subsequently removed in the fat audit — see Removed.)
- The README "What's Inside" section (EN + ZH) now lists every distributed skill except `using-superpowers` (the session bootstrap, which upstream's README also leaves out): `dispatching-parallel-agents`, `receiving-code-review`, and `project-init` join their categories, and a new Documentation category pairs `write-documentation` with `document-release`.
- README restructured to the upstream superpowers shape (EN + ZH): Quickstart first, a curated set of categorized skills tables trimmed from the full inventory, flat per-CLI Installation (tier headers removed) positioned after the Docs section, dynamic release badge plus PRs-welcome and docs badges, and an extended "Built on" credits section naming Garry Tan (document-release), Matt Pocock (stress-test, session-handoff), and Ivan Neustroev ("Anbeeld", the write-documentation writing system) alongside Jesse Vincent and Steve Yegge. The ZH README also gains the previously-missing Docs link list and Codex hook note.
- Skill attribution centralized in the README: the visible per-skill Source lines are replaced with invisible license comments in the adapted skills, and upstream version pins move to CLAUDE.md's Upstream Sources table.
- Contributor model switched to a dev-branch flow: all work (including maintainer sessions) lands on `dev`, `main` is released-only and advances by fast-forward merges at release cut, and `main`/`gh-pages` carry force-push and deletion protection. CONTRIBUTING.md, the PR template (now with agent-disclosure and human-review gates), and the release runbook follow suit.
- SECURITY.md refreshed: supported-versions table matches the current release line; the stale CI-workflow scope claim is gone.
- document-release now audits the pinned Discussions post alongside the file surfaces.

### Removed

- The stale npx "Updating from ≤0.8.2" migration callout (the `superpowers-reminder.sh` cleanup snippet) and the plugin-vs-npx "full experience" comparison paragraph, from both READMEs.
- **Fat audit (repo-wide, evidence-based):** 54 tracked files cut after a 10-zone reference-mapped audit with per-file verdicts and user review. Gone: the four deprecated LLM test suites (`tests/claude-code`, `tests/explicit-skill-requests`, `tests/skill-triggering`, `tests/subagent-driven-dev` — successor: the external eval-harness project), the completed kv→beads migration tooling (`scripts/migrate-kv-to-beads.sh` + its selftest suite), the gh-pages stub regeneration pair (`generate-ghpages-stubs.sh` + `ghpages-stub-titles.tsv` — the live bridge and its verify script remain; regen lives in git history), the unlisted docs migration guide (`docs/en+zh/migration.md`), `assets/README.md`, `assets/social-preview.png`, `example-workflow/README.md`, the archived pre-overhaul `yegge-old.md`, and the dead `.markdownlintignore`. All references cleaned (CLAUDE.md, AGENTS.md, pre-commit shellcheck arg, docs cross-links, maintainer audit skill).
- The vestigial `github-actions` block in `.github/dependabot.yml` — no `.github/workflows/` exist and the release process is explicitly no-GHA, so it scanned zero targets. The `npm` block remains.
- The `example-workflow/CLAUDE.md` starter template — the adopter-facing Karpathy-principles CLAUDE.md. The `yegge.md` orchestrator and its opt-in `install.sh --with-yegge` path stay; the workflow docs now point adopters at the root `CLAUDE.md` and docs as the behavioral-rules reference.
- The orphaned `docs/assets/extra.css` (81-line MkDocs Material site stylesheet — sidebar CTA buttons + a Mermaid overflow-scroll rule). The docs site builds from the separate the-factory-website repo, which carries its own copy, so this repo's copy had no in-repo consumer. Retires the last presentation-asset exception; the ownership boundary is now clean (`docs/*.md` + `docs/assets/banner.svg` only).

## [0.14.0] - 2026-07-17

### Added

- A **Migrating your knowledge into beads** docs page (`docs/migration.md` + `docs/migration.zh.md`) — a six-phase playbook (principles → per-repo setup → inventory → migrate → wire & verify → lifecycle), each phase ending on checkable exit criteria, for moving a project's ADR directory, design docs, research notes, and reference stashes into the beads-native knowledge store. Generic guidance with this repo's own migration as inline worked-example evidence (129 kv + 36 docs + 55 ADRs → 216 deferred knowledge-beads; 14% → 100% topic-query precision).
- A **model-genericization guard** (`scripts/check-model-genericization.sh`, wired into `just guards` plus a two-directional selftest mutation): hardcoded Claude model names (`haiku`/`sonnet`/`opus`/`fable`) are forbidden in the harness-neutral distributed surfaces (`skills/`, `hooks/`, `example-workflow/CLAUDE.md`), with the deliberately harness-specific files allowlisted (`skills/using-superpowers/references/`, `example-workflow/agents/yegge.md`).

### Changed

- The RDD grounding-verify ladder is now model-agnostic: the `model: "haiku"` / `model: "sonnet"` dispatch fragments in `research-driven-development` (SKILL.md + verifier-prompt.md) are replaced with capability-tier phrasing — verifiers dispatch on a **fast/cheap model**, contested escalations on a **stronger model** — so the instructions work on all 9 harnesses instead of naming Claude Code models. Escalation semantics (3-way ensemble → single stronger-model final verdict) and the author-model-independence contract are unchanged.
- `bd worktree create .worktrees/<name>` (and path-form `bd worktree remove .worktrees/<name>`) is now the mandated instruction form at every `bd worktree` site in the skills. The rule is stated once, positively, in `using-git-worktrees` (bd's bare-name `./<name>` default is demoted to a trap note); the SDD and dispatching-parallel-agents walkthroughs switch form to match, and `finishing-a-development-branch`'s removal step now uses its already-computed, provenance-checked `"$WORKTREE_PATH"`. Removal guidance carries an empirically-grounded caveat: bd's remove safety-check flags any local-only branch as "unpushed" (even at 0 commits), so after verifying the merge landed, add `--force`.

- Bead-creation instructions now use `bd import` (JSONL) instead of `bd create --graph`. The `--graph` node schema was undiscoverable from the binary (no `--help`, no schema dump) and rotted repeatedly; `bd import` round-trips with `bd export` (so the schema can't rot) and is atomic. `parent-child` deps + rich fields (`description`, `acceptance_criteria`) ride the import; inter-task `blocks` ordering is wired with `bd batch` afterward. Applies to `writing-plans`, `subagent-driven-development`, `executing-plans`, `brainstorming`, the CB-5 batch-writes line, the session-start hook, and the docs (EN+ZH).
- Beads-graft in the 13 upstream-inherited skills minimized (Pocock composition-model slice 3). The `bd`-frugality convention block is removed where the always-loaded session hook already carries it (its `--claim` consent boundary is retained per-site as a floor kernel, and the using-git-worktrees copy is corrected to match its actual single-bead claim). The capture-what-you-learned block is shortened uniformly across its sites. Upstream skill content is unchanged and the security floor (destructive-gate consents, the secrets rule, land-the-plane) is byte-for-byte intact.
- Beads DB decoupled onto a dedicated private Dolt remote, separate from this public code repo; the public repo's `refs/dolt/data` and `__dolt_remote_info__` were scrubbed (0 dolt refs on git origin, verified) since Dolt history retains deleted rows and a matching remote previously made every bead, memory, and deleted row publicly fetchable. `project-init` gained a Multi-Repo / Private Beads Remote section — separate-remote is now the primary path in Path A/E, same-repo sync is an explicit opt-in given bd's post-v1.1.0 collision guard (refuses a git-origin-matching remote without `--allow-git-origin`). `diagnose.sh`'s dolt-remote check now probes the *configured* `sync.remote` instead of assuming git origin, and warns if dolt refs ever reappear on the code repo (regression signal). Land the Plane's `git pull --rebase && git push` is now `git pull --ff-only && git push` (three captured history-flattening incidents) across its shipped sites. Docs (EN+ZH): getting-started teaches both the dedicated-remote and same-repo patterns; tips and migration adopt the matching beads-remote terminology.
- Reference-class knowledge (`research`/`design`/`decision` notes) moved from the `bsp.kb.` kv store to beads-native **deferred knowledge-beads**: one bead per item, `status=deferred` (far-future `defer_until`, GC-safe, hidden from `bd ready`), labeled `kb` plus 1–3 controlled-vocabulary topic labels, with `metadata.doc` pointing at the source doc/ADR. All 129 existing kv entries (11 decision + 43 research + 75 design) were migrated and every `bsp.kb.` kv entry is now a tombstone. Retrieval is `bd list --label <topic> --status all` (topic) or `bd search "<keyword>" --status all` (keyword); `bd supersede <old> --with <new>` retires stale entries. The store ships with its enforcement surface: a 3-invariant label guard and a doc↔bead reconciliation guard (both in `just guards`), a retrieval-contract test pinning the 5 depended-on `bd` behaviors, KB-query triggers co-located in brainstorming/systematic-debugging Phase 1 plus a session-start pointer, and the 36 `.internal/research/` disk docs indexed as research beads (store total 164).
- The knowledge-store capture snippets now pipe a distilled description into the bead body (`--body-file -`) instead of creating title-only rows, across the RDD Step-5 snippet, the four CB-3 ADR-capture gate sites, and the memory-curator move-out. This repo's own store was completed to match: 29 thin research beads enriched to full distillations and 53 ADRs backfilled as `decision` knowledge-beads, both with human-reviewed labels and sensitivity parking for items not yet cleared for a shared Dolt remote. The doc↔bead reconciliation guard now also covers the ADR corpus, gating each corpus independently so a skipped capture in one can't hide behind coverage of the other, and the zh-parity guard gained a completeness assertion that fails if any `docs/*.md` page is left unregistered.
- KB retrieval now reads what it finds: every retrieval site (brainstorming, systematic-debugging, research-driven-development + its researcher prompt, the session-start pointer, getting-up-to-speed) requires opening hit bodies — `bd show <id1> <id2>` or `bd list … --flat --long -n 10` — with a one-line disposition per relevant hit (folded in / ruled out) instead of stopping at "N hits". Body-term recall is documented (`--desc-contains`, since `bd search` matches titles only), over-broad queries are narrowed rather than triaged from truncated titles, and a query re-angles once before concluding "none". The sentence "hits are pointers, not knowledge" is guard-synced at all six sites, and the retrieval contract test grows from 5 to 9 pinned bd behaviors.
- Finishing a branch now runs the docs audit structurally: finishing-a-development-branch gained Step 3.5 (Docs-Audit Gate) — before merge/PR options are presented, document-release must have run on the branch (or is invoked on the spot; doc-irrelevant diffs exit cheaply), with an explicit user decision if the audit cannot complete. document-release's description gained the matching state trigger, so end-of-branch docs audits no longer depend on the router remembering them.
- The session-start hook's Issue Tracking pointer now ranks skills at work entry: starting work on a bead routes process skills first — brainstorming → writing-plans → only then an implementation skill — and a bead with an existing spec/plan proceeds straight to its planned skill. Closes the gap where skill priority bound request→skill matching but not bead→skill matching, so orientation could suggest test-driven-development for an un-designed backlog item.

### Removed

- Seven dead bundled files: two superseded document-reviewer prompt templates (`plan-document-reviewer-prompt.md`, `spec-document-reviewer-prompt.md`, replaced by the stress-test workflow) and five upstream eval/creation-log artifacts under `systematic-debugging/` that served no runtime purpose.

## [0.13.0] - 2026-07-14

### Added

- Maintainer contact email (`dillon@algocents.com`) in the plugin manifests' author/owner fields, `package.json`, SECURITY.md, and the Code of Conduct — a direct address replaces the previous GitHub-profile indirection, matching where upstream superpowers carries its contact.
- Memory-backlog escalation tier: at ≥300 stored memories (`BSP_MEM_ESCALATE_AT`), the session hook injects a directive to file one deduplicated memory-curation chore bead (the ≥150 soft nudge is unchanged; tiers never stack).

### Removed

- The `tracking-with-beads` policy skill. Beads policy now lives where it is read — the using-superpowers Beads section and inline kernels in the skills that perform each operation; commands remain owned by the bd binary (`bd human`, `bd <cmd> --help`). Upgrades remove previously installed copies automatically.

### Fixed

- bd command syntax across the instruction surface now matches the binary: brainstorming's `--graph` guidance (file-path arg, real node-schema behavior), the phantom `bd human <id>` reference, and a repo-wide audit of asserted flags. New house rule at the always-loaded layer: the binary is SSOT — read `bd <cmd> --help` on first use, never guess.
- project-init no longer asserts the phantom `bd vc log` (no such command in bd v1.1.0 — `bd vc` is commit/merge/status only). The three SKILL.md sites and `scripts/diagnose.sh` now use `bd vc status`, verified against `--help`; the diagnostic battery's `== db ==` section previously dumped `bd vc` usage text instead of VC evidence on every run.
- The SDD implementer prompt template no longer instructs subagents to claim/close beads. The beads lifecycle section is now explicitly controller-owned, matching the "only the orchestrating agent manages beads" convention and the SDD flow diagram; subagents report evidence + a suggested close reason instead.
- The composed SessionStart envelope now fits Claude Code's 10,000-char per-hook inline threshold (total byte budget 9,500). Previously ~15KB, so every session received a `<persisted-output>` pointer instead of inline context, silently dropping curated memories and the binary-is-SSOT pointer. The memory ceiling is now scaffolding-accurate and the continuation memory degrades to a `bd recall` pointer instead of bypassing the budget.

## [0.12.0] - 2026-07-12

### Added

- **`tracking-with-beads` policy core + the first Pocock-shaped skill.** A new model-invoked skill owns the beads conventions of record (frugality, the `--claim` consent boundary, capture quality, land-the-plane policy); bd command tables defer to `bd human`. `getting-up-to-speed` is the pilot redesign: steps with checkable completion criteria, every-run reference inline-pruned, branch-only edge cases behind `references/edge-cases.md`, own-operation kernels guarded by a per-site signature map in `check-convention-sync.sh`, and a contract test that pins invariants instead of prose. Output contract unchanged. Existing `.beads/PRIME.md` safety-net files keep their old pointer text until deleted (the file explains its own refresh); new ones name `tracking-with-beads`.

### Changed

- **BREAKING (contributors):** MkDocs machinery moved to the private the-factory-website repo — this repo is docs-content-only; site at algocents.com/beads-superpowers/; the old github.io home is now a permanent-redirect stub bridge (≥1yr).
- **Fork-only Pocock sweep: 7 fork skills + the maintainer drift-audit skill reshaped.** Every fork-only skill now carries the Pocock shape: steps ending on checkable completion criteria, every-run reference inline (pruned), branch-only material behind `references/` context pointers — project-init's recovery walkthroughs (`references/recovery.md`), write-documentation's long-form diagnostics (`references/long-form-diagnostics.md`), and the maintainer drift-audit's 21-check catalog (`references/check-suite.md`, closing the progressive-disclosure gap). The security floor is now machine-pinned: `check-convention-sync.sh`'s KERNEL_MAP grew from 1 to 9 per-site kernel invariants (secrets, consent gates, Iron Laws) with a fail-on-mutation self-test. Frontmatter descriptions are byte-unchanged across all 8 skills — trigger behavior unaffected. Cross-tier convention blocks (CB-3/4/5) stay byte-identical pending slice 3.
- **Harness plugin manifests re-aligned with upstream superpowers v6.1.1.** Keyword sets restored to upstream's per-manifest vocabulary (plus `beads`/`issue-tracking`), the Kimi `skillInstructions` re-adopts upstream's full tool mapping with the beads override, the Claude marketplace manifest regains its description field, and `.codex-plugin/plugin.json` adopts upstream's Codex portal packaging (`skills` path, empty `hooks`, `interface` block) with beads-superpowers branding. Five deliberate divergences newly registered in the maintainer drift-audit skill; Gemini support deferred (upstream's own Gemini pointer is broken).
- **BREAKING: OpenCode install is now git-install only, exactly like upstream.** The plugin moved to `.opencode/plugins/beads-superpowers.js` (upstream's plugin as the base — message-transform bootstrap, config-hook skill auto-registration — plus the beads graft: composer-sourced context and compaction re-injection). Install by adding `"plugin": ["beads-superpowers@git+https://github.com/DollarDill/beads-superpowers.git"]` to opencode.json; `package.json` gains the `main` entry the git spec loads. `install.sh` no longer copies OpenCode artifacts — pre-0.12 copies keep working but are frozen; migrate per `.opencode/INSTALL.md` (or `install.sh --uninstall` removes them). The version-sync set drops `opencode/package.json` (8 → 7 files).

### Removed

- **BREAKING: the `writing-skills` meta-skill is no longer shipped.** It authored upstream-style skills — maintenance weight this fork doesn't need. Existing installs have it removed on upgrade/uninstall via `install.sh` (never on fresh install); the `skills` npx channel simply stops listing it.

### Fixed

- **SessionStart hooks registered via Claude Code `settings.json` now actually inject the beads context.** Claude Code parses that channel's hook output strictly and silently discarded the previous top-level format, so settings-registered installs started every session without skills bootstrap or memories. The hook now recognises the Claude Code environment on every channel and emits the nested envelope Claude Code expects.

## [0.11.0] - 2026-07-10

### Changed

- **`research-driven-development` now fact-checks its own findings before writing them up.** After the parallel researchers report back, every load-bearing claim goes to a separate, blinded verifier that re-fetches the cited source itself and confirms the source actually backs the claim — being merely on-topic no longer counts. Claims that don't hold up get chased in a follow-up round or dropped, so the research document reflects what the sources say rather than what sounded right. The skill also picked up an explicit nested mode (research invoked by another skill returns its findings instead of stopping to prompt you) and a wider fan-out of up to 10 parallel researchers.
- **Reference-class memories now route to a `bsp.kb.` knowledge base instead of crowding the session-start context.** The `memory-curator` taxonomy makes a memory's `@type` its routing decision: rules you want surfaced unprompted (`lesson`, `pattern`, `root-cause`, `correction`) stay injected, while reference notes that only point at a doc or ADR (`research`, `design`, `decision`) move to a `bsp.kb.` key-value store that persists and Dolt-syncs but is never auto-injected — retrieve them on demand with `bd kv list | grep '^ *bsp.kb'` or `bd kv list --json | jq`. Running a `memory-curator` sweep applies the model to an existing store and can roughly halve an overcrowded one (this project's went 227 → 102 memories). The session-start composer's salience selector is now anchored to each memory's header line, so a note whose *body* mentions `@salience=5` no longer false-selects for injection, and a graduated nudge suggests a curator pass as the store grows. Three memory-reading skills (`research-driven-development`, its research subagent, and `getting-up-to-speed`) also search the `bsp.kb.` namespace so routed notes stay discoverable.
- **BREAKING: SessionStart no longer injects the full `bd prime` dump — it composes a lean beads context instead.** The hook now emits a `bd` workflow pointer plus curated core memories (`@salience>=4` plus the latest continuation, selected from `bd memories --json` under a hard 8KB byte ceiling with a visible "+N more" tail) and a self-disclosing pointer line ("core memories: K of N injected"). Measured on the live 218-memory store, session-start injection drops from ~173,800 chars (~43.4k tokens — 97% was the unranked memory dump) to 14,596 bytes (~3.6k tokens), a 91.6% reduction; memories not selected stay retrievable just-in-time via `bd memories <keyword>` / `bd recall <key>`, with selection driven by the memory-curator salience taxonomy (backfill sweep: 218/218 memories now headered). A guarded `.beads/PRIME.md` safety net is auto-written (only when `.beads/` exists, never overwrites, off-switch `bd config set custom.prime-safety-net false`), so a stray `bd prime` call now emits a ~600B pointer instead of the full dump; Tier-B harnesses (no hook) keep full `bd prime` unchanged. `install.sh`'s written hook is now a thin exec shim of the canonical composer where a checkout exists, and the npx tier writes a policy-free minimal hook (no `bd prime` capture) — a new `scripts/check-install-hook-fork.sh` guards against the two drifting apart; the OpenCode plugin execs the same canonical composer with a no-policy fallback. A new "bd frugality" convention block (bounded reads, batched writes, the `--claim` consent boundary) is synced across 6 skills; `getting-up-to-speed`'s Phase 1 and `project-init`'s diagnostics each collapse to one bundled data-gathering script call (`orient.sh`, `diagnose.sh`); `bd prime` mandates across skills became conditionals; and `brainstorming` now documents its ephemeral ceremony beads.
- **Skills no longer hardcode the Claude Code `AskUserQuestion` tool name.** All ~28 instruction sites across 10 skills now use generic "structured question tool" phrasing; a new **Asking the User** convention block in the always-injected `using-superpowers` bootstrap carries the universal rule — prefer the harness's structured question tool, fall back to numbered plain-text options + STOP, and treat skipped/dismissed/auto-resolved answers as **no consent** (headless and auto modes fabricate answers on most harnesses, including Claude Code `-p`). The 3 destructive gates (finishing-a-development-branch, document-release, using-git-worktrees) carry self-contained consent lines; per-harness reference files gain quirk rows (Codex `request_user_input` plan-mode gate, Pi tool absence) and the factually wrong OpenCode "Not available" row is corrected (OpenCode ships a built-in `question` tool, default-on). A new `check-askuser-genericization.sh` guard in `just guards` enforces the invariant. Grounded in a 9-harness research sweep: 8 of 9 harnesses have a native structured-question tool under 7 different names.
- Docs site content boundary redrawn against upstream Beads' documentation site: `bd` cheat-sheet and command tables trimmed toward the workflow-core command set, with curated "Go deeper" references to the upstream docs at every delegation point (EN + ZH in lockstep). The `auditing-upstream-drift` skill gains Check 7.7, a link-check that catches upstream URL rot at each audit. Readers keep the day-to-day surface on-site and follow annotated links for tool depth.
- ADR home relocated from `decisions/` to `docs/decisions/` (aligns with the MADR convention); ADRs remain gitignored-local working docs. `mkdocs.yml` gains an `exclude_docs` entry (and a `git-revision-date-localized` exclude) so the internal ADRs never render into the published site, and a new `scripts/check-adr-gitignored.sh` guard (in `just guards`) fails if `docs/decisions/` ever stops being gitignored — so ADRs living inside the published `docs/` tree can never leak. The decision-capture convention text across the skills, `CLAUDE.md`, and the docs pages (EN + ZH) now points at `docs/decisions/`. (ADR-0046, supersedes ADR-0033 on the path clause only.)

### Fixed

- **SessionStart could double-inject under multi-scope hook registration.** An event-scoped self-dedup marker (keyed on `(session_id, source)`, 60s TTL, per-user `0700` directory, symlink-refusing, fail-open) now suppresses the sibling firing instead of injecting the beads context twice; post-compaction re-injection is unaffected.
- Plan-to-bead creation now passes `bd lint` on first create: writing-plans' Task Structure gains an **Acceptance Criteria** block and all three creation sites (writing-plans, executing-plans, subagent-driven-development) instruct embedding the lint-required sections — `## Success Criteria` in epic descriptions, `## Acceptance Criteria` in task descriptions (or `--acceptance` in the sequential fallback). Previously an agent following the skills verbatim produced beads that failed the skills' own lint step.

### Removed

- **BREAKING: `auditing-upstream-drift` is no longer distributed.** It is a maintainer-only skill (it audits this fork against upstream superpowers/beads) and now lives at `.claude/skills/auditing-upstream-drift/` — git-tracked and discovered as a project skill for maintainers, excluded from the plugin, install.sh, and Pi channels. install.sh upgrades and uninstalls remove previously installed copies (evidence-gated: fresh installs never touch the path). npx installs may still surface it (that CLI scans `.claude/skills/`; accepted — npx is the declared degraded tier) but the skill now self-guards and refuses to run outside its home repo. (ADR-0044)

## [0.10.0] - 2026-07-06

### Added

- **Shell-lint gate.** `just lint` (also wired into `just guards`/`just check`) runs shellcheck over every git-tracked shell script and fails only on findings not in the committed baseline — which shipped **empty**: all 56 tracked scripts are already warning-clean. Skips visibly when shellcheck isn't installed, so fresh clones aren't blocked.
- **Codex marketplace manifest.** A repo-root `.agents/plugins/marketplace.json` lets Codex marketplace sources actually discover and install the plugin (`codex plugin add <source>` then install) — previously Codex could add the marketplace but found zero installable entries.

### Changed

- Production-Grade Doctrine consolidated: the 3 byte-identical CB-1 paragraph sites (brainstorming, writing-plans, executing-plans) are now self-contained woven floor lines (incl. an explicit security clause); CB-1 retired from `check-convention-sync.sh`; `auditing-upstream-drift` now protects the doctrine as a divergence *class* (canonical block + woven lines) on re-sync. Doctrine content and all security-gate rules unchanged.
- **BREAKING: the `yegge.md` orchestrator agent is now opt-in.** `install.sh` no longer copies `yegge.md` to `~/.claude/agents/` by default — pass `--with-yegge` to install it. When the flag is set, the plugin and npx tiers are skipped (they have no checkout to copy the agent from; same precedent as `--version`), so install lands on the tarball/git/local tier. `--test` verifies whichever mode it is invoked with, and uninstall removes the agent in both modes. Upgrades never delete an existing `yegge.md`, but it is only refreshed when you upgrade with `--with-yegge`; `--uninstall` still removes it. README and docs (EN+ZH) now present yegge/example-workflow as a suggested-workflow optional add-on.
- **project-init now teaches the beads v1.1.0 migration gate.** Since beads v1.1.0 refuses to silently migrate a remote-backed database, the recovery guide walks you through the real decision — one designated migrator (`bd export --all -o backup.jsonl`, then `BD_ALLOW_REMOTE_MIGRATE=1 bd migrate`, then push) while every other machine adopts via `bd bootstrap` — and points at bd's printed recovery recipe when Dolt refuses a primary-key fork. `bd recompute-blocked` is now part of the post-pull routine.
- **Leaner per-harness reference files.** The Copilot and OpenCode tool-mapping references drop the generic rename rows agents already infer (Read→view and friends), keeping only what carries real weight: capability gaps with workarounds, agent-type mappings, async shell sessions, and `bd` usage. Smaller injected context, same guidance.
- Audited upstream baselines advanced: skill content now tracked against superpowers **v6.1.1**, beads integration against **v1.1.0**.

### Removed

- **BREAKING: Gemini CLI harness support removed entirely.** Google EOLed the Gemini CLI on 2026-06-18; its successor, Google Antigravity, is already a supported best-effort harness. Deleted `gemini-extension.json` and `GEMINI.md`, dropped Gemini detection and the native-install hint from `install.sh`, and shrank the synced version registry from nine files to eight. Historical CHANGELOG entries are unchanged.

### Fixed

- **The upstream-drift audit's self-checks work again.** The audit skill now counts all 8 phases (was "7"), checks version sync across the real 8-file registry via `bump-version.sh --check` (was a hardcoded 6-file grep), greps the renamed `## Beads` bootstrap section (the old check could never match and silently failed), and drops a reference to a deleted test README.
- **Codex hook limitation documented instead of silently broken.** README and the getting-started guide now state it plainly: Codex plugin-channel installs do not register the SessionStart hook (codex-cli rejects manifest hook objects) — use the scripted `install.sh`, which wires the hook explicitly.
- **project-init's manual bootstrap no longer hides migration-gate refusals.** The `bd migrate --yes` step in the Path B manual remote-bootstrap fallback dropped its stderr suppression, so a beads v1.1.0 remote-migrate-gate refusal is visible instead of silently leaving the freshly cloned database unmigrated — and the step now points at the Path C gate guidance for what to do next.

## [0.9.0] - 2026-07-03

### Added

- **`justfile` check surface (tool, not gate).** `just check` runs the deterministic set — guards, hook tests, manifest validation, skill-contract tests, and the new install-shape suite — on demand when harness plumbing changes. `just selftest` (guard-the-guards: 4 must-fail mutations), `just server`, `just docker`, and `just docs` are opt-in. Nothing is CI-enforced by design.
- **`tests/install-shape/` — 9-harness install-shape suite.** Sandboxed `install.sh --source` runs with inert PATH-shim fixtures assert what each harness actually receives: full artifact + uninstall round-trip assertions for Claude Code/Codex/OpenCode, hint-text + manifest assertions for the 6 best-effort harnesses (which receive guidance, not files). Proves artifacts land — does NOT prove hooks fire (see `tests/install-shape/MANUAL-VERIFICATION.md`).
- **`install.sh --source <dir>`** — local Tier-0 install from a checkout: bypasses all download tiers, zero network, version from `package.json`. Dev/test affordance; checksum validation on the tarball path is untouched.
- KNOWN_SKILLS≡`skills/` drift guard in `check-skill-count.sh` (catches the array silently missing a skill — a bug class that shipped once before).

### Fixed

- **OpenCode TS plugin was never installed by `install.sh` in any tier** — the extract dir passed to `install_opencode_from` pointed inside the skills staging dir. Found by the new install-shape suite.
- **Uninstall was broken in two ways** (also found by the suite): `--source`/local-tier installs skipped all uninstall cleanup (missing case arm), and a trailing `[ cond ] && …` in the Codex/OpenCode uninstall helpers aborted `do_uninstall` under `set -e` whenever those harnesses were never installed.
- **`getting-up-to-speed` no longer under-reports open work or mislabels fresh handoffs.** Its Phase-1 status query is split into two per-status calls (bd v1.0.5 silently drops rows when `OR` spans status clauses), and the handoff freshness check matches the doc's recorded short sha against HEAD prefix-aware instead of by full-string equality.

### Changed

- **Skill scratch standardized to one root.** SDD and brainstorm working files now live under `.internal/` (`.internal/sdd/`, `.internal/brainstorm/`) instead of a separate `.superpowers/` root. Both self-ignore so they stay out of git even in downstream repos that don't ignore `.internal/`; brainstorm's gains this to keep its session auth token (`.last-token`) from ever being committed. The brainstorm server (`server.cjs`) is unchanged.
- **BREAKING:** Removed the per-prompt UserPromptSubmit reminder hook on all harnesses; the SessionStart bootstrap (rebased on upstream superpowers v6.1.0, now ≤6KB) is the single recurring injection.
- `using-superpowers` bootstrap rebased on upstream v6.1.0's lean shape; per-harness references trimmed; Gemini reference removed.

### Deprecated

- The four LLM-driven test suites (`tests/skill-triggering`, `tests/explicit-skill-requests`, `tests/claude-code`, `tests/subagent-driven-dev`) are deprecated in place — successor is the external eval-harness project. Kept as reference; excluded from the `just` surface. See `tests/*/DEPRECATED.md`.

### Removed

- The `setup` skill. The npx path is now skills-only; hooks come from the plugin installs or `install.sh`. Run `bd setup claude` for `bd prime` on npx installs.
- **BREAKING:** The dormant GitHub Actions workflows `ci.yml` and `release.yml` (both manual-dispatch-only and stale). Checks live in the local `just` surface; releases are `bump-version.sh` → tag → push. `deploy-docs.yml` (docs publishing) survives.
- DCI output-path resolution in `research-driven-development` — `resolve-output-dir.sh` and its `bd config custom.research-output-dir` / `RESEARCH_OUTPUT_DIR` priority chain deleted; the knowledge base is hardcoded to `.internal/research/`. The `!` backtick (DCI) syntax only works on Claude Code — a portability liability on every other harness — and the configurability was speculative. Also fixes the researcher prompt's stale `docs/research` default.

### Fixed

- **`npx --copy` setup no longer installed a no-op session-start hook.** On a skills-only
  `npx skills add … --copy` install there was no `hooks/` directory, so the (since-removed) setup
  skill's hook-content resolver found nothing and installed an empty hook — silently disabling skill
  auto-activation for those users. Marketplace-plugin and native installs were unaffected; skills-only
  installs now get hooks from `install.sh` instead. Existing `--copy` users who installed the broken
  hook should **re-run `install.sh`** to refresh their hooks.
- `install.sh` now removes stale UserPromptSubmit registrations on update/uninstall (python3, timestamped backup, foreign hooks preserved). Manual one-liner in the README npx section for users updating from ≤0.8.2.

## [0.8.2] - 2026-06-30

### Added

- **`session-handoff` skill (human-invoked).** A new skill that writes a grounded handoff document — current state, work in progress, what shipped, decisions, loose threads, and how to resume — plus a one-line continuation memory, so a fresh session can pick up in-progress work after a context reset or a teammate handoff. It is deliberately human-only: never auto-invoked, and absent from every agent trigger surface. Output defaults to a gitignored local path, with a `git check-ignore` safety check and secret redaction so a handoff can't leak secrets to a tracked file.

### Changed

- **`getting-up-to-speed` now reads the latest session-handoff doc, engages parallel agents sooner, and stops continuation memories from piling up.** On orientation the skill now finds and reads the newest `.internal/handoff/` doc (when one exists), folding it into the summary as a cross-checked, headline-only narrative source — so a fresh or post-compaction session picks up the prior session's thread, not just the one-line pointer. Its repo-size bands were rescaled (`<40` / `40–150` / `>150` tracked files) so sub-agent fan-out kicks in for mid-size repos instead of only very large ones. And at close it prunes superseded `continuation-*` pointer memories — keeping the newest, matching on the key prefix only, and failing safe rather than guess-deleting — consistent with `memory-curator`'s keep-newest policy. `session-handoff` now notes that `getting-up-to-speed` reads its artifact (still no skill-to-skill call either direction).
- **The skill count is no longer hardcoded, so it can't silently go stale.** The advertised number of skills used to be duplicated across roughly seventeen places — plugin manifests, the README, `CLAUDE.md`, the installer, the docs site — and every new skill left some of them wrong. The exact count now lives in exactly one computed place (the docs site's build-time macro); everywhere else simply reads "composable skills" with no number to drift. A new `scripts/check-skill-count.sh` pre-commit hook fails the commit if a hardcoded skill count reappears anywhere, and also verifies every skill directory has exactly one `SKILL.md`. The old `scripts/sync-skill-count.sh` count-syncer is removed.
- **`getting-up-to-speed` no longer mistakes a stale handoff for the last session.** It now treats `.internal/handoff/` as an unread inbox: the handoff it reads is archived to `.internal/handoff/archive/` at the end of orientation, so a later session with no new handoff finds an empty inbox instead of re-reading an old one. As a backstop for handoffs an intervening session never consumed, it compares the handoff's recorded commit against `HEAD` and, when `HEAD` has moved past it, labels the doc "possibly stale" and suppresses the "welcome back — last thread was …" narration rather than mis-attributing it. A multi-doc inbox surfaces a "+N older unread" count. `session-handoff`'s docs note the consume-on-read counterpart.
- **Documentation synced to the shipped behavior, in both languages.** The remaining hardcoded skill-count literals are gone — the two English docs-site frontmatter descriptions and the Chinese README no longer carry a number (the English-only guard had let the Chinese "24 项技能" slip through, so `check-skill-count.sh` now also catches CJK count forms). The skills reference and diagrams now describe `getting-up-to-speed`'s handoff-inbox behavior and place `session-handoff` in the lifecycle, and the Chinese docs were re-synced to the English pages for the `memory-curator` close step and `bd create --graph` plan creation.

## [0.8.1] - 2026-06-28

### Changed

- **Skill conventions now hold up in isolation.** Every skill's production-grade doctrine, memory-capture guidance, and decision-capture prompt is now self-contained, so a skill invoked on its own, under a subagent, or after a context compaction no longer points at a `using-superpowers` section that may not be loaded. Skill cross-references use the `beads-superpowers:` plugin namespace so they resolve to this fork rather than the upstream one, and the four decision skills (brainstorming, planning, stress-testing, debugging) now close with a single explicit Capture prompt — record an ADR, a memory, both, or skip — instead of separate, easy-to-miss instructions. A new `scripts/check-convention-sync.sh` gate keeps the shared convention text byte-identical across skills so the copies can't quietly drift apart.
- **Decision-capture is framed as an offer at each decision point.** The session reminder and the methodology and workflow docs (English and Chinese) now invite you to record an ADR rather than implying one is automatic, and the three-part gate — hard to reverse, surprising without context, a genuine trade-off — still keeps ADRs scarce.
- **Human-facing docs no longer carry internal tracker IDs.** Removed `ADR-NNNN` and `bd-xxxx` references from the README, CHANGELOG, and docs-site pages — they pointed at gitignored local decision records and bead IDs that a reader can't open. `document-release` and `write-documentation` now flag these so they don't creep back into reader-facing prose.
- **`memory-curator` now organizes memories by a two-level type taxonomy.** Each memory is tagged `@type=<class>:<subtype>` — `semantic` for durable facts (design, lesson, pattern, decision, root-cause, research, correction) or `episodic` for time-bound records (done, continuation, cleanup, review) — so you can filter and rank them (e.g. `bd memories | grep '@type=episodic:'`), and the curator uses the class to prune safely: episodic clusters distill into semantic facts and the most-recent handoff is never dropped. The skill was also streamlined, with its propose-then-apply, secrets, and never-shrink safeguards sharpened.

## [0.8.0] - 2026-06-28

### Added

- **Chinese (Simplified) documentation + language switcher.** The README and all six docs-site pages now have a Simplified-Chinese (`zh`) version, with a one-click language switcher in the Material header (auto-generated by `mkdocs-static-i18n`) and an `English · 中文` link at the top of the README. Translations are AI-produced under a do-not-translate guardrail (code, `bd` commands, `{{ macro }}` tokens, and product terms preserved) and each zh page carries an honest "机器翻译 / machine-translated" banner linking the English source; a tracked bead invites native-speaker post-editing. A `scripts/check-zh-docs.sh` gate (with a self-test) enforces structure/term parity, and an in-repo `mkdocs_hooks.py` shim keeps `mkdocs-panzoom-plugin` working under the plugin's per-locale build. Untranslated pages fall back to English, so the site never breaks.
- **Agent-Filed Bead Discipline.** When a skill files a bead for discovered/follow-up work, it now stamps the bead with a severity tier (Critical/Important/Minor), an evidence-driven confidence marker (Confirmed when it cites a checkable `file:line`/failing test/repro, else Speculative), and a `[spec]` title prefix for speculative items — so a human can triage agent-filed work at a glance without opening each bead. The convention is single-sourced in `verification-before-completion` and applied at `finishing-a-development-branch` and the `executing-plans`/`subagent-driven-development` blocker-filing sites, with one-line pointers from `code-reviewer`/`brainstorming`/`writing-plans`. A new `scripts/check-agent-bead-stamp.sh` CI gate keeps the convention present at every required site.
- **Decision-capture convention.** The orchestrator now offers to record an Architecture Decision Record when a decision clears a strict three-part gate — hard to reverse, surprising without context, and the result of a genuine trade-off — keeping ADRs scarce and high-value instead of firing on every clarification. The convention is single-sourced in `using-superpowers` (a `## Capturing Decisions` block), nudged once per prompt by `superpowers-reminder.sh`, and referenced with a one-line pointer at the `brainstorming`, `writing-plans`, `stress-test`, and `systematic-debugging` decision points plus the `yegge` orchestrator — closing the gap where skills cited and audited ADRs but none produced them. ADRs stay local in `decisions/`.
- **`memory-curator` skill.** A new skill (the 23rd) that consolidates, deduplicates, and structures the beads memory store — offered at session-close when you've captured several new memories, or run on demand for a full sweep. It enriches each memory with a compact `@type/@created/@salience/@refs/@tags` header so you can filter and rank them, and it proposes every change as a reviewed command list before anything is written. The scope is deliberately evidence-led: it does the proven work (quality-gated capture, consolidation, pruning) and skips unproven memory-graph machinery.

### Changed

- **Atomic plan creation via `bd create --graph`.** `executing-plans` and `subagent-driven-development` now create a plan's epic + tasks + dependencies in one atomic transaction (validate with `--dry-run` first, then create) instead of a sequential `bd create` loop — eliminating the orphaned-bead failure mode where a mid-sequence crash left a half-built epic polluting `bd ready`. `writing-plans` documents the pattern; a sequential-loop fallback is noted for older `bd`. Verified working under embedded Dolt v1.0.5.
- **MAST-FC2 pre-fan-out discipline.** `dispatching-parallel-agents` and `subagent-driven-development` (Parallel Batch Mode) gain a short orchestrator-only checklist before fanning out: front-load shared decisions into every agent prompt and share full context, not summaries — because worktrees isolate *files*, not *assumptions* (parallel agents on different files can still diverge on an un-prescribed shared decision).
- **The `yegge` example-workflow orchestrator is now a lean router.** The optional `yegge.md` agent drops from a 263-line 11-state FSM to a ~70-line triage-and-route agent: a triage table (quick question / simple change / non-trivial / research) and a compact full-flow step list that *defer to the skills* (which own their own gates), plus a two-tier skill index — instead of restating command tables, plan templates, and an unenforceable "no state may be skipped" state machine. Trivial edits no longer drag a worktree + doc audit + PR behind them, but verification stays required on every path. The retired "RPI" methodology branding and the `@researcher`/`@implementer` agent-personification are gone; the pre-overhaul agent is preserved at `example-workflow/agents/archive/yegge-old.md`, and the paired `example-workflow/README.md`, the `CLAUDE.md` Land-the-Plane order, and the docs-site workflow page were reframed from the 11-state FSM to the lean-router flow to match.

### Fixed

- **Corrected the embedded-Dolt guidance.** `dolt_mode: embedded` runs the Dolt engine in-process but does **not** disable sync — `bd dolt status/show/push/pull` all work with a configured remote. The earlier "embedded mode means all Dolt commands fail" claim in `CLAUDE.md`/`AGENTS.md` was false and has been corrected (verified 2026-06-28); genuine push failures are setup-specific (diverged history, push-protection).
- **Consistent `bd create --graph` edge schema.** The dependency-edge type is now `type: blocks` uniformly across the `executing-plans` and `subagent-driven-development` plan-graph examples, so a copied plan wires its dependencies correctly instead of silently mismatching.

## [0.7.2] - 2026-06-26

### Added

- **Native support for 7 more AI coding agents.** Beyond the verified trio (Claude Code, Codex, OpenCode), the plugin now ships native per-CLI config for Cursor, Gemini CLI, GitHub Copilot CLI, Kimi Code, Antigravity, Factory Droid, and Pi — each with its own install section in the README and a tiered, honest "best-effort, not E2E-tested by us" label. `install.sh` auto-detects all of them.
- **Production-Grade Doctrine.** Every session now carries a bright-line doctrine: treat every project as a production-facing system with real users, so the agent never takes shortcuts, silently descopes a requirement, or accepts a material-risk trade-off on its own judgment — and never accepts a security regression (a hard floor). Code review, the task reviewer, and the completion gate now block security regressions by rule. Stated once in `using-superpowers`, referenced across the judgment and gate skills.

### Changed

- **Stress-test guidance is clearer and its attribution current.** The one-branch-at-a-time rule now says *why* questions go one at a time — batching is bewildering and dilutes each recommendation — and the skill credits mattpocock's current `grilling` skill (its old `grill-me` link became a launcher shim upstream).
- **The TodoWrite-free invariant is now single-sourced and self-tested.** One canonical `scripts/check-todowrite.sh` replaces four divergent copies of the gate (CI, both `CLAUDE.md` checks, `AGENTS.md`, and the audit skill all reference it); a new self-test proves the gate stays quiet on the tree *and* still catches a real prescriptive `TodoWrite`; and `getting-up-to-speed` gains a Phase-4 output-contract test so its terminal "I'm ready" contract can't be silently diluted. Fixes a latent CI false-positive on a legitimate anti-pattern line.
- **`document-release` now catches *missing* docs, not just stale ones.** A Diataxis coverage map audits new public surface (skills, commands, flags, endpoints, exported APIs) against reference/how-to/tutorial/explanation and flags real gaps; CHANGELOG entries get a 0–3 sell-test (What changed / Why care / How to use); architecture-diagram drift is flagged; documentation gaps become offered `docs-debt` beads; an empty-doc diff exits early without an empty commit; and the VERSION-scope check is now cadence-aware for repos that batch releases. Adapted from gstack, pure-Markdown, no binaries.
- **Stress-test is now offered at every approval gate.** The `brainstorming` spec-review and `writing-plans` plan-review gates include an "Approved + stress-test" option (listed first, recommended), so the optional adversarial design review is surfaced every time — not only when a design was judged "complex." Choose it to run `stress-test` on the spec or plan before continuing; plain "Approved" skips it.
- **`research-driven-development` now decomposes, verifies, and right-sizes its research.** Instead of handing the raw topic to a fixed pair of agents, it breaks the topic into sub-questions and dispatches one researcher each (each with an objective, output format, sources, and boundaries), scales the agent count to the question (a hard cap of 5), verifies every load-bearing claim against a verbatim source quote, tags each finding's confidence, and runs one capped gap-closing round when a claim rests on a single source. Grounded in a study of the most-adopted deep-research systems.
- **`getting-up-to-speed` now self-checks before it reports.** Orientation runs a copyable progress checklist and a pre-emit verification gate (every Current State line must trace to a command run this session — nothing invented), tags inferred findings with their source and a confidence glyph, summarizes uncommitted working-tree changes, runs a beads-vs-git continuity check that flags work shipped but left open, and adds a "Recent Activity" delta — so the current-state summary cites its evidence and surfaces drift. Stays read-and-emit (no cache).

## [0.7.1] - 2026-06-26

### Changed

- **Installation reframed around native per-CLI plugin install.** Native plugin install is now the primary, recommended path in the README and docs; `curl | bash` is documented as a scoped "scripted / advanced install" fallback (its unique roles: beads/Dolt bootstrap, hook registration for the npx/scripted path, optional `yegge.md` agent, version pinning via `--version`, and CI). The curl installer remains fully functional — behavior unchanged, only its framing.
- **Tiered platform support.** README and `docs/getting-started.md` now present a two-tier Supported Platforms table: **Verified** (Claude Code, Codex, OpenCode — install-tested) and **Best-effort / community** (Cursor, Gemini CLI, GitHub Copilot CLI), each Best-effort row stamped "community-verified, not tested by us — last reviewed 2026-06"; the long tail delegates to `npx skills add` + upstream's install list.
- **README restructured** to the upstream section order: Quickstart → How it works → Prerequisites → Installation → What's Inside (skills grouped by category) → Updating, with a prominent prerequisite note that native install does not bootstrap the beads/Dolt database (`brew install beads` → install plugin → `bd init`).
- `docs/index.md` now reflects the Verified/Best-effort tiers and links to Getting Started for per-platform install paths.
- **Full public-documentation audit + prose pass.** Every human-facing surface (README, all six docs-site pages, CONTRIBUTING, the example-workflow README) was run through the `write-documentation` checks for clarity and register, preserving all facts, install commands, and MkDocs macros. Stale references were corrected (CI release skill-count floor 15 → 22, PR-template count 20 → 22, `SECURITY.md` supported versions 0.6.x → 0.7.x, root `CLAUDE.md` version + cache paths 0.7.0 → 0.7.1), and the GitHub repository description and topics were refreshed.

### Added

- **`auditing-upstream-drift`:** registered CLI-only beads integration (direct `bd` CLI + one SessionStart `bd prime` hook; no beads Claude plugin or `beads-mcp` server) as a Known Deliberate Divergence.
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
- `subagent-driven-development` adopted upstream superpowers v6.0.3's review model (selectively). The two sequential reviewer prompts (`spec-reviewer-prompt.md` + `code-quality-reviewer-prompt.md`) are replaced by one read-only `task-reviewer-prompt.md` that returns a spec-compliance verdict (✅/❌/⚠️) and a code-quality verdict in a single pass. Added three pure-bash file-handoff scripts (`sdd-workspace`, `task-brief`, `review-package`) that pass task briefs, implementer reports, and review diffs as files under a per-worktree `.superpowers/sdd/` directory; a Pre-Flight Plan Review; a mandatory model-per-dispatch rule; a banned-coaching Red Flag; and a "cannot-verify-from-diff" handling section. Beads remains the durable ledger (the upstream markdown progress ledger was deliberately not adopted), and the Parallel Batch Mode (one `bd worktree` per task) is preserved.
- Skill vocabulary made vendor-neutral and the discovery concept renamed (from upstream superpowers v6.0.3) — "Claude Search Optimization (CSO)" is now "Skill Discovery Optimization (SDO)" across `writing-skills`, `docs/methodology.md`, `docs/skills.md`, and `CLAUDE.md`, and the generic-stand-in "Claude" prose in `writing-skills` and `docs/methodology.md` now reads as "agent"/"your agent" so the guidance fits any harness. Factual Claude Code platform references (built-in agent names, the `EnterWorktree` tool) are kept verbatim, the `writing-skills` SDO worked example restores "two-stage review process" so it stays internally consistent, and the `using-superpowers` Platform Adaptation note now lists all four reference tool-maps shipped (`codex`, `copilot`, `gemini`, `opencode`). The vendored `anthropic-best-practices.md` is left unchanged as cited Anthropic source material; baseline version bumps are deferred.
- `finishing-a-development-branch` PR/MR step is now forge-aware instead of GitHub-only — the "Create a Pull Request" option detects the forge from the `origin` remote and runs `gh pr create` for GitHub, `glab mr create` for GitLab, or prints an actionable "open via your forge's web UI" message otherwise (the PR body template is preserved). Worktree detection in `finishing-a-development-branch` and `using-git-worktrees` now canonicalizes git paths with `pwd -P`, so it classifies correctly when run from a subdirectory. These are selective cherry-picks from upstream superpowers v6.0.3; the `bd worktree` Iron Law and the Land-the-Plane session-close ritual are deliberately retained, and upstream's native-tool-first worktree selection (which would bypass beads-database sharing across worktrees) is **not** adopted — `using-git-worktrees` carries a note recording the divergence.
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
- Dynamic per-page "last updated" dates via `mkdocs-git-revision-date-localized-plugin` — dates sourced from git commit history, no hardcoding.
- Material theme footer restored — copyright, social links, and prev/next page navigation. The 0-byte `footer.html` override that suppressed the footer was removed.
- `mkdocs-panzoom-plugin` for Mermaid diagrams — Alt+scroll to zoom, Alt+drag to pan, fullscreen toggle. Replaces the custom panzoom implementation lost in the v0.5.2 MkDocs migration.
- Critical Rule #8 in `yegge.md`: always use `AskUserQuestion` for design choices with 2+ options — never present options as plain text.
- **Codex CLI plugin support** — `.codex-plugin/plugin.json` and `marketplace.json` mirror the Claude Code plugin manifest. `hooks/codex-hooks.json` references the same hook scripts via `${CODEX_PLUGIN_ROOT}`. Skills auto-discovered from plugin bundle.
- **OpenCode native TypeScript plugin** — `opencode/beads-superpowers-plugin.ts` provides 3 in-process hooks: session start (bd prime + skill injection), prompt reminders, and compaction resilience. Distributed via `install.sh`.
- **OpenCode tool mapping reference** — `skills/using-superpowers/references/opencode-tools.md` maps Claude Code tool names to OpenCode equivalents (subagent dispatch, environment detection).
- E2E tests for multi-CLI install/uninstall and hook format validation (6 scenarios: CC/Codex/generic × session-start/reminder).
- **3-tier fallback chain** in `install.sh` — tries plugin system (Claude Code/Codex marketplace) first, then `npx skills add`, then tarball download, then git clone. Each tier cleans up on failure before trying the next.
- **SHA-256 checksum validation** for tarball downloads — 3-tool fallback (`sha256sum` → `shasum` → `openssl`), on by default, `--skip-checksum` to bypass. `checksums.txt` published as a GitHub Release asset.
- **Atomic rollback** via staging directory — skills install to a temp dir first, only move to final location on complete success. No partial installs on failure.
- `BEADS_SUPERPOWERS_CHECKSUMS_URL` env var in `install.sh` — overrides the checksums.txt download URL for local testing.
- E2E tests for checksum validation (valid/corrupted/missing/skip), fallback chain (PATH stub-based tool hiding), atomic rollback (read-only target dir), and `bd` integration (hook JSON with bd in PATH).
- Claude Code CLI, `bd`, and `wget` added to E2E Docker test container.
- GitHub Action step in release workflow to generate and upload `checksums.txt` alongside release tarballs.
- **Upstream drift audit** — obra/superpowers v5.0.7→v5.1.0 and gastownhall/beads v1.0.2→v1.0.4.
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
