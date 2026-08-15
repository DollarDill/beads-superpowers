# Rulings and Escalation — the full boundary

Open this when a conflict, ambiguity, or plan defect surfaces and you need to decide whether it is
yours to rule on. The kernel — the rule itself, the precedence clause, and the ledger format —
lives in `SKILL.md`; this file carries the enumerated lists and the reasoning behind them.

## The rule

**You MAY rule when the spec unambiguously settles it. Everything else escalates.**

Ruling from the spec is *reading the binding authority*, not descoping — it does not touch the
Production-Grade Doctrine's soft tier. Deciding that a requirement is not worth meeting stays your
human partner's call.

## You may rule

Record each in the ledger, then carry it into the next dispatch:

- a task contradicts another task
- the plan contradicts the spec
- the plan mandates something the review rubric classifies as a defect
- a plan defect whose correction the spec determines

## You MUST stop and ask

- dropping a required behaviour or edge case
- changing shipped behaviour the spec does not cover
- anything security-sensitive
- destructive or irreversible operations
- side effects outside the worktree (a merge, a push to a shared branch, a publish)
- **load-bearing breaker findings** — a finding that reveals a plan defect is by definition not
  spec-settled
- a plan so broken that every path forward is a guess

## Why the precedence clause exists

Where a situation could plausibly fall under both lists, must-stop governs. The may-rule entry
"the plan mandates something the review rubric classifies as a defect" structurally *reaches*
security findings — the rubric is exactly what classifies them. Without an explicit precedence
clause, the permissive list silently swallows the restrictive one, and an agent under pressure
reads the entry that lets it keep working.

So: **a security finding is never rulable and never parkable**, whatever the plan or the spec
says. That is the Production-Grade Doctrine's hard floor, and it matches the breaker's own rule
that a security-classified open finding "is never included in a list of things that could be
parked" (`breaker-trip.md`).

## Why rulings cite their authority

"The spec unambiguously settles it" is a test you apply to yourself, about your own authority.
That shape decays: under a long run it softens into "the spec probably implies it," and at that
point the boundary has moved without anyone deciding to move it.

Requiring a citation converts the test into a fill-or-fail field. If you cannot name a specific
spec location, it is by definition not spec-settled — escalate. It also makes the boundary
auditable afterwards: the "Rulings I made" list carries citations a reader can check, rather than
asking anyone to trust your own assessment of your own authority.

## Divergence from upstream

Upstream superpowers v6.3.0 ("Rulings, not stalls") lets the controller rule on conflicts, plan
defects, plan-mandated findings **and load-bearing breaker findings**, stopping only for four
classes. This fork deliberately keeps the narrower boundary above. Registered in
`auditing-upstream-drift`'s Known Deliberate Divergences table — do not "restore parity" by
widening it.
