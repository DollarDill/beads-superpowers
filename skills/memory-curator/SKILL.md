---
name: memory-curator
description: Use at session-close when a session captured several new memories, or on-demand, to consolidate, deduplicate, prune, and structure the beads memory store. Triggers on "curate memories", "clean up memories", "memory sweep".
---

# Memory Curator

Turn a session's raw `bd remember` notes into deduplicated, consolidated, well-structured
memories — and prune the pile — using `bd` over text already in context. No runtime, no embeddings.

**Announce at start:** "I'm using the memory-curator skill to consolidate and structure the memory store."

## When to Use
- **Session-close** — when the session produced ~3+ new `bd remember` calls. Offered, never automatic.
- **On-demand** — a full-store sweep: `Skill(memory-curator)`.

## When NOT to Use
- Sessions with 0–2 new memories — not worth a pass.
- Mid-task — run at a clean stopping point, not while work is in flight.

## Memory taxonomy
Two classes; **procedural** memory (how-to / workflow) lives in the **skills**, never the memory store.

- **semantic** — durable facts that stay true. Subtypes: `design`, `lesson`, `pattern`, `decision`,
  `root-cause`, `research`, `correction`. The durable keep.
- **episodic** — time-bound records of what happened. Subtypes: `done`, `continuation`, `cleanup`,
  `review`. Consolidate and retire as they age; a cluster often distills into one semantic fact.

Map a non-canonical prefix to the nearest canonical subtype — e.g. `stress-test`/`plan-stress-test`→`design`,
`bug`→`root-cause`, `sdd`→`lesson`, `upstream`→`research`, `docs`→`pattern`. If none fits, ask — don't
invent. If an extracted "memory" is really procedural, flag it for a skill — don't store it.

## Memory header
Every memory keeps its existing key and carries one greppable header line:

```
@type=semantic:lesson @created=2026-06-28 @salience=4 @refs=<bead-id>,<memory-key> @tags=memory,curation
<self-contained fact body>
```

- `@type` — `<class>:<subtype>` from the taxonomy. `@created` — ISO date. `@salience` — 1–5, best-effort.
  `@refs` — related bead IDs / memory keys. `@tags` — lexical filter.

One line. The class makes the prune signal greppable (`bd memories | grep '@type=episodic:'`);
`@salience`/`@tags` filter recall.

## The sweep
One pass. Input: the session (in context) + `bd memories --json`. Output: a **reviewed** list of
`bd remember` / `bd forget` commands. Propose least-destructive changes first (enrich + exact-duplicate
dedup); cross-cluster consolidation and pruning come after, and only where clearly safe.

1. **Gather** — `bd memories --json` for the full store; `bd dolt status` to record the pre-sweep
   state for rollback.
2. **Extract** — pull salient, self-contained, date-grounded facts; classify each by the taxonomy and
   normalize its `@type` to `class:subtype` (fixing stray `type-*` keys and any leaked `class:subtype`
   placeholder on contact). Store a fact ONLY if it carries checkable evidence (cited `file:line`,
   passing test, command output, closed bead) — the same bar as Agent-Filed Bead Discipline in
   `verification-before-completion`. No evidence → drop, or store at low `@salience`. Procedural how-to
   → flag for a skill, don't store. **Never persist secrets, tokens, or PII** — `bd prime` injects every
   memory into future sessions and Dolt history outlives `bd forget`.
3. **Reconcile** — ADD new facts; UPDATE a same-topic memory in place with `bd remember --key <existing>`,
   merging so the result keeps the MOST information (never silently shrink); skip what's already present.
4. **Consolidate** — collapse a themed cluster of **episodic** memories into one timeless **semantic**
   fact with `@refs` to its sources, then retire the cluster. The only step that shrinks the pile.
   Extract a record's durable content into a semantic memory BEFORE retiring it — never drop an episodic
   record that still holds an un-consolidated fact.
5. **Forget** — soft-tombstone a superseded memory (`[superseded YYYY-MM-DD by <key>]`) rather than
   delete — Dolt keeps history either way, and a tombstone is reversible if the supersede was wrong.
   Episodic records are the prune-first *candidates*, but never retire the most-recent `continuation` /
   active handoff. Reserve hard `bd forget` for exact duplicates or true noise, with a cited reason.

## Iron rule: propose, then apply
This mutates the store `bd prime` injects into every future session — a bad run corrupts the context
layer invisibly. So:

- Emit the full planned command list — every ADD / UPDATE / CONSOLIDATE / FORGET with a one-line reason —
  and get the user's approval before running ANY of it. The on-demand sweep is dry-run-first, always.
- Surface the pre-sweep Dolt state (step 1) as the rollback path.
- No hard `bd forget` without an exact-duplicate match or a cited supersede reason.

## Red Flags
| Thought | Reality |
|---------|---------|
| "I'll just apply the merges" | Never mutate silently. Propose the list; the user approves first. |
| "This memory is probably fine to store" | No cited evidence → it doesn't meet the bar. Drop or low-salience. |
| "I'll keep the shorter version on UPDATE" | UPDATE keeps the MOST information. Never silently shrink. |
| "Consolidate hard to shrink fast" | Lose no distinct fact; extract durable content to semantic first, then retire. |
| "Episodic, so safe to drop" | Never retire the latest continuation/handoff; soft-tombstone, never hard-delete. |
| "There might be a token in here, but it's internal" | Never persist secrets/PII. Redact or skip. |

## Beads Integration
```bash
bd create "Memory curation: <session/sweep>" -t chore
# after the user approved + you applied:
bd close <id> --reason "Curated: <N added, M updated, K consolidated, J forgotten>; pre-sweep Dolt <ref>"
```
Only the orchestrating agent runs this (subagents skip `using-superpowers`).

## Integration
**Invoked by:** the orchestrator at session-close (offered when a session produced ~3+ new memories —
see `finishing-a-development-branch` Step 7) and the user on-demand.
**Pairs with:** `verification-before-completion` (supplies the evidence bar) and `getting-up-to-speed`
(its session-start `bd forget` is lightweight cleanup; this skill owns curation).

Memories arrive header-less from other skills; the curator assigns `@type` on contact. Do not add
`@type` emission to other skills — header-less-until-curated is the intended state.
