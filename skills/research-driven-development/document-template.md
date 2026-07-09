# Research Document Template

Filled in by the dispatching agent at Step 5.

```markdown
# Research: [Topic]

> **Date:** YYYY-MM-DD
> **Bead:** <bead-id>
> **Status:** Complete

## Summary

[2-3 sentence overview of key findings. What did we learn? What's the recommendation?]

## Key Findings

### [Finding 1: Title]

> **Confidence:** high / medium / low — [one-line rationale]

[Details with specific facts, numbers, commands. Tag each load-bearing claim with its source, e.g. `[S1]`. Be concrete — no vague claims.]

### [Finding 2: Title]

> **Confidence:** high / medium / low — [rationale]

[Details]

## Comparisons

[Table comparing options/approaches if applicable]

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| ... | ... | ... | ... |

## Disagreements

[Optional — omit if none. When sources conflict on a load-bearing point: both positions, who holds each, and our verdict + why.]

## Codebase Context

[What already exists in the codebase related to this topic. File paths, patterns, relevant tests.]

## Recommendations

[Clear, actionable recommendations based on findings. What should we do next?]

## Recommended Beads

[If research reveals follow-up work, list as bd create commands]

- `bd create "Title" -t <type> -p <priority> --notes "Severity:/Confidence:/Evidence:"` — [Why]

## Open Questions

[Anything unresolved or needing further investigation]

## Refuted / Discarded Claims

[Optional — omit if none. Claims checked and dropped/downgraded during verification, with why. Surfaced for transparency.]

## Sources

- [Source Title](URL) — Primary/Official | Secondary | Community — [date] — [what was extracted]
- [Source Title](URL) — Primary/Official | Secondary | Community — [date] — [what was extracted]
```
