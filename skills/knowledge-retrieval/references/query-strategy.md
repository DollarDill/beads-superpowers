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

## Degradation matrix

| Condition | Behavior |
| --- | --- |
| No `python3` on `PATH` | Keys/titles only are returned; hit **bodies are withheld** (redaction lives in the ranker — see SKILL.md Floor). |
| No `bd` on `PATH` | Visible SKIP — the coverage line names `bd` as unavailable rather than silently returning zero hits. |
| Empty store (no matching beads at all) | Reported as "none" — a legitimate empty result, not an error. |
| Broken text-processing pipeline (`grep`/`sort`/`sed` missing or erroring, no `python3`) | Named on the coverage line as `keys UNAVAILABLE(pipeline error)`. Without this a broken toolchain printed output byte-identical to the row above, so "none" could not be trusted. |
| Malformed entry (unparseable bead record) | Counted and named individually in the coverage line, not silently dropped from the total. |
