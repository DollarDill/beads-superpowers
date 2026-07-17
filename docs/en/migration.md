---
description: Move a project's scattered knowledge — ADR directories, design docs, research notes, wikis, kv stashes, oversized memory stores — into the beads-native knowledge store, one phase with checkable exit criteria at a time.
---

# Migrating your knowledge into beads

Most projects accumulate knowledge faster than they can find it again. The decisions land in an ADR directory, the investigations in research notes, the design rationale in specs and wiki pages, and a pile of reference notes in whatever key-value or memory store was handy. Each store has a strong write path and no read path — nothing pulls the right note up at the moment you need it, so the knowledge is technically saved and practically lost.

This page is the playbook for moving that knowledge into the beads-native knowledge store the plugin builds on: one deferred bead per reference item, retrieved by label at decision time, synced with your beads database instead of rotting on one machine. It is written for a developer running this plugin on their own repo. The guidance is generic; this repo's own migration runs alongside as the worked example.

One boundary up front, because it decides what you even touch: this is a migration for **reference knowledge** — decisions, research, and design rationale you would re-open when a related choice comes up. It is not for the injected working memories (`lesson`, `pattern`, `root-cause`, `correction`) that surface unprompted every session. Those stay exactly where they are. Phase 0 draws that line precisely.

The work runs in six phases. Each ends on exit criteria you can check before moving on.

```mermaid
---
config:
  flowchart:
    nodeSpacing: 60
    rankSpacing: 55
---
graph LR
  P0["0 · Principles"] --> P1["1 · Per-repo setup"]
  P1 --> P2["2 · Inventory"]
  P2 --> P3["3 · Migrate"]
  P3 --> P4["4 · Wire & verify"]
  P4 --> P5["5 · Lifecycle"]

  style P0 fill:#6366f1,color:#fff
  style P3 fill:#22c55e,color:#000
  style P5 fill:#f59e0b,color:#000
```

## Phase 0 — Principles

Four ideas decide whether the store is worth building. Get them wrong and you rebuild it later; this repo dodged one such mistake at the last minute and had to rework another, and the evidence box at the end of the phase is why.

### Knowledge lives in the description

The knowledge goes **in the bead's description** — a self-contained distillation of half a kilobyte to two and a half: the finding or decision, the evidence for it, and the consequences. A file path in `metadata.doc` is an optional deep-dive pointer, not the payload. The reason is sync: bead descriptions travel with your Dolt history to every machine, while the doc corpora they point at are usually gitignored or per-machine. A bead whose description is a one-line pointer carries nothing across the boundary that matters.

Size is not the constraint. A 256 KB description round-trips byte-for-byte, far above anything you would write. The real limit is retrieval economics — what a reader can usefully take in when the bead surfaces — which is what fixes the target at 0.5–2.5 KB rather than a storage ceiling.

### The deferred store model

Each reference item is one bead, held in a shape chosen to persist quietly and never intrude:

- `status=deferred` with a far-future `defer_until` (this repo uses `2099-01-01`). Deferred beads are garbage-collection-safe: `bd gc`, `bd prune`, and `bd admin compact` all target *closed* beads, not deferred ones.
- Hidden from `bd ready`, so the store never clutters your active work.
- Typed `decision`, `research`, or `design`.
- Labeled with the class marker `kb` plus one to three topic labels.

### Labels are the only query axis

You retrieve by topic label, by keyword, or by body substring — and nothing else is reliable:

```bash
bd list --label <topic> --status all      # by topic
bd search "<keyword>" --status all        # by keyword (titles only)
bd list --label kb --status all --desc-contains "<term>"   # by body term
bd show <id1> <id2>                       # then read the hits — bodies, not titles
```

Bead metadata is display-only — filtering on a `metadata` field returns nothing — so the topic labels *are* the index. That is why the vocabulary you author in Phase 1 carries so much weight, and why labels get the heaviest human review in Phase 3.

### The injected-memory boundary

Reference knowledge is one tier; injected working memory is another. Lessons, patterns, root causes, and corrections stay in `bd memories`, where the session-start hook surfaces them unprompted. Do **not** migrate them into the deferred store — moving them would drop them out of injection, which is the whole point of that tier. The store is for the notes you look up deliberately, not the rules you want handed to you.

!!! example "In this repo — the closed-status near-miss"
    The first design stored each knowledge-bead as `closed`. Closed beads are exactly what `bd gc` (decay default: 90 days), `bd prune`, and `bd admin compact` delete, so the whole store would have quietly emptied within about three months. A pre-build stress-test caught it against a scratch database; `deferred` with a far-future date is the status that survives.

!!! example "In this repo — the thin one-liner"
    The first pass at indexing the research docs created one bead per document whose description was a single line — 125 characters on average, a table of contents rather than the knowledge. A second pass rewrote them as full distillations averaging about 1,500 characters. The shape rule above exists because the thin version looked done and retrieved nothing.

**Exit criteria.** This phase is done when:

