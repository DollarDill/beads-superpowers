---
name: document-release
description: Use when implementation on a branch is complete and it is about to be merged or PR'd — or when finishing-a-development-branch reaches its docs-audit gate — and after code changes are committed, to ensure all project documentation accurately reflects shipped code. Covers README, ARCHITECTURE, CONTRIBUTING, CHANGELOG, CLAUDE.md, TODOS, and VERSION files. Triggers on "update docs", "sync documentation", "post-ship docs", "document release", "documentation audit".
---

# Document Release: Post-Ship Documentation Update

<!-- Adapted from garrytan/gstack document-release (MIT). Attribution: README "Built on". -->

**Announce at start:** "I'm using the document-release skill to audit and update project documentation."

Run after code changes are committed but before PR merge. Ensures all project documentation accurately reflects shipped code.

## Beads Integration

```bash
# Create a doc-update bead at start
bd create "Docs: update documentation for <branch>" -t chore
```

Closed with evidence at Step 9 — the single source of truth for the close command.

## Key Operating Principles

**Automation with guardrails:** Make obvious factual corrections automatically (path updates, version numbers, table additions) but pause for subjective decisions (narrative changes, security model updates, large rewrites, version bumps).

**Auto-update (apply without asking):**
- Factual corrections derived directly from the diff
- Adding items to existing lists and tables
- Updating file paths, counts, and version numbers
- Fixing stale cross-references between documents
- Minor CHANGELOG wording polish (preserving all content)
- Marking TODOs as complete

**Always ask before:**
- Narrative or philosophy changes
- Removing any section
- Security model rewrites
- Large rewrites (10+ lines in one section)
- VERSION bumps
- New TODO items

## Audit Methodology (9-Step Process)

### Step 0: Platform Detection
Detect git platform (GitHub/GitLab/unknown) and determine the base branch. Use `gh`/`glab` if available, fall back to git-native commands.

Done when: the platform and base branch are both determined.

### Step 1: Pre-flight and Diff Analysis
1. Verify you are on a feature branch (not base branch)
2. Gather what changed: `git diff <base>..HEAD` and `git log --oneline <base>..HEAD`
3. Discover all `.md` files: `find . -name '*.md' -not -path './.git/*' -not -path './.worktrees/*'`
4. Categorise changes: new features, behaviour changes, removals, infrastructure

Done when: the diff is gathered, all `.md` files are discovered, and every change is categorised.

### Step 1.5: Coverage Map (Diataxis Blast-Radius Audit)

Catches **missing** docs (shipped public surface that was never documented) — the per-file audit (Step 2) only catches **stale** docs.

1. **Extract new public surface** from `git diff <base>..HEAD`. "Public surface" is whatever the project exposes to users — a general superset, not any one project type:
   - **Apps:** new API endpoints, CLI flags, config keys, env vars.
   - **Libraries:** new exported functions, classes, public types.
   - **Tools / plugins:** new skills, user-facing commands, hooks, manifest fields, install flags.
   - …plus any renamed or removed surface in the above.
2. **Grid each item against the four Diataxis quadrants** (definitions are generic; the doc targets in parentheses are *examples*, never a hardcoded file list):
   - **Reference** — factual descriptions, signatures, option lists (README tables, AGENTS.md lists)
   - **How-to** — task-oriented guidance (README examples, CONTRIBUTING workflows)
   - **Tutorial** — step-by-step learning paths (getting-started guides)
   - **Explanation** — rationale and design reasoning (ARCHITECTURE, design docs, ADRs)

   ```text
   <entity>     reference  how-to  tutorial  explanation
   <entity-1>   yes        no      no        no
   <entity-2>   yes        yes     no        no
   ```
