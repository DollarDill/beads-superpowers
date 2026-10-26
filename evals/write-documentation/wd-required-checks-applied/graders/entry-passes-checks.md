---
type: llm
---

The reply must contain a CHANGELOG entry for the changes in CHANGES.md (the Skill and Read tool calls are graded separately). Grade only that entry against two checks from the write-documentation skill's references/required-checks.md, quoted here verbatim:

2. **Concrete-anchor audit.** For each substantial paragraph, point to one concrete anchor. In criticism, reportage, reviews, and analysis, at least one paragraph in the whole piece should be built around a single concrete example or observed consequence rather than category summary. If you cannot point to that paragraph, add one.

3. **Fact discipline.** Pick the three most fragile factual claims in the piece: dates, milestone names, quotes, close paraphrases, public metrics, future claims, causal trend claims. If you cannot vouch for them, attribute them, soften them, or cut them. If a citation or source is present, confirm it supports the exact claim rather than a nearby topic.

The entry is graded against this ground truth. CHANGES.md contains exactly:

```
# Changes since 1.4.0

- `parseDate` now accepts `YYYY/MM/DD` as well as `YYYY-MM-DD` (issue #31).
- `parseDate` returns `null` instead of throwing on an empty string. Callers that relied on the exception must check for `null`.
- Fixed `formatDate` printing the previous day for users west of UTC when the input was a date-only string (issue #44).
- Dropped Node 16 support; the minimum is now Node 18.
```

PASS only if both hold. Check 2: the entry names the specific changes (for example `parseDate`, `YYYY/MM/DD`, the `null` return for an empty string, `formatDate`, issue #31 or #44, Node 18) rather than vague category summary such as "various parsing improvements". Check 3: every fact in the entry is supported by the CHANGES.md content above; FAIL if it invents a release date, a version number other than a plainly marked placeholder, a performance figure, a quote, or a cause not stated in CHANGES.md. An `[Unreleased]` heading, or a version visibly marked as proposed or placeholder (for example "1.5.0 (proposed)"), counts as a plainly marked placeholder; a bare concrete version number presented as fact (for example "## 1.5.0" or "## [1.5.0] - 2026-10-26") FAILS. FAIL if the entry omits the `null`-instead-of-throwing behaviour change or its caller impact.
