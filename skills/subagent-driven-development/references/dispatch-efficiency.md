# Dispatch Efficiency — batching and waiting

Open this before dispatching a run with several small tasks, or whenever you are about to wait on
children. Both rules exist because the default behaviour is expensive in ways that do not show up
as errors.

## Batch small same-shape work

When the plan lists several tasks that are each a small, independent edit of the **same kind** —
the same one-line fix, constant change, or field addition repeated across files — do not dispatch
one subagent per task. Compose **one** dispatch brief listing every file and its change, send the
whole batch to a single subagent, and review its diff as one unit.

Reserve one-dispatch-per-task for work that needs its own judgment, its own tests, or its own
review surface. The test is not "how many files" — it is whether a reviewer could meaningfully
reject one item while approving its neighbour.

**When you batch, the review changes shape too.** The reviewer must check the diff against the
brief's file list *file by file*: every listed file must have a corresponding hunk, and a listed
file the diff never touches is a **Missing** finding no matter how clean the rest of the batch
looks. Without that check a batched dispatch can silently drop items.

## Waiting on dispatched subagents

Never poll a wait interface with short timeouts, and never sit in one silent, open-ended wait
either.

- **While you have local work — ledger updates, packaging the next review, reading reports — keep
  working.** Child results arrive on their own; a completed child's answer is pushed to you and
  surfaces on your next turn.
- **When genuinely idle, wait in bounded stretches** (five to ten minutes, where your platform
  allows). Between stretches, post one line of status and reconcile your live children: list them,
  and chase any that finished without reporting.
- A bounded stretch keeps nearly all of a long wait's efficiency while guaranteeing that a stuck or
  lost child is noticed within minutes rather than at the end of the session. A stretch that times
  out with no activity is a cue to reconcile, not to shorten the next stretch.

Harness-specific mechanics (timeout values, `list_agents`, spawn hygiene) live in the platform
reference your harness maps to — for Codex, `using-superpowers/references/codex-tools.md`.
