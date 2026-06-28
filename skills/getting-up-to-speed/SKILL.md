---
name: getting-up-to-speed
description: Orients on an unfamiliar or stale codebase at the start of a session, after compaction, or whenever the project state is unclear. Loads beads context, deep-dives the codebase, and produces a structured 'current state' summary. Triggers on phrases like "catch me up", "where are we", "orient me", "what's the state of this project", "bring me up to speed", "load context", "session orientation".
---

# Getting Up to Speed

Orient on the current project before doing any work. Run beads context commands, deep-dive the codebase, and produce a structured "current state" summary so you (and the user) know exactly where things stand.

**Announce at start:** "I'm using the getting-up-to-speed skill to orient on the project."

## When to Use

- Start of a fresh session on an existing project
- After `/compact` or context loss
- User says "catch me up", "where are we", "orient me", "bring me up to speed", "load context", "session orientation"
- You're about to do non-trivial work in a repo and have no recent context

## When NOT to Use

- The user just asked a single targeted question that doesn't depend on broad context
- You already oriented in this session and nothing has changed
- Fresh empty repo with nothing to orient on (use `project-init` instead)

## Pipeline

```
Pre-step: Detect repo scale  →  Phase 1: Beads (parallel)  →  Phase 2: Codebase (parallel, adaptive)
                                                                     ↓
                                       Phase 4: Synthesize summary  ←  Phase 3: Top open beads drilldown
```

## Progress Checklist

Copy this into your working response and check each item off as you complete it (all paths — Light included):

- [ ] Pre-step: repo scale detected (Light / Medium / Heavy)
- [ ] Phase 1: beads context loaded (or skipped — no beads)
- [ ] Phase 2: codebase explored (path-appropriate)
- [ ] Phase 3: top open beads drilled (or skipped — no beads)
- [ ] Phase 4: summary emitted + verification gate passed

## Pre-step: Detect repo scale

Run this single command first to pick a path. Uses git plumbing (`rev-parse --is-inside-work-tree`) and a probe of `bd ready` so it works correctly inside git worktrees and submodules — checking for a literal `.git`/`.beads` directory misidentifies worktrees as "no git" because `.git` there is a file, not a directory.

```bash
TRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
HAS_GIT=$(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo 1 || echo 0)
if command -v bd >/dev/null 2>&1; then
  HAS_BEADS=$(bd ready --limit 1 >/dev/null 2>&1 && echo 1 || echo 0)
else
  HAS_BEADS=0
fi
echo "tracked=$TRACKED beads=$HAS_BEADS git=$HAS_GIT"
```

| Tracked files | Path | Behavior |
|---|---|---|
| `< 50` or no `.git` | **Light** | bd commands + read README + git log; skip Phase 2 medium drilldown. |
| `50 – 500` | **Medium** *(default)* | Parallel bd + parallel codebase reads + key-file drilldown + open-bead details. |
| `> 500` | **Heavy** | Dispatch `@researcher` + `@explore` in parallel via the `Agent` tool (use `dispatching-parallel-agents`). |

## Phase 1 — Beads context (single parallel batch)

Issue all of these commands in **one message, multiple Bash tool calls in parallel**:

- `bd prime`
- `bd ready`
- `bd blocked`
- `bd query "status=open OR status=in_progress"` — compound-query open + in-progress work in one call (the v1.0.5 query language replaces `bd list` + jq)
- `bd memories`
- `bd stats`
- `bd count --by-status` — ledger counts grouped by status; feeds the Phase 4 "Beads ledger" line
- `bd count --by-priority` — open-work priority breakdown

If `bd` is not installed or `.beads/` is missing, skip Phase 1 entirely and emit "**Beads:** not installed/initialized — skipped" in the Phase 4 summary.

**Do NOT run `bd dolt status`, `bd dolt show`, or `bd dolt push` here** — they aren't needed for orientation, and `bd dolt push` mutates the remote. Keep orientation read-only.

## Phase 2 — Codebase exploration (single parallel batch, content varies by path)

Issue **all reads in one message, multiple tool calls in parallel**. Do NOT serialize.

### Light path

- `find <repo-root> -maxdepth 1 -mindepth 1 | sort`
- `git log --oneline -15` + `git status -sb` + `git tag --sort=-v:refname | head -5`
- `Read` of `README.md`

### Medium path *(default)*

Light path, plus:

