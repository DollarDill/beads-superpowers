# Rulings and Escalation — the full boundary

Open this when a conflict, ambiguity, or plan defect surfaces and you need to decide whether it is
yours to rule on. The kernel — the rule itself, the precedence clause, and the ledger format —
lives in `SKILL.md`; this file carries the enumerated lists.

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

**Precedence: must-stop wins** where both lists could apply - otherwise the permissive list
silently swallows the restrictive one. A security finding is never rulable and never parkable.
