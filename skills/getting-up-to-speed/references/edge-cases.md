# getting-up-to-speed — Edge Cases & Degraded-State Language

Open this when a step returns something unexpected. Each row prescribes the behavior and the exact degraded wording for the summary — degraded language is stated, never invented.

| Condition | Behavior / summary wording |
|---|---|
| No `.git` directory | Skip the git phase; emit "**Git:** not a git repo" |
| `bd` not installed | orient.sh still runs (scale + handoff); bd sections read SKIP — skip step 3 and beads lines; emit "**Beads:** not installed — skipped" |
| `.beads/` missing but `bd` installed | `bd ready` returns empty; note "no beads workspace" |
| Embedded Dolt mode | Never call `bd dolt status/show/push` — orientation is read-only |
| Dirty working tree | Show `git status -sb` count in the Git line |
| Detached HEAD | Emit `HEAD detached at <sha>` instead of a branch name |
| Empty git log | `git log` exits non-zero; catch and emit "no commits yet" |
| `find` on missing dirs | Independent + `2>/dev/null`; skipped silently |
| Post-compaction, no prior thread | Recent Activity → "Fresh session — no prior in-session delta" |
| Hundreds of changed files | Top-N by churn + "+K more"; never dump the diff |
| Open/in-progress bead in no commit | NOT a divergence — do not flag |
| `git log --grep` errors / base branch undetectable | Continuity check "unavailable"; never blocks the summary |
| `.internal/handoff/` absent or empty | Skip the read; Last-handoff line reads "none found" |
| Handoff at a non-default path | Not auto-detected; only `.internal/handoff/` is checked |
| Newest handoff predates the latest commit | Recency verdict **possibly stale**; suppress "Welcome back"; say it "predates HEAD — background context, not necessarily the last session" |
| Multiple unread handoffs in the inbox | Read only the newest; append "(+N older unread handoff(s) in inbox — not consumed this run)" |
| Archive `mv` fails at close | Non-fatal: "⚠️ could not archive `<name>` (<reason>); left in inbox"; re-read + recency-flagged next session |
| Re-run after archive | Doc was moved, not deleted; empty inbox → skip |
