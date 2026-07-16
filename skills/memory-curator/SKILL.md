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
- **On-demand** — a full-store sweep: `Skill(beads-superpowers:memory-curator)`.

## When NOT to Use
- Sessions with 0–2 new memories — not worth a pass.
- Mid-task — run at a clean stopping point, not while work is in flight.

## Memory taxonomy
Two classes; **procedural** memory (how-to / workflow) lives in the **skills**, never the memory store.

- **semantic** — durable facts that stay true.
- **episodic** — time-bound records of what happened.

**The `@type` is the routing decision.** Classify once; the type deterministically sets store, injection, and lifecycle.

| `@type` | store | injected at session start? | lifecycle |
|---|---|---|---|
| `semantic:lesson` | memory | yes (salience≥4) | durable; consolidate near-dups |
| `semantic:root-cause` | memory | yes (salience≥4) | durable; consolidate |
| `semantic:pattern` | memory | yes (salience≥4) | durable; consolidate |
| `semantic:correction` | memory | yes | durable (supersedes a wrong memory) |
| `semantic:research` | **deferred knowledge-bead** | **no** | deferred bead; pointer to a research doc (`metadata.doc`); `bd supersede` on replacement |
| `semantic:design` | **deferred knowledge-bead** | **no** | deferred bead; pointer to an ADR/spec (`metadata.doc`); `bd supersede` on replacement |
| `semantic:decision` | **deferred knowledge-bead** | **no** | deferred bead; pointer to an ADR (`metadata.doc`); `bd supersede` on replacement |
| `episodic:continuation` | memory | latest only | supersede on next |
| `episodic:done` / `cleanup` / `review` | memory → retire | no | consolidate into a semantic fact, then drop; age-out (>30d) safety net |

**Crisp routing definitions (the boundary that keeps determinism honest):**
- `research` / `design` / `decision` = a **pointer** whose detail lives in a doc/ADR you would re-open when relevant. Injecting it every session wastes context — route to a deferred knowledge-bead (§ Beads-native knowledge store).
- `lesson` / `root-cause` / `pattern` / `correction` = a **standalone, actionable rule** you want surfaced *unprompted* so you don't repeat a mistake (e.g. "bd worktree default path is ./<name>, not .worktrees/"). Stays an injected memory.
- **Escape hatch:** if a research/design item is genuinely a standalone reusable rule, classify it as a `lesson`/`pattern` — you change the *type*, never the store directly.

Map a non-canonical prefix to the nearest canonical subtype — e.g. `stress-test`/`plan-stress-test`→`design`,
`bug`→`root-cause`, `sdd`→`lesson`, `upstream`→`research`, `docs`→`pattern`. If none fits, ask — don't
invent. If an extracted "memory" is really procedural, flag it for a skill — don't store it.

## Memory header
Every memory keeps its existing key and carries one greppable header line:

```
@type=semantic:lesson @created=2026-06-28 @salience=4 @refs=<bead-id>,<memory-key> @tags=memory,curation
<self-contained fact body>
```

- `@type` — `<class>:<subtype>` from the taxonomy — the subtype sets store/injection/lifecycle per the taxonomy table above. `@created` — ISO date. `@salience` — 1–5, best-effort.
  `@refs` — related bead IDs / memory keys. `@tags` — lexical filter.

The class makes the prune signal greppable (`bd memories | grep '@type=episodic:'`);
`@salience`/`@tags` filter recall.

## Beads-native knowledge store

Reference-class memories (`research`/`design`/`decision`) live as **deferred knowledge-beads**, not in `memory.` — a deferred bead is never auto-injected at session start, so pointers stay out of every session's context but keep persistence + Dolt sync.

- **Bead:** `status=deferred` with a far-future `--defer 2099-01-01` — never `closed` (closed beads are GC-deleted at 90d). `issue_type` matches the subtype (`research`/`design`/`decision`); every knowledge-bead also carries the class-marker label `kb` plus 1–3 topic labels from the controlled vocabulary (`scripts/kb-label-vocab.txt`).
- **Body:** the research doc / ADR stays on disk as the source of truth; the bead is the queryable index/pointer via `metadata.doc` (display-only), with a one-line summary as the description:

  ```bash
  printf '%s' "<distilled summary: what this note establishes>" | \
  bd create "<one-line summary>" -t <research|design|decision> -l kb,<topic-labels> \
    --defer 2099-01-01 --metadata "$(jq -nc --arg d "<doc-path>" '{doc:$d}')" --body-file - --silent
  ```

