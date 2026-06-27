---
name: memory-curator
description: Use at session-close (when the session produced several new memories) or on-demand to consolidate, deduplicate, and structure the beads memory store
---

# Memory Curator

## Overview

Turn a session's raw `bd remember` notes into well-structured, deduplicated, consolidated memories — and prune the growing pile — using the in-session agent. No runtime, no API key, no embeddings: just `bd` primitives over text the agent already has in context.

**Announce at start:** "I'm using the memory-curator skill to consolidate and structure the memory store."

**Scope is deliberate (ADR-0034, evidence-led split).** The proven levers are quality-gating, consolidation, and pruning — NOT structural richness. This skill does those. It does NOT build a graph, self-evolving links, a bi-temporal DB, or embeddings; richer-but-unproven structure is explicitly out of scope (the independent evidence shows naive memory growth hurts).

## When to Use

- **Offered at session-close** when the session produced curation-worthy volume (roughly 3+ new `bd remember` calls). Confirm-never-auto.
- **On-demand** for a heavier consolidation/prune sweep across the whole memory store: invoke `Skill(memory-curator)`.

## When NOT to Use

- Trivial sessions that captured 0–2 memories — not worth a pass.
- Mid-task — this runs at a clean stopping point, not while work is in flight.

## The Memory Schema (moderate, backward-compatible)

Keep existing key slugs and the established prefixes (`design:`, `root cause:`, `lesson:`, `research:`, …) — they already are a type system. Add one optional, greppable header line to the body:

```
@type=design @created=2026-06-28 @salience=4 @refs=rki7,2rbo @tags=memory,adr
<the existing self-contained fact body>
```

- `@type` — the existing prefix vocabulary (do NOT rename to CoALA types; that churns memories for no proven gain).
- `@created` — ISO date (recency signal).
- `@salience` — 1–5, best-effort (least-reliable field; don't over-invest).
- `@refs` — related bead IDs / memory keys (in-text link signal).
- `@tags` — lexical-filter signal.

These fields pay off **today**: the agent reading the `bd prime` dump can self-rank on them, and `bd memories <kw>` + `grep '^@type='` / `@salience=[45]` gives filtered recall now — independent of any upstream change. Keep the header to ONE compact line.

## The Algorithm (single pass)

Input: the session transcript (already in context) + `bd memories --json` (the full store). Output: a **reviewed** list of `bd remember` / `bd forget` commands.

**Phase 0 — Gather (no LLM).** Run `bd memories --json` for the full store. Record the pre-sweep Dolt state for rollback: `bd dolt status` (note the current state so a bad run can be reverted).

**Phase 1 — Extract (quality-gated + secrets-screened).** From the session, pull salient, self-contained, **date-grounded** facts; classify each by `@type`.

- **Evidence-bar gate (load-bearing):** store a fact as a durable memory ONLY if it carries checkable evidence per `verification-before-completion`'s Agent-Filed Bead Discipline (cited `file:line` / passing test / command output / closed bead). No evidence → drop it, or store as a low-`@salience` item the sweep prunes first. This is the same evidence test the project enforces on filed beads — not a self-graded "verified" (which would inherit the over-trust bias it is meant to filter).
- **Secrets rule (security, mandatory):** NEVER persist secrets, credentials, tokens, keys, or PII. Redact or skip — don't store it in the first place, because `bd prime` dumps memories into every future session and Dolt history outlives `bd forget`.
- Return nothing for unverified speculation or chatter.

**Phase 2 — Reconcile in-place** against the full store (no vector retrieval needed at this scale):

- **ADD** — new info absent from the store → `bd remember "<header line>\n<body>"`.
- **UPDATE** — same topic, more/merged info → `bd remember --key <existing-key>` (keep the key; merge so the result keeps the fact with the MOST information — never silently shrink a memory).
- **NONE** — already present → no command.

**Phase 3 — Consolidate (the only volume-reducer).** When a themed cluster of dated episodic memories can become one timeless semantic/procedural fact, synthesize it with in-text source citations (`@refs=`) and retire the cluster. This is what shrinks the pile.

**Phase 4 — Forget (invalidate-over-delete).** For a contradicted/superseded memory, prefer a soft tombstone — rewrite its body with a `[superseded YYYY-MM-DD by <key>]` prefix — over hard deletion (Dolt preserves history either way). Reserve hard `bd forget` for exact duplicates or true noise, and only with a cited reason.

## Safety: Propose-Then-Apply (HARD requirement)

This skill mutates the store that `bd prime` injects into EVERY future session, non-deterministically. A bad run corrupts the context layer invisibly. Therefore:

1. **Never mutate silently.** First emit the full planned command list — each ADD/UPDATE/FORGET/consolidate with a one-line reason — and get the user's confirmation before running ANY of it. The on-demand sweep is dry-run-first, always.
2. **Dolt-revert backstop.** You recorded the pre-sweep Dolt state in Phase 0; surface it so a bad run can be rolled back wholesale.
3. **Bounded destructive ops.** No hard `bd forget` without an exact-duplicate match or a cited supersede reason; default to soft-invalidate; UPDATE must preserve nuance.

## Phased Rollout (prove-it-first)

v1 leads with the **least-destructive** jobs — capture-enrichment + exact-duplicate dedup. Aggressive cross-cluster consolidation and pruning is a second gear: use it sparingly until the conservative pass has proven trustworthy on this repo (the dry-run review IS the validation loop). Watch the memory-count trend and spot-check that no true fact was lost. Do not chase memory benchmarks — they are gamed.

## Beads Integration

```bash
# At skill start
bd create "Memory curation: <session/sweep>" -t chore

# At completion (after the user approved + you applied the command list)
bd close <id> --reason "Curated: <N added, M updated, K consolidated, J forgotten>; pre-sweep Dolt state <ref>"
```

Only the orchestrating agent runs this skill (subagents skip `using-superpowers` via SUBAGENT-STOP). Coordinates with `getting-up-to-speed`, whose session-start `bd forget` is a lightweight orientation cleanup — this skill owns substantive curation.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll just apply the merges directly" | Never mutate silently. Propose the command list; the user confirms first. |
| "This memory is probably fine to store" | No cited evidence → it doesn't meet the bar. Drop or mark low-salience. |
| "I'll keep the shorter version on UPDATE" | UPDATE keeps the fact with the MOST information. Never silently shrink. |
| "A graph/links would be richer" | Out of scope (ADR-0034). Unproven + over-build risk. |
| "There might be a token in this fact, but it's internal" | Never persist secrets/PII. Redact or skip. |
| "Consolidating aggressively will shrink the pile fast" | Phased: enrich+dedup first; aggressive consolidation only once proven. |

## Integration

**Invoked by:**

- The orchestrator at session-close (offered when the session produced ≥~3 new memories) — see `finishing-a-development-branch` Step 7 and the Session Close Protocol.
- The user on-demand via `Skill(memory-curator)` for a full sweep.

**Pairs with:**

- **verification-before-completion** — supplies the evidence-bar the quality gate reuses.
- **getting-up-to-speed** — its session-start `bd forget` is lightweight cleanup; this skill owns curation.
- **finishing-a-development-branch** — hosts the conditional session-close offer.

> **Upstream dependency note (multiplier, not prerequisite):** ranked/selective surfacing (`bd prime` top-N) is owned by upstream beads. This skill delivers value with zero upstream changes (dedup/consolidate shrinks the dump by count); the `@type/@salience/@created` fields are also exactly what a future ranked `bd prime` would consume. Tracking: see the upstream feature-request bead.