3. **Calibrate gaps (avoid alert-fatigue).** The grid *shows* all four cells, but only **judgment-confirmed gaps** become debt: a new user-facing surface with **zero** coverage anywhere, OR missing the **one quadrant that surface type genuinely needs** (e.g. a new flag with no Reference; a new workflow with no How-to). Tutorial/Explanation are flagged only when the change is significant enough to warrant them. An empty cell the entity genuinely doesn't need is **not** a gap.
4. **Guardrail — informs, never generates.** The coverage map flags gaps for beads + the PR body; it does **not** auto-write doc pages. Point real gaps at the **`write-documentation`** skill as the follow-up.
5. **Diagram-drift sub-check (flag-only).** Scope to **entity-bearing diagrams** — architecture / component / data-flow diagrams whose labels name code entities (e.g. `ARCHITECTURE.md`, or `docs/*.md` Mermaid). Extract entity names, cross-reference the diff, and flag any the diff **renamed or removed**. Prose/workflow flowcharts (e.g. process `dot` graphs) are in scope only when a renamed skill/command/step is itself the label. Never auto-edit a diagram.
6. **Empty-check gate (conservative early exit).** After building the coverage map, if the diff is **unambiguously doc-irrelevant** — both (a) `git diff <base>..HEAD --name-only -- '*.md'` is empty (zero docs changed) **and** (b) the coverage map found **no** new user-facing surface — emit "All documentation is up to date" and exit without an empty commit. **When in doubt, do not exit — run the full audit (Steps 2–9).** A false-skip would ship undocumented surface (the failure this skill exists to prevent), which is strictly worse than a redundant audit.

Done when: every new public-surface item is grid-checked against the four quadrants, or the empty-check gate confirms the diff is doc-irrelevant.

### Step 2: Per-File Documentation Audit
Read each documentation file and cross-reference against the diff:

| File | What to Check |
|------|--------------|
| **README** | Features, install steps, examples, troubleshooting still valid? |
| Pinned Discussions post | Front-door claims (contribute/contact/links) still true? Body stays evergreen — no versions or counts. |
| **ARCHITECTURE** | Diagrams, component descriptions, design rationale still accurate? |
| **CONTRIBUTING** | Setup instructions work? Test tiers match reality? |
| **CLAUDE.md** | Project structure tree, commands, build/test steps current? |
| **CHANGELOG** | Entries present for all changes? Voice user-forward? |
| **Any other .md** | Purpose clear, contradictions with diff? |

Classify each update as **auto-update** (factual, obvious) or **ask-user** (narrative, ambiguous, risky).

Done when: every documentation file is read and each needed update is classified auto-update or ask-user.

### Step 3: Apply Auto-Updates
Make factual corrections directly. Each edit gets a specific one-line summary — not "updated README" but "README: added /new-skill to skills table, updated count 15 to 16".

Done when: every Step 2 auto-update is applied, each with a one-line summary.

### Step 4: Ask About Risky Changes
Use your structured question tool for risky changes. Provide context, recommendation, and options.

### Step 5: CHANGELOG Voice Polish
**Critical rules:**
- Never clobber entries — polish wording only, preserve all content
- Use Edit tool with exact string matches — never use Write to overwrite CHANGELOG.md
- Ensure each bullet leads with what the user can *do*, not implementation details
- Flag commit-message-style entries for rewrite to user-forward language
- Strip internal references — human-facing CHANGELOG/README entries do NOT carry `ADR-NNNN` or `bd-xxxx` tags. Those belong in commit messages and `docs/decisions/` (gitignored, invisible to readers); in reader-facing prose they are noise pointing at nothing. Describe the change, not its tracking ID.

**Sell-test (0–3 rubric).** Score each entry — this scoring always applies:

- **+1 What changed** — names the specific feature/fix
- **+1 Why care** — user impact or pain removed
- **+1 How to use** — a command, flag, or link

Thresholds: **<2 → rewrite** the entry; **3 → gold** (preserve as-is or minor wording only). Lead with what the user can now *do* ("You can now…"), not "Refactored…".

**Optional contributor split (format-compatible).** Only when a project keeps developer-only notes (migration steps, deprecation) in its CHANGELOG, move them to a clearly-separated sub-list — at a heading level/placement that respects the project's existing convention. For **Keep a Changelog** (the common case), that is a nested bullet or sub-list, **never** a competing `###` that collides with the `### Added/Changed/Fixed` level. The rubric never restructures a CHANGELOG to force the split — it stays Edit-only (polish, never clobber or regenerate).

Done when: every CHANGELOG entry is scored, and any entry scoring below 2 is rewritten without clobbering existing content.

### Step 6: Cross-Doc Consistency
1. Check README/CLAUDE.md/ARCHITECTURE alignment
2. Ensure every doc file is reachable from one entry point (README or CLAUDE.md)
3. Fix clear factual inconsistencies (e.g., version mismatch between files)

Done when: README/CLAUDE.md/ARCHITECTURE alignment is checked and every factual inconsistency found is fixed.

### Step 7: TODOS Cleanup
1. Mark completed items based on the diff
2. Update stale TODO descriptions
3. Ask whether inline code comments (`TODO`, `FIXME`, `HACK`) represent meaningful deferred work

