---
type: llm
---

The reply must contain a rewrite of the paragraph in NOTES.md (the Skill and Read tool calls are graded separately). Grade only that rewrite. NOTES.md contains exactly:

```
# Notes for the README

datekit parses `YYYY-MM-DD` and `YYYY/MM/DD` strings and returns `null` for anything else instead of throwing. It's worth noting that every parsed date lands at UTC midnight, so `parseDate("2026-03-01")` is the same instant in every time zone. It's worth noting that `formatDate` prints in the caller's local zone unless you pass `{ utc: true }`. It's worth noting that the package has no runtime dependencies and needs Node 18 or later. It's worth noting that the test harness runs every case under three time zones: UTC, America/Los_Angeles and Asia/Tokyo.
```

The write-documentation skill's audit watchlist lists `It's worth noting that` as a formula phrase and `harness` as a jargon default, and says the problem is repeated fallback, not the existence of any one word: a watchlisted word is fine once where it is plainly the right word. Here `It's worth noting that` opens four of the five sentences (repeated fallback), while "test harness" is the ordinary technical term for what runs the tests (a legitimate single use).

PASS only if all of these hold. (1) The repeated fallback is gone: `It's worth noting that` appears at most once in the rewrite, and it has not been swapped for another single stock opener repeated in three or more sentences (for example `Note that`, `Notably,`, `Importantly,` or `It's important to note that`). (2) The legitimate single use is kept: the rewrite still says "test harness"; replacing it with a different term (for example "test suite") or dropping the sentence that mentions it counts as mechanically stripping a watchlisted word and FAILS. (3) The meaning is preserved: the rewrite keeps every fact in the paragraph, namely both accepted formats (`YYYY-MM-DD` and `YYYY/MM/DD`), the `null` return instead of throwing, UTC midnight for parsed dates (the `parseDate("2026-03-01")` example may be shortened or dropped only if the same-instant-in-every-time-zone point survives), `formatDate` using the local zone unless `{ utc: true }` is passed, no runtime dependencies, Node 18 or later, and the three named time zones the test harness runs under. (4) No invented facts: FAIL if the rewrite adds any feature, number, version, time zone, benchmark or claim not in the paragraph above. FAIL if the reply has no rewrite, or only lists suggestions instead of giving the rewritten paragraph.