- `Read` of any of these that exist: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json`
- `Read` of any of these that exist: `CHANGELOG.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`
- `Read` of project-specific manifests when relevant (e.g., `.claude-plugin/plugin.json` for plugin repos)
- `find` on any of these dirs that exist: `skills/`, `agents/`, `commands/`, `docs/`, `hooks/`, `tests/`, `src/`, `lib/`, `app/`

### Heavy path

Use `dispatching-parallel-agents` to dispatch in one message:

- `@researcher` — read CLAUDE.md/README/CHANGELOG, return architecture summary in <300 words
- `@explore` — enumerate top-level structure, count source files by language, return layout report in <200 words

After both return, optionally `Read` 1–3 files the agents flagged as critical.

## Phase 3 — Top open beads drilldown (all paths)

- Run `bd show <id> | head -30` on the **top 3 open ready beads by priority** from Phase 1's `bd ready` output.
- This is the agent's drilldown — used to feed the "Known operational quirks" line in the Phase 4 summary.
- The output table in Phase 4 lists **up to 10 open ready beads** (not just the 3 drilled), so the user sees the whole queue.

If Phase 1 was skipped (no beads), skip Phase 3.

## Phase 4 — Synthesize the structured summary

Produce **exactly this Markdown structure**. Heading levels are H2; tables and lists scale to project content. Sections you cannot fill from earlier phases are marked with the degraded-state language from the Edge Cases table — never invented.

**Evidence + confidence convention:**

- **Inferred/synthesized claims** ("What it is", "Architecture Highlights", "Known operational quirks") each carry `[<glyph> source: <file/cmd>]` — glyph is ✅ high / ⚠️ medium / ❓ low — plus `verify: <what>` when below high.
- **Deterministically-verified sections** (Repo Layout from `find`, Git from git, Beads ledger from `bd count`) are ground truth — labeled `(verified)` at the heading, no per-line tags. Tag where trust varies, never as filler.

**Cross-checks to compute (compute these yourself, all paths — never delegated to sub-agents):**

- **Working tree:** from `git status --porcelain` (full list incl. untracked, status codes `M`/`A`/`D`/`R`/`??`) + `git diff --numstat` (added/deleted per tracked file; binary shows `-`). Rank tracked changes by added+deleted; show top-N with `+X/-Y` counts; render binary as `(binary)`; list the untracked count separately. Never dump the diff.
- **Continuity check (in-progress beads only):** resolve the base branch as `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name), falling back to `main` then `master`; if none resolves, mark the check "unavailable". For each in-progress bead, run `git log --grep="<bead-id>" --oneline <base>`. If the bead ID appears in a commit reachable from the base branch, flag it advisory: `⚠️ <bead> appears in <sha> on <base> — verify it shouldn't be closed`. A multi-commit epic legitimately keeps shipping while open, so judge — do not auto-conclude. A bead whose ID is in no commit is NOT flagged. Skip the check when beads are absent. Deeper hygiene (stale branches, orphans, lint) → point to `bd doctor` / `bd stale` / `bd orphans`; do not reimplement it here.

```markdown
## What `<project>` Is
<1–3 sentence synthesis. Language/runtime, primary purpose, merge/fork lineage if discoverable.> [✅ source: CLAUDE.md / README / CHANGELOG]

| Layer | Source | Role |
|---|---|---|
<Optional table — used when project merges/wraps multiple subsystems. Skipped for simple repos.>

## Architecture Highlights
- **<key design decision 1>** — <one-line consequence> [✅ source: CLAUDE.md Key Design Decisions]
- **<key design decision 2>** — <one-line consequence> [⚠️ source: README §Arch; verify: still matches code]
<3–6 bullets, sourced from CLAUDE.md / README / a METHODOLOGY-style doc. Each carries a confidence glyph + source.>

## Repo Layout (verified)
<code-fenced tree, ONLY directories actually present per `find` output. Never invented.>

## Current State
**Git:** <branch> · <clean | N uncommitted (M staged)> · <in sync | N ahead | N behind> origin · latest `<sha>` <subject> · tags <top 5>.
**Working tree:** <top-N changed files with +X/-Y counts; binary as `(binary)`; `+K untracked`>. (omit this line if the tree is clean — never dump the diff)
**Last release:** <if version detectable> shipped: <CHANGELOG bullet summary>. `[Unreleased]` <empty | has N entries>.
**Beads ledger:** <total> total · <closed> · <open> · <in-progress> · <blocked>. (verified, from `bd count --by-status`; <blocked> from `bd blocked`)
**Continuity check:** <✓ ledger consistent with git | ⚠️ <bead> appears in <sha> on <base> — verify it shouldn't be closed | skipped (no beads) | unavailable>.

| Bead | Pri | Title |
|---|---|---|
<Up to 10 open ready beads, sorted by priority. Top 3 were drilled into in Phase 3. Source: `bd ready`, or `bd query "status=open" --sort priority --limit 10` for the full open set.>

## Recent Activity
- <last 3–5 commits as a narrative of what shipped> [source: git log]
- <in-progress beads + where they were mid-way> [source: bd query in-progress]
- <after compaction: the prior in-session thread / decisions>
<Backward delta only. Degrades to "Fresh session — no prior in-session delta" when none. Does NOT restate the open-ready bead table above, nor the Last release line.>

**Known operational quirks:** <from `bd memories` keyword scan; from docs/known-issues/* if present> [source: bd memories]
**Other captured memories:** <one line per memory not surfaced above>

---
<after-compaction only: "Welcome back — last thread was <X>.">
I'm ready for your next instruction. Highest-priority unblocked work: **`<bead-id>`** (<priority> — <title>).
If you want to start it, the fitting skill is **<skill>** — but I'll wait for your call; I won't claim or begin anything.
```