- [ ] You can state, in one sentence, why knowledge lives in the description and not in the file pointer.
- [ ] You have chosen a far-future `defer_until` and confirmed deferred beads survive `bd gc` in your beads version.
- [ ] You have a written list of what will *not* migrate — starting with your injected memories.

## Phase 1 — Per-repo setup

The plugin ships the machinery; you supply what only your repo knows. Splitting those two is the whole of setup.

### What the plugin ships versus what you author

| Shipped by the plugin | You author, per repo |
|---|---|
| Capture instructions — the skills file a bead when they author knowledge | Any custom types beyond the native `decision` |
| Retrieval triggers — a knowledge check inside brainstorming and debugging | A controlled label vocabulary, clustered from *your* corpus |
| The session-start pointer to the store | The two guards, adapted to your paths and test surface |

### Declare your custom types

`decision` is native. Add the two reference types the store uses:

```bash
bd config set types.custom "research,design"
```

### Author your label vocabulary

The labels are your index, so build the vocabulary from your own material — cluster your actual corpus, name the clusters that recur, and stop at 15–25 labels. Two rules keep it a usable query axis: no singletons (a label with one member is not something you would ever query by), and never copy another project's vocabulary blind, because it encodes another project's topics. Keep the list in a plain file the guards can read:

```text
# kb-label-vocab.txt — one topic label per line
hooks
installer
memory
retrieval
sync
testing
```

### Adapt the two guards

Two guards keep the store honest, and both need pointing at your paths before they mean anything:

- A **label-invariants guard**: every knowledge-bead carries `kb` plus one to three topic labels, each drawn only from the vocabulary file.
- A **doc↔bead reconciliation guard**: every source document that should have a bead has one. Scope it per corpus so a skipped capture in your ADR directory fails independently of your research notes.

Wire both into whatever runs your checks so a drifted label or a missed capture breaks the build, not a future lookup.

!!! example "In this repo"
    The vocabulary settled at 20 topic labels, clustered from the existing corpus. Both guards run in this repo's `just guards` surface; the reconciliation guard covers the ADR directory and the research docs as two independently scoped loops, so a skip in one corpus can't hide behind coverage of the other.

**Exit criteria.** This phase is done when:

- [ ] `bd config set types.custom` has run and `bd config show` lists your types.
- [ ] A vocabulary file exists with 15–25 labels, no singletons, clustered from your corpus.
- [ ] Both guards run in your test surface and pass on the empty-store starting state.

## Phase 2 — Inventory

Before migrating anything, sort your sources by where each maps — and, just as important, which ones don't belong in the store at all.

| Source | Maps to |
|---|---|
| ADR directory (architecture decisions) | `decision` |
| Design docs, specs, RFCs | `design` |
| Research notes, investigations, findings | `research` |
| Wiki pages or READMEs holding decisions or design rationale | `decision` / `design` |
| An oversized memory store, reference-class notes only | by note type |
| Key-value stashes of reference notes | by note type |

Exclude anything that isn't reference knowledge you would re-open at a decision point:

| Excluded | Why |
|---|---|
| Implementation plans, task briefs and reports | Execution artifacts — they describe work, not knowledge |
| Transient TODOs | Belong in the task tracker, not the knowledge store |
| Injected memories (`lesson` / `pattern` / `root-cause` / `correction`) | A different memory tier — they stay in `bd memories` |

**Exit criteria.** This phase is done when:

- [ ] Every source corpus is assigned a type or explicitly excluded, with a reason for each exclusion.
- [ ] The excluded list names your injected memories and your execution artifacts.

## Phase 3 — Migrate

Migration is a pipeline: distill each item, propose its labels, put a human on the labels, triage for sensitivity, create the bead, then verify before you retire anything. The order matters — the review gates sit before the writes, not after.

### Distill

Turn each source into a 0.5–2.5 KB description that stands on its own: the finding or decision, the evidence, the consequences, no "see above" references to context the bead doesn't carry. Run a secret and PII scan on every description before it becomes a bead. Descriptions ride your Dolt history, which outlives a later deletion, so the rule is flag-and-drop, never relocate-and-hope.

### Propose labels, then review them

Let an LLM propose the topic labels; never auto-apply them. Labels are the query axis, so a wrong label doesn't just mislabel one bead — it corrupts what every future query returns. Give the labels a **full human review**, every row. Descriptions can take a lighter touch: a stratified spot-check (longest, shortest, most-sensitive-looking, one per type) over a mechanical floor that every row must clear anyway — within the size band, secret-scan clean, self-contained. A weak distillation is recoverable one bead at a time; label rot is not.

### Triage for sensitivity

During that same review, flag anything whose substance shouldn't reach a shared Dolt remote — internal strategy, unreleased plans, competitive positioning. Migration syncs the description, which is new exposure the source file never had. Park flagged items: leave them out of the store, record them in a gitignored exclusions list the reconciliation guard honors, and migrate them only once you have a dedicated beads remote to hold them.

### Create or enrich the bead

Create fresh from a distilled description, piped over stdin so it never touches your shell history, with provenance metadata that makes re-runs idempotent:

