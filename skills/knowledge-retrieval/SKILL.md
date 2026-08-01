---
name: knowledge-retrieval
description: Retrieve prior knowledge before designing, planning, or debugging. Triggers on "what do we know about X", "prior decisions", or when another skill needs grounding first.
---

# Knowledge Retrieval

**Announce at start:** "I'm using the knowledge-retrieval skill to surface prior knowledge on <topic>."

## Iron Law: hits are pointers, not knowledge

A ranked list is not an answer. Completion is **every plausibly-relevant hit dispositioned** — folded in
(what it changed) or ruled out (why). A count is never the completion criterion.

## Steps

1. **Expand the query to 3–8 variants** — synonyms, abbreviations, compound splits. `bd` has no stemming,
   so `worktree` and `work tree` are different searches.
   Done when: the variant list exists and covers at least one synonym and one compound split.
2. **Run `bash scripts/surface.sh <variants>`.** Read the coverage line first.
   Done when: the coverage line is read and any degraded source is named.
3. **Read the shortlist's hit bodies** — `bd show <ids>` / `bd recall <key>`, never truncated below 50 lines.
   Done when: every returned hit is read or explicitly ruled out from its sentence alone.
4. **Emit dispositions** — one line per hit: folded in (what it changed) or ruled out (why).
   Done when: `KB check: N hits, K read` plus one disposition line per read hit.

Bounded: at most 5 query rounds. Re-angle once before reporting none.

## This skill asks nothing

It returns what it found. Where a query is ambiguous it returns the candidate angles and the caller
re-queries — it never requests input, so it is safe in interactive, headless and subagent frames.

## Floor (never moved, never compressed)

- **Redact before truncating.** Secrets are redacted on the full body before any cutting; a redacted
  excerpt cut afterwards can print a partial secret.
- **Queries are passed as arguments, never built into a command string.** Queries are model-generated.
- **Without `python3`, bodies are withheld** — redaction lives in the ranker, and a floor with a bypass
  is not a floor.

For keyword expansion technique, the topic-label vocabulary, and degraded modes, read
`references/query-strategy.md`.
