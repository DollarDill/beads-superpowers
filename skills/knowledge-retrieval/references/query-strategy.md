# Query Strategy

Supporting detail for the `knowledge-retrieval` skill's Steps 1–2. Open this when a query returns
nothing, returns more than you can disposition, or a source reports degraded in the coverage line.

## Topic-label vocabulary

Knowledge beads are tagged with the `kb` label plus 1–3 topic labels. `surface.sh` derives the vocabulary
from the live data (`rank.py`'s label-matching stage reads it off the beads actually returned, never from
a file — a file path breaks once the skill is installed, since only `skills/*` gets promoted into
`~/.claude/skills`). The **authoritative set** is whatever the coverage line's `label=` field discloses
when a query's terms match a label. The list below is an example of *this repo's own* vocabulary, useful
for orientation, not a source to `cat` or treat as current:

```
kb
skills-arch
stress-test
sdd-process
orientation
docs
i18n
memory
hooks
token-efficiency
rdd
installer
harness-parity
beads-tooling
positioning
seo-web
adr-process
production-doctrine
testing-guards
release
```

Use labels like these to scope a search with `bd list --label <topic> --status all` when a query maps
cleanly onto one — it's cheaper and more precise than free-text search.

## Keyword expansion examples

**Synonym expansion.** Query: "how does the installer detect harnesses". `bd` has no stemming or synonym
matching, so a single phrase misses adjacent wording. Expand to variants that cover the same idea in
different words:

- `installer harness detection`
- `installer harness auto-detect`
- `install.sh detect CLI`
- `harness-parity` (topic-label search)

**Compound split.** Query: "worktree isolation". Compound and split forms are different literal strings to
`bd`'s search, so both must be tried:

- `worktree` (compound)
- `work tree` (split)
- `git worktree isolation`
- `using-git-worktrees` (skill-name form, since docs often reference the skill by name)

## Bounded iteration

At most 5 query rounds per retrieval task. If round 5 still returns nothing plausibly relevant, re-angle
the query once (a genuinely different framing — not a rephrase) before reporting "none found." Do not keep
grinding past that; a bounded "none" is a valid, complete answer.

## When a query returns more than you can disposition

More than 10 hits means the query is too broad, not that you should skim. A title is not evidence
and a hit count is not a done-state, so
**narrow the query, never triage truncated titles**.

**Terms are OR-ed, not AND-ed** — by `surface.sh` on the degraded path and by BM25 in the ranker.
Adding a term therefore *widens* the candidate set. Narrowing means **replacing** terms, never
appending them:

1. **Replace a low-signal term with a high-signal one.** Signal is rarity: a term carried by most
   entries discriminates nothing. (Measured on this repo's store, as counts of memories whose body
   contains the term: `lesson` 117 of 180, `shellcheck` 5. Swapping `lesson` for `shellcheck`
   collapses the set; adding it to `lesson` enlarges it — `lesson` returns 136 keys on the degraded
   path, `lesson guard` returns 144.)
2. **Drop terms rather than add them.** Every extra term is more results, not fewer.
3. Only then re-run.

If a compound may be spelled two ways, `worktree` and `work tree` are different searches — `bd` has
no stemming. That is a *recall* fix for the zero-hits case above, not a narrowing move; it widens.

**On the degraded path (no `python3`) nothing bounds the set but the query** — and that is the only
path where more than 10 hits can reach you, since the ranker caps its shortlist. Keys come back in
alphabetical order, never relevance order, cut at 20 with a `showing 20 of N keys` disclosure. Do
not disposition 20 unranked keys — replace terms until the disclosure disappears, or install
`python3` so the shortlist is ranked and bounded.

## Degradation matrix

| Condition | Behavior |
| --- | --- |
| No `python3` on `PATH` | Memory **keys only** — never titles, never bodies (redaction lives in the ranker — see SKILL.md Floor). Knowledge beads are not searched at all on this path; the coverage line reads `kb-beads(SKIPPED)`. Keys are cut at 20, and the cut is disclosed as `showing 20 of N keys`. |
| No `bd` on `PATH` | Visible SKIP — the coverage line names `bd` as unavailable rather than silently returning zero hits. |
| Empty store (no matching beads at all) | Reported as "none" — a legitimate empty result, not an error. |
| Broken text-processing pipeline (`grep`/`sort`/`sed` missing or erroring, no `python3`) | Named on the coverage line as `keys UNAVAILABLE(pipeline error)`. Without this a broken toolchain printed output byte-identical to the row above, so "none" could not be trusted. |
| Malformed entry (bead carrying no id) | **Counted but not searched** — it is included in `kb-beads(N)` yet excluded from the corpus, and nothing names it individually. This differs from the `schema_version` envelope key, which is excluded from the memory count precisely so that count reports what was *searched*. A known inconsistency, recorded rather than fixed here. |