```bash
printf '%s' "<distilled 0.5-2.5KB summary>" | bd create "<one-line title>" -t <type> -l kb,<topics> --defer 2099-01-01 --metadata "$(jq -nc --arg d "<doc-path>" '{doc:$d}')" --body-file - --silent
```

If a thin index-row bead already exists from an earlier pass, enrich it in place instead of creating a duplicate:

```bash
printf '%s' "$desc" | bd update <id> --body-file -
```

The `metadata.doc` (or a `metadata.kv_key` for key-value sources) is both the deep-dive pointer and the idempotency key: a second run finds the existing bead and creates nothing.

### Verify, then retire

Migration is two-phase, and the phases don't overlap. First verify: counts match your inventory, sample topic queries surface items you know are in there, and the guards are green. Only then retire sources — and only the ones the store *replaced*. A key-value stash or a set of duplicated notes becomes a tombstone (`bd` keeps the provenance of where each item moved), never a hard delete. Corpora that stay the deep-dive body your beads point at — the ADR directory, the research docs — are kept, not retired.

!!! example "In this repo — 129 kv + 36 docs + 55 ADRs"
    Three corpora moved into 216 knowledge-beads: 63 decision, 75 design, 78 research. The key-value store was retired to tombstones with per-key provenance; the ADR files and research docs stayed in place as the deep-dive bodies their beads point at. Eight items — six research docs and two ADRs — were held back during review because their substance shouldn't reach a shared remote, kept green by a gitignored exclusions list until a dedicated beads remote existed; once it landed, all eight migrated in a follow-up pass. Every run is idempotent: a second pass creates zero beads. The secret scan flagged one token-shaped filename before it landed and wrote nothing sensitive.

!!! example "In this repo — 14% to 100% retrieval precision"
    The payoff is retrieval you can trust. Before the migration, grepping the key-value store for `position` returned seven hits, one of them relevant; the store's own documented tag query returned zero, because only 26 of 129 entries had ever been tagged and the tags shared no vocabulary. The same question as a topic-label query returned three results, all three relevant — 14% precision to 100%.

**Exit criteria.** This phase is done when:

- [ ] Every migrated item cleared the mechanical floor and a secret/PII scan.
- [ ] Labels were human-reviewed in full; sensitivity-flagged items are parked, not written.
- [ ] Counts and sample queries verified before any source was retired; only replaced sources were tombstoned.

## Phase 4 — Wire & verify

A migrated store is inert until two things happen to it on their own: knowledge gets captured when it's created, and knowledge gets retrieved when a decision is made. Wire both, then prove they fire.

### Capture at authoring time

Put the capture command inside the steps that already author knowledge, so filing the bead is part of the work and not a separate chore. In this plugin that means the research write-up files its research bead, the ADR write files its decision bead, and the memory curator routes reference-class memories into the store — each piping the distilled description over `--body-file -`.

### Retrieve at decision time

Co-locate a knowledge check where decisions actually get made: the first phase of brainstorming and the first phase of debugging both query the store before proposing anything, and the session-start hook carries a pointer to it. The pointer is deliberate — bodies are never injected, so the store stays a just-in-time lookup instead of a context tax on every session.

### Smoke-test both paths

Prove capture writes a real description and retrieval finds it by topic:

```bash
# capture smoke test — a fresh knowledge-bead lands with a real body
printf '%s' "Smoke: <two-sentence real finding>" | bd create "Smoke: retrieval works" -t research -l kb,<topic> --defer 2099-01-01 --body-file - --silent
# retrieval smoke test — the topic query surfaces it, and the body reads back
bd list --label <topic> --status all --flat --long -n 5
```

With the guards from Phase 1 in your test surface, a skipped capture or an off-vocabulary label now fails the build the moment it happens.

**Exit criteria.** This phase is done when:

- [ ] A capture smoke test produces a bead with a full description, not a title-only row.
- [ ] A retrieval smoke test surfaces a known item by topic label.
- [ ] Both guards run in your test surface and are green.

## Phase 5 — Lifecycle

The store is not a one-time load; it drifts, and three habits keep it accurate.

### Supersede on replacement

When a decision changes or a document is rewritten, don't edit the old bead out from under whoever might be reading it — supersede it, which retires the old and links the replacement:

```bash
bd supersede <old> --with <new>
```

### Let the curator govern the vocabulary

A periodic `memory-curator` sweep owns vocabulary governance: merging labels that have converged, retiring singletons that never earned a second member, and naming a new cluster once enough beads pile up around it. Vocabulary drift is normal; leaving it ungoverned is how the query axis rots.

### Age cooled memories into the store

An injected memory that has cooled — still true, no longer needed unprompted — ages down into the deferred store as reference knowledge. It is the Phase 0 boundary run in reverse over time: a note graduates out of injection once you no longer want it handed to you every session, but you still want to find it when you go looking.

**Exit criteria.** This phase is done when:

- [ ] Replacements use `bd supersede`, not in-place edits that erase history.
- [ ] A recurring curator sweep is scheduled to govern the vocabulary.
- [ ] There is an agreed path for aging cooled injected memories into the store.
