# Final Review

Read this when the last task has closed and you are about to run the whole-branch review.

Run `bash scripts/review-package <plan-file> <MERGE_BASE> HEAD` and dispatch a
most-capable-tier reviewer over the whole branch — the only place the composite of
all fix rounds is examined. Findings go to one fix subagent, then one scoped
re-review; residuals follow the breaker rules.

**Rulings I made.** Before you delete anything, collect **every** ledger line containing
`Ruling:` — pre-flight rulings, parked findings, breaker adjudications, all of them — into your
final message under "Rulings I made", in the order you made them, each with its cited spec
location and what it costs if wrong. The list is exhaustive: if the ledger holds a ruling, the
list holds it. This is the only place decisions you took on your human partner's behalf reach
them, so they can rework whatever you got wrong.

**Teardown:** remove the plan's workspace once the final review is clean **and**
each task's outcome and any implementer-raised concerns are recorded in beads,
**and** the "Rulings I made" list has been delivered.
Reports are the only non-regenerable artifact — delete once the record is durable.