- **Retrieval:** `bd list --label <topic> --status all` (topic) and `bd search "<kw>" --status all` (keyword) — never metadata filters (broken in `bd`), never `find-duplicates`.
- **Lifecycle:** `bd supersede <old> --with <new>` on replacement — the superseded bead closes and decays; the live pointer stays deferred.
- **Move-out invariant (curator route step):** write the deferred knowledge-bead → **verify** (`bd show <id>` returns it) → **then** `bd forget` the memory. Never forget first. Existence-check before writing (idempotent re-run). Run the secret/PII scan on the body first — **flag for removal, never relocate** a secret into a bead.
- **Aging path:** a cooled injected memory (low `@salience`, or superseded) can retire into a deferred knowledge-bead too, not just a tombstone — same move-out invariant above (write → verify → `bd forget`), never a copy left behind in both stores.

## The sweep
One pass. Input: the session (in context) + `bd memories --json`. Output: a **reviewed** list of
`bd remember` / `bd forget` commands. Propose least-destructive changes first (enrich + exact-duplicate
dedup); cross-cluster consolidation and pruning come after, and only where clearly safe.

1. **Gather** — `bd memories --json` for the full store; `bd dolt status` to record the pre-sweep
   state for rollback.
   Done when: the full memory list and the pre-sweep Dolt state are both captured.
2. **Extract** — pull salient, self-contained, date-grounded facts; classify each by the taxonomy and
   normalize its `@type` to `class:subtype` (correcting any malformed `@type` it encounters). Store a
   fact ONLY if it carries checkable evidence (cited `file:line`,
   passing test, command output, closed bead) — the same bar as Agent-Filed Bead Discipline in
   `verification-before-completion`. No evidence → drop, or store at low `@salience`. Procedural how-to
   → flag for a skill, don't store. **Never persist secrets, credentials, tokens, keys, or PII** — the session hook
   injects curated memories into every future session (the full store via `bd prime`) and Dolt history outlives `bd forget`.
   Done when: every extracted item carries a normalized `@type` and is evidence-backed, low-salience, dropped, or flagged for a skill.
3. **Reconcile** — ADD new facts; UPDATE a same-topic memory in place with `bd remember --key <existing>`,
   merging so the result keeps the MOST information (never silently shrink); skip what's already present.
   Done when: every extracted fact is added, merged, or skipped.
4. **Consolidate** — collapse a themed cluster of **episodic** memories into one timeless **semantic**
   fact with `@refs` to its sources, then retire the cluster. The only step that shrinks the pile.
   Extract a record's durable content into a semantic memory BEFORE retiring it — never drop an episodic
   record that still holds an un-consolidated fact.
5. **Forget** — soft-tombstone a superseded memory (`[superseded YYYY-MM-DD by <key>]`) rather than
   delete — Dolt keeps history either way, and a tombstone is reversible if the supersede was wrong.
   Episodic records are the prune-first *candidates*, but never retire the most-recent `continuation` /
   active handoff. Reserve hard `bd forget` for exact duplicates or true noise, with a cited reason.

## Iron rule: propose, then apply
This mutates the store injected into every future session (curated by the session hook, in full via
`bd prime`) — a bad run corrupts the context layer invisibly. So:

- Emit the full planned command list — every ADD / UPDATE / CONSOLIDATE / FORGET with a one-line reason —
  and get the user's approval before running ANY of it. The on-demand sweep is dry-run-first, always.
- Surface the pre-sweep Dolt state (step 1) as the rollback path.
- No hard `bd forget` without an exact-duplicate match or a cited supersede reason.

## Red Flags
| Thought | Reality |
|---------|---------|
| "I'll just apply the merges" | Propose the list; the user approves first — never mutate silently. |
| "This memory is probably fine to store" | No cited evidence → it doesn't meet the bar. Drop or low-salience. |
| "There might be a token in here, but it's internal" | Redact or skip. Never persist secrets/PII. |

## Beads Integration
```bash
bd create "Memory curation: <session/sweep>" -t chore
# after the user approved + you applied:
bd close <id> --reason "Curated: <N added, M updated, K consolidated, J forgotten>; pre-sweep Dolt <ref>"
```
Run this as the session/ledger-owning agent; a dispatched single-task subagent does not.

## Integration
**Invoked at:** session-close (offered when a session produced ~3+ new memories —
see `finishing-a-development-branch` Step 7) and on-demand by the user.
**Pairs with:** `verification-before-completion` (supplies the evidence bar) and `getting-up-to-speed`
(its session-start `bd forget` is lightweight cleanup; this skill owns curation).

Memories arrive header-less from other skills; the curator assigns `@type` on contact. Do not add
`@type` emission to other skills — header-less-until-curated is the intended state.
