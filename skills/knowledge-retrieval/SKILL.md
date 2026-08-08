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
2. **Run `bash <skill-base-dir>/scripts/surface.sh <variants>`.** Read the coverage line first.
   Done when: the coverage line is read and any degraded source is named.
3. **Read the shortlist's hit bodies** — `bd show <ids>` / `bd recall <key>`, never truncated below 50 lines.
   Done when: every returned hit is read or explicitly ruled out from its sentence alone.
4. **Emit dispositions** — one line per hit: folded in (what it changed) or ruled out (why).
   Done when: the coverage line from step 2 is reproduced **verbatim**, then
   `KB check (retriever): N hits, K read`, then one disposition line per read hit.
   The coverage line is the evidence — only the script prints it, and its counts are
   checkable against the store. The marker is a human-readable cue, not proof.

Bounded: query rounds are capped. Open `references/query-strategy.md` before starting a third
round, or before reporting that nothing was found.

## This skill asks nothing

It returns what it found. Where a query is ambiguous it returns the candidate angles and the caller
re-queries — it never requests input, so it is safe in interactive, headless and subagent frames.

## Floor (never moved, never compressed)

- **Never truncate before redacting, and redact the key as well as the body.** Redact the full body
  first; a redacted excerpt cut afterwards can print a partial secret. The key is an output too: `bd`
  derives it from the body's leading words and lowercases it, so a credential reaches the key column
  in a mangled — and for uppercase-only shapes, trivially reversible — spelling.
- **Never build a query into a command string** — pass it as an argument. Queries are model-generated.
- **Never print bodies without `python3`** — redaction lives in the ranker; print keys only. A floor with
  a bypass is not a floor. With no ranker there is also no bound: if the output discloses
  `showing 20 of N keys`, narrow the query, never triage truncated titles.

Open `references/query-strategy.md` when a query returns nothing, returns more than you can
disposition, or a source reports degraded in the coverage line.
