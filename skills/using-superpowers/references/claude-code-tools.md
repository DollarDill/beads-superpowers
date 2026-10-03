# Claude Code Tool Notes

Claude Code is the reference harness: skills speak its vocabulary (`Agent` for a subagent dispatch, `Skill`, `AskUserQuestion`). One Claude Code capability changes how a plan can be run, and it is opt-in only.

## Delegated orchestration (opt-in, whole plan only)

Claude Code nests subagents (three layers below the main conversation by default; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` adjusts it). The controller seat in a subagent-driven-development run is the most expensive one — it reads every dispatch result and every report on the session's tier — so the whole loop can run one layer down.

**Only when your human partner asks for it (for example at the writing-plans handoff).** Never choose delegation yourself to save cost; that is a trade-off the doctrine reserves for the human.

Dispatch ONE orchestrator subagent on a capability tier no lower than the standard tier with this brief:

- the plan path and the spec path;
- "You are the orchestrating agent for this plan: you own its beads (epic and children) for this run; the session will not touch them until you return";
- "Use beads-superpowers:subagent-driven-development end to end, including its Model Selection, Rulings and Escalation, breaker and final review — every stop applies to you unchanged; a security finding is never rulable and never parkable";
- "Stop after the final review and its fixes. Do not invoke beads-superpowers:finishing-a-development-branch, merge, push, or tear down the plan workspace — return to the session, which verifies before any merge.";
- "Your final message carries the exhaustive 'Rulings I made' list verbatim, with cost-if-wrong per line."

Do this only for a whole plan. Nesting a single task's dispatch buys nothing and adds a seat.

## When the delegate returns — verify before you trust

Relay its "Rulings I made" list to your human partner unsummarised. Then verify the ledger against the repository before any merge:

```bash
bd list --parent <epic-id> --status all          # every task closed? any 'human' labels?
bd show <epic-id>                                 # rulings and pre-flight rows
git log --oneline <merge-base>..HEAD              # commit ranges named in completion lines exist?
```

Check every closed child against what subagent-driven-development leaves behind:

- the commit range in its close reason exists in `git log` on the branch;
- it was closed only after a review verdict — the close reason says `review clean`, or `re-review PASS` after a fix round;
- each ruling in the delegate's list appears in the epic's notes as a `Ruling: … — settled by …` line.

A completion line without a matching commit is a finding, not a formality — stop and surface it. Once the ledger checks out, the session tears down the plan workspace and invokes beads-superpowers:finishing-a-development-branch itself.