Done when: completed items are marked, stale descriptions are updated, and inline TODO/FIXME/HACK comments are triaged.

### Step 8: VERSION Bump Decision
**Critical rule:** Never bump silently — always ask via your structured question tool. A skipped, dismissed, or auto-resolved answer is not consent — stop and ask in plain text.
- **If already bumped:** verify the bump scope matches the shipped changes via a structured question — A) bump is correct → proceed; B) too conservative → escalate to user; C) too aggressive → escalate. A feature-A bump must not silently absorb feature-B.
- **If not bumped:** ask whether to bump PATCH/MINOR — and accept **"this project batches releases → record under `[Unreleased]`, defer the bump to release time"** as a first-class, no-friction answer. Do not nag for a per-PR bump on repos that deliberately batch. Never bump silently either way.
- Use `scripts/bump-version.sh` if available. (Note: it may not sync every prose mention of the version — e.g. root `CLAUDE.md` — so spot-check after a real bump.)

Done when: a bump verdict — proceed, escalate, PATCH/MINOR, or an explicit defer-to-release-time — is confirmed via the structured question tool.

### Step 9: Commit and Output
1. Stage modified doc files by name (never `git add -A`)
2. Create a single commit: `docs: update project documentation (bd-<id>)`
3. Push to the branch
4. Update the PR body with a `## Documentation` section if PR exists
5. Output a health summary table:

```
| File | Status | Changes |
|------|--------|---------|
| README.md | ✅ Updated | Added new skill to table |
| CLAUDE.md | ✅ Current | No changes needed |
| CHANGELOG.md | ✅ Polished | Voice improvements |
```

6. **Documentation Debt (from the Step 1.5 coverage map).** For each judgment-confirmed gap, **offer** a bead (do not auto-create — consistent with "ask before new TODO items"), stamped per **Agent-Filed Bead Discipline** (`beads-superpowers:verification-before-completion`): `bd create "docs-debt: <entity> missing <quadrant>" -t chore -p 3 --notes "Severity:/Confidence:/Evidence:"`. Before creating, **check for an existing open `docs-debt` bead for the same entity** (`bd find-duplicates`, or `bd list --status=open | grep docs-debt`) and skip duplicates so the ledger doesn't fill with re-filed gaps. If a PR exists, also append the lightweight always-available form to the PR body:

   ```text
   ### Documentation Debt
   - ⚠️ `<entity>` — reference present, no how-to example
   - 🗂️ <diagram file> — "FooProcessor" renamed to "BarProcessor" in code, diagram may be stale
   ```

   This informs reviewers and backlog prioritisation; it does not block the PR.
7. **(Optional) Cross-model doc review.** For a high-stakes release, you may optionally dispatch a documentation-review subagent via the **`requesting-code-review`** skill to check the docs against the shipped diff. No external binaries — this reuses the existing review pattern.
8. Close the bead: `bd close <id> --reason "Documentation updated: <summary>"`

Done when: the doc commit is pushed, the health summary is output, and the bead is closed with evidence.

## Critical Rules

- **Read before editing:** Understand file content before modifying
- **Never clobber CHANGELOG:** Polish wording only. Use Edit with exact matches.
- **Never bump VERSION silently:** Always ask, even if already bumped
- **Be specific about changes:** Every edit gets a one-line summary
- **Discoverability:** Every doc file must be reachable from README or CLAUDE.md
- **Coverage map informs, never generates:** flag gaps for beads/PR body; never auto-write doc pages (point gaps at `write-documentation`). Diagram-drift is flag-only — never auto-edit a diagram.
- **Never early-exit without the coverage map:** the Step 1.5 empty-check may exit only after the coverage map confirms zero new public surface AND zero `.md` changed. When in doubt, run the full audit — a false-skip ships undocumented surface.
- **Offer doc-debt, don't auto-create:** present coverage gaps; create `docs-debt` beads only on confirmation, and dedupe against existing open ones.

**Capture what you learned.** At close, record durable, evidence-backed insights (still true next month, tied to a file, test, or command). Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## Integration

**Called by:**
- **finishing-a-development-branch** — its Step 3.5 docs-audit gate invokes this skill before merge/PR options
- Any workflow where code has shipped and docs need updating

**Pairs with:**
- **verification-before-completion** — docs audit is part of completion verification
- **writing-plans** — plans reference doc locations that this skill validates
- **write-documentation** — complementary; document-release syncs existing docs to shipped code, write-documentation handles writing or rewriting prose
