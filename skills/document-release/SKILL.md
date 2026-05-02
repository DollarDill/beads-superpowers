---
name: document-release
description: Use after code changes are committed but before PR merge to ensure all project documentation accurately reflects shipped code. Covers README, ARCHITECTURE, CONTRIBUTING, CHANGELOG, CLAUDE.md, TODOS, and VERSION files. Triggers on "update docs", "sync documentation", "post-ship docs", "document release", "documentation audit".
---

# Document Release: Post-Ship Documentation Update

> **Source:** Adapted from [garrytan/gstack](https://github.com/garrytan/gstack/tree/main/document-release) (Garry Tan)

**Announce at start:** "I'm using the document-release skill to audit and update project documentation."

Run after code changes are committed but before PR merge. Ensures all project documentation accurately reflects shipped code.

## Beads Integration

```bash
# Create a doc-update bead at start
bd create "Docs: update documentation for <branch>" -t chore

# Close with evidence at completion
bd close <id> --reason "Documentation updated: <summary of changes>"
```

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

### Step 1: Pre-flight and Diff Analysis
1. Verify you are on a feature branch (not base branch)
2. Gather what changed: `git diff <base>..HEAD` and `git log --oneline <base>..HEAD`
3. Discover all `.md` files: `find . -name '*.md' -not -path './.git/*' -not -path './.worktrees/*'`
4. Categorise changes: new features, behaviour changes, removals, infrastructure

### Step 2: Per-File Documentation Audit
Read each documentation file and cross-reference against the diff:

| File | What to Check |
|------|--------------|
| **README** | Features, install steps, examples, troubleshooting still valid? |
| **ARCHITECTURE** | Diagrams, component descriptions, design rationale still accurate? |
| **CONTRIBUTING** | Setup instructions work? Test tiers match reality? |
| **CLAUDE.md** | Project structure tree, commands, build/test steps current? |
| **CHANGELOG** | Entries present for all changes? Voice user-forward? |
| **Any other .md** | Purpose clear, contradictions with diff? |

Classify each update as **auto-update** (factual, obvious) or **ask-user** (narrative, ambiguous, risky).

### Step 3: Apply Auto-Updates
Make factual corrections directly. Each edit gets a specific one-line summary — not "updated README" but "README: added /new-skill to skills table, updated count 15 to 16".

### Step 4: Ask About Risky Changes
Use the `AskUserQuestion` tool for risky changes. Provide context, recommendation, and options.

### Step 5: CHANGELOG Voice Polish
**Critical rules:**
- Never clobber entries — polish wording only, preserve all content
- Use Edit tool with exact string matches — never use Write to overwrite CHANGELOG.md
- Ensure each bullet leads with what the user can *do*, not implementation details
- Flag commit-message-style entries for rewrite to user-forward language

### Step 6: Cross-Doc Consistency
1. Check README/CLAUDE.md/ARCHITECTURE alignment
2. Ensure every doc file is reachable from one entry point (README or CLAUDE.md)
3. Fix clear factual inconsistencies (e.g., version mismatch between files)

### Step 7: TODOS Cleanup
1. Mark completed items based on the diff
2. Update stale TODO descriptions
3. Ask whether inline code comments (`TODO`, `FIXME`, `HACK`) represent meaningful deferred work

### Step 8: VERSION Bump Decision
**Critical rule:** Never bump silently — always use `AskUserQuestion`.
- If VERSION was not bumped: ask whether to bump PATCH/MINOR or skip
- If VERSION was already bumped: verify scope coverage; ask if gaps exist
- Use `scripts/bump-version.sh` if available

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

6. Close the bead: `bd close <id> --reason "Documentation updated: <summary>"`

## Critical Rules

- **Read before editing:** Understand file content before modifying
- **Never clobber CHANGELOG:** Polish wording only. Use Edit with exact matches.
- **Never bump VERSION silently:** Always ask, even if already bumped
- **Be specific about changes:** Every edit gets a one-line summary
- **Discoverability:** Every doc file must be reachable from README or CLAUDE.md

If you discovered something reusable, capture it before closing:

```bash
# Only if worth preserving for future sessions:
bd remember "docs: <documentation pattern or gap found>"
```

## Integration

**Called by:**
- **finishing-a-development-branch** — RECOMMENDED before merge/PR options
- Any workflow where code has shipped and docs need updating

**Pairs with:**
- **verification-before-completion** — docs audit is part of completion verification
- **writing-plans** — plans reference doc locations that this skill validates