### Verification Gate (run before emitting)

Validate each line; fix or mark degraded, then re-check. Only emit once all pass:

1. Every Current State fact (git, working tree, ledger, continuity) traces to a command you ran THIS session — not memory, not assumption.
2. Every inferred claim has a confidence glyph + source tag.
3. Any section you could not fill from a command → degraded-state language from the Edge Cases table. NEVER invent.
4. The continuity check ran (or is marked skipped/unavailable).
5. The Progress Checklist is fully ticked (or items marked skipped with reason).

The trailing "I'm ready" line is the **terminal contract**: the skill stops here. Do NOT auto-claim the next bead. Do NOT start working on anything. The user drives the next move.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

If orientation surfaced a Phase-1 memory that is now stale or wrong, remove it: `bd forget <id>`.

## Edge Cases

| Condition | Behavior |
|---|---|
| No `.git` directory | Skip the git phase entirely; emit "**Git:** not a git repo" in the summary |
| `bd` not installed | Skip Phase 1; emit "**Beads:** not installed — skipped" |
| `.beads/` missing but `bd` installed | Run `bd ready` (will return empty); note "no beads workspace" |
| Embedded Dolt mode | Do NOT call `bd dolt status/show/push` — only the safe read commands listed in Phase 1 |
| Dirty working tree | Show `git status -sb` count in the Current State line |
| Detached HEAD | Output `HEAD detached at <sha>` instead of branch name |
| Empty git log | `git log` exits non-zero; catch and emit "no commits yet" |
| `find` errors on missing dirs | Each `find` is independent and uses `2>/dev/null` — missing dirs skipped silently |
| After compaction, no prior thread recoverable | Recent Activity → "Fresh session — no prior in-session delta" |
| Working tree has hundreds of changed files | Summarize top-N by change-size + "+K more"; never dump the diff |
| Open/in-progress bead whose ID is in no commit | NOT a divergence — work uncommitted or convention not followed; do not flag |
| `git log --grep` errors or base branch undetectable | Mark continuity check "unavailable"; do not block the summary |

## Red Flags / Anti-Rationalization

These thoughts mean STOP — you're rationalizing skipping orientation:

| Thought | Reality |
|---|---|
| "I already explored this last session" | Sessions don't carry state. Re-orient. |
| "I'll skip beads commands — I'll use TodoWrite" | This project IS beads. `bd prime` is mandatory. TodoWrite is forbidden. |
| "The README is enough" | README skips beads state, open work, and known issues. Run the full pipeline. |
| "I'll skip Phase 3 — looking at open beads is busywork" | Phase 3 is what surfaces "this Dolt setup is broken" before you waste 20 minutes on it. |
| "I'll auto-claim the top P0" | Forbidden. Orient and stop. User drives. |
| "This is a small repo, I can skim" | Run the Light path of this skill. It's still 30 seconds and produces a summary you can refer back to. |
| "The summary looks complete, I'll emit it" | Run the Verification Gate first — every line traces to a command this session. |
| "I'll tag confidence later" | An inferred claim without a glyph + source is an unverified guess. Tag inline. |
| "Beads and git probably agree" | Run the continuity check. A shipped-but-still-open bead is exactly what it catches. |
| "I'll suggest they start the top bead" | Suggest the *skill*; don't claim or begin. The terminal contract is absolute. |

## Output Contract

The skill is complete when you have produced the structured summary, **the Verification Gate has passed**, AND emitted the trailing "I'm ready for your next instruction" line. No claiming, no continuation. Wait for user input.

## Integration

**Invoked by:** User on-demand or at session start. No other skill invokes this directly.

**Uses:** **dispatching-parallel-agents** — heavy path (500+ tracked files) dispatches @researcher + @explore in parallel.

**Pairs with:** **project-init** — for fresh/empty repos with nothing to orient on, use project-init instead.
