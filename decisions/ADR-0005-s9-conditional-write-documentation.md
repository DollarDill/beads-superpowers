# ADR-0005: S9 Conditional write-documentation Invocation Alongside document-release

**Date:** 2026-05-03
**Status:** Accepted
**Deciders:** Dillon Frawley

## Context

S9 (DOCUMENT_RELEASE) in the yegge.md FSM invokes only `Skill(document-release)`. The write-documentation skill is designed to fire when prose needs writing or major rewriting, but has zero FSM presence — it is the only hook-triggered skill with no named state.

Both skills already define complementary boundaries in their Integration sections:
- document-release: "write-documentation handles writing or rewriting prose"
- write-documentation: "Rewriting a section flagged by document-release as needing major revision" (When to Use) and "document-release work that is factual syncing, not prose rewriting" (When NOT to Use)

The `example-workflow/README.md` already shows the intended design (`S9: DOCUMENT → Skill(write-documentation) + Skill(document-release)`) but the FSM in yegge.md was never updated.

## Decision

1. **Rename S9** from `DOCUMENT_RELEASE` to `DOCUMENT` to reflect the broader scope.
2. **Conditional invocation:** Always invoke `Skill(document-release)` (mandatory). If the audit flags major prose rewrites (10+ lines in one section), conditionally invoke `Skill(beads-superpowers:write-documentation)` for flagged sections.
3. **Shared bead:** write-documentation does NOT create its own bead when fired within S9. It shares the document-release bead to avoid two beads for one FSM state.
4. **Docs pages deferred:** Updates to `docs/workflow.md`, `docs/methodology.md`, and `docs/skills.md` are tracked as separate beads under a docs epic.

## Rationale

- **Option B (conditional) over sequential:** Avoids overhead on simple audits. write-documentation fires only when its value is highest.
- **Matches existing FSM patterns:** S7 already has conditional logic (simple → TDD, non-trivial → SDD). S9 follows the same pattern.
- **No skill-to-skill coupling:** The orchestrator makes the decision, not the skills. Consistent with "only the orchestrating agent manages workflow."
- **State rename:** Aligns yegge.md with what README.md already documents, and reflects that S9 now encompasses two skills.
- **Shared bead:** Keeps beads ledger clean — one FSM state, one bead.

## Consequences

- yegge.md S9 row, triage table, and workflow summary must be updated (3 locations in 1 file).
- Neither skill's SKILL.md needs changes — Integration sections already describe the relationship correctly.
- Docs pages need separate updates (deferred to docs epic).
- The 10-line threshold for invoking write-documentation matches document-release's existing "ask before" threshold — no new judgment call needed.
