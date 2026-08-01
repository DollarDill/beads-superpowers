# Query Strategy

Supporting detail for the `knowledge-retrieval` skill's Steps 1–2. Open this when a query returns
nothing, returns more than you can disposition, or a source reports degraded in the coverage line.

## Topic-label vocabulary

Knowledge beads are tagged with the `kb` label plus 1–3 topic labels from this fixed vocabulary
(`scripts/kb-label-vocab.txt`, copied verbatim — do not retype from memory, `cat` the file if it may have
changed):

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

Use these labels to scope a search with `bd list --label <topic> --status all` when a query maps cleanly
onto one of them — it's cheaper and more precise than free-text search.

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
| Malformed entry (unparseable bead record) | Counted and named individually in the coverage line, not silently dropped from the total. |
