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
Pre-step: Detect repo scale (from orient.sh)  →  Phase 1: orient.sh + handoff Read (≤ 2 calls)  →  Phase 2: Codebase (parallel, adaptive)
                                                                     ↓
                                       Phase 4: Synthesize summary  ←  Phase 3: Top open beads drilldown
```

## Progress Checklist

Copy this into your working response and check each item off as you complete it (all paths — Light included):

- [ ] Pre-step: repo scale detected (Light / Medium / Heavy)
- [ ] Phase 1: `orient.sh` run — beads context loaded (or skipped — no beads) + handoff doc detected/read (or none)
- [ ] Phase 2: codebase explored (path-appropriate)
- [ ] Phase 3: top open beads drilled (or skipped — no beads)
- [ ] Phase 4: summary emitted + verification gate passed

## Pre-step: Detect repo scale

Phase 1 (below) runs `orient.sh` in a single call that also emits this Pre-step's `== scale ==` section — do not run a separate scale command. Read `tracked=<N>` and `git=<0|1>` from it to pick a path. Uses git plumbing (`rev-parse --is-inside-work-tree`) so it works correctly inside git worktrees and submodules — checking for a literal `.git` directory misidentifies worktrees as "no git" because `.git` there is a file, not a directory.

| Tracked files | Path | Behavior |
|---|---|---|
| `< 40` or no `.git` | **Light** | bd commands + read README + git log; skip Phase 2 medium drilldown. |
| `40 – 150` | **Medium** *(default)* | Parallel bd + parallel codebase reads + key-file drilldown + open-bead details. |
| `> 150` | **Heavy** | Dispatch `@researcher` + `@explore` in parallel via the `Agent` tool (use `dispatching-parallel-agents`). |

## Phase 1 — Beads, scale & handoff (orient.sh)

**Contract: Phase 1 is at most 2 tool calls** — one `bash scripts/orient.sh` call, plus one `Read` of the handoff doc if `path=` came back non-empty. Never more.

Run the data gatherer once:

```bash
bash scripts/orient.sh
```

It emits labeled RAW sections only — no verdicts, no freshness classification (that judgment stays with the agent, in Phase 4, working from these facts):

- `== scale ==` — `tracked=<N>` / `git=<0|1>`; feeds the Pre-step decision above.
- `== ledger ==` — `bd count --by-status` + `bd count --by-priority`; feeds the Phase 4 "Beads ledger" line.
- `== ready ==` — `bd ready -n 10`.
- `== in-progress ==` — `bd query "status=in_progress" -n 10`, run as its own call — the script never merges this with an open-status query into one `OR` (bd v1.0.5 silently drops rows when `OR` spans status clauses; never combine these into one `OR` query yourself either).
- `== blocked ==` — `bd blocked`.
- `== memories ==` — `bd memories` count line only (bodies come via the session hook).
- `== handoff ==` — runs `ls -t .internal/handoff/*.md | head -1` to find the newest inbox doc, then emits `path=`, `head_sha=`, `doc_sha=`, `doc_mtime=`, `last_commit_time=`, `inbox_count=` as raw facts (or `none` if the inbox is empty/absent — it is gitignored, absent on fresh clones). `ls -t` (mtime) is deliberate: handoff naming is `YYYY-MM-DD[-HHMMSS]-<topic>-handoff.md` and `-HHMMSS` is added only when a same-day doc already exists, so a lexical sort mis-orders same-day docs; mtime does not. Phase 4's existing freshness/recency logic consumes `doc_sha` / `head_sha` / `doc_mtime` / `last_commit_time` — the script itself never classifies them.

If `== handoff ==` returned a `path=` line, `Read` that file — the **second** Phase 1 tool call:

- **Inbox vs archive:** `.internal/handoff/` is an *unread inbox*. The doc read this run is moved to `.internal/handoff/archive/` at close (Phase 4 close steps); the script's non-recursive glob excludes the subdir, so archived docs are never re-detected. Only the newest inbox doc is read — `inbox_count=` carries any leftover count into Phase 4.
- **If `path=` is absent** (`none` line instead): skip the Read; note "no handoff doc found" in Phase 4.
- **Headline-only:** surface only the short state headline (branch / sha / topic / WIP one-liner). Never echo doc body sections that could carry secrets — treat the doc like a diff: read for context, quote only the headline.
- The handoff is a synthesized narrative source → cross-check it (Phase 4 freshness check) and tag it ⚠️, **never** "verified".

`bd prime` is NOT re-run here — the session hook already injected composed beads context. If it did
not (no `<beads-context>` block visible), run `bd prime` once before Phase 1.

If `bd` is not installed or `.beads/` is missing, the script's `== ledger ==` / `== ready ==` / `== in-progress ==` / `== blocked ==` / `== memories ==` sections come back `SKIP` — skip Phase 3 too, and emit "**Beads:** not installed/initialized — skipped" in the Phase 4 summary.

**Do NOT run `bd dolt status`, `bd dolt show`, or `bd dolt push`** — they aren't needed for orientation, and `bd dolt push` mutates the remote. Keep orientation read-only (`orient.sh` itself never calls them).

> **bd frugality: bounded output, one round trip.** Cap reads: `bd ready -n 10`,
> `bd show --short <id>` to skim (full `bd show` only when the body is needed),
> `bd memories <keyword>` (NEVER bare `bd memories` — it dumps the whole store).
> Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph`
> call, not a loop. Filter big outputs before they hit context
> (`... | grep -E "PATTERN" | head -20`). Keep write confirmations — they are evidence.
> **`--claim` boundary:** `bd ready --claim` ONLY in autonomous take-next-task flows
> (this skill's batch/wave dispatch). FORBIDDEN wherever the user picks the work —
> orientation, brainstorming, session close. Efficiency never erodes a consent gate.

## Phase 2 — Codebase exploration (single parallel batch, content varies by path)

Issue **all reads in one message, multiple tool calls in parallel**. Do NOT serialize.

### Session-handoff doc

Already detected and read in Phase 1 (see `== handoff ==` above) — not repeated here.

### Light path

- `find <repo-root> -maxdepth 1 -mindepth 1 | sort`
- `git log --oneline -15` + `git status -sb` + `git tag --sort=-v:refname | head -5`
- `Read` of `README.md`

### Medium path *(default)*

Light path, plus:

- `Read` of any of these that exist: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json`
- `Read` of any of these that exist: `CHANGELOG.md`, `CLAUDE.md`, `AGENTS.md`
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

If Phase 1's beads sections came back `SKIP` (no beads), skip Phase 3.

## Phase 4 — Synthesize the structured summary

Produce **exactly this Markdown structure**. Heading levels are H2; tables and lists scale to project content. Sections you cannot fill from earlier phases are marked with the degraded-state language from the Edge Cases table — never invented.

**Evidence + confidence convention:**

- **Inferred/synthesized claims** ("What it is", "Architecture Highlights", "Known operational quirks") each carry `[<glyph> source: <file/cmd>]` — glyph is ✅ high / ⚠️ medium / ❓ low — plus `verify: <what>` when below high.
- **Deterministically-verified sections** (Repo Layout from `find`, Git from git, Beads ledger from `bd count`) are ground truth — labeled `(verified)` at the heading, no per-line tags. Tag where trust varies, never as filler.

**Cross-checks to compute (compute these yourself, all paths — never delegated to sub-agents):**

- **Working tree:** from `git status --porcelain` (full list incl. untracked, status codes `M`/`A`/`D`/`R`/`??`) + `git diff --numstat` (added/deleted per tracked file; binary shows `-`). Rank tracked changes by added+deleted; show top-N with `+X/-Y` counts; render binary as `(binary)`; list the untracked count separately. Never dump the diff.
- **Continuity check (in-progress beads only):** resolve the base branch as `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name), falling back to `main` then `master`; if none resolves, mark the check "unavailable". For each in-progress bead, run `git log --grep="<bead-id>" --oneline <base>`. If the bead ID appears in a commit reachable from the base branch, flag it advisory: `⚠️ <bead> appears in <sha> on <base> — verify it shouldn't be closed`. A multi-commit epic legitimately keeps shipping while open, so judge — do not auto-conclude. A bead whose ID is in no commit is NOT flagged. Skip the check when beads are absent. Deeper hygiene (stale branches, orphans, lint) → point to `bd doctor` / `bd stale` / `bd orphans` / `bd recompute-blocked` (after a pull); do not reimplement it here.
- **Handoff freshness + recency check (if a doc was read):** two parts.
  1. *Claims cross-check* (existing): compare the handoff's stated branch / sha / in-progress claims against live `git` + `bd` state; flag divergence **advisory** (e.g. doc says "in progress X" but X is closed/shipped) — never trust the doc over live state.
  2. *HEAD-recency* — does the doc describe the last session, or an older one HEAD has moved past? Parse the recorded sha from the **`@ <sha>` token** on the "Current State (TL;DR)" branch line — match the hex *immediately after* `@` (through optional spaces/backticks/asterisks), so a bare `@mention` or email earlier in the doc, and the other commit shas in the "What Shipped" section, can't false-match:

     ```bash
     DOC="<path>"; HEAD=$(git rev-parse HEAD)
     DOC_SHA=$(grep -m1 -oE '@ *[`*]*[0-9a-f]{7,40}' "$DOC" | grep -oE '[0-9a-f]{7,40}' | head -1)
     case "$HEAD" in "$DOC_SHA"*) SHA_IS_HEAD=1 ;; *) SHA_IS_HEAD=0 ;; esac  # prefix-aware: handoffs record the SHORT sha
     if [ -n "$DOC_SHA" ] && [ "$SHA_IS_HEAD" = 1 ]; then
       echo fresh
     elif [ -n "$DOC_SHA" ] && git merge-base --is-ancestor "$DOC_SHA" HEAD 2>/dev/null; then
       echo possibly-stale            # HEAD has moved past the handoff's sha
     else                              # sha absent / not an ancestor / 0-or-many → mtime fallback
       DOC_MTIME=$(stat -c %Y "$DOC" 2>/dev/null || stat -f %m "$DOC")
       if [ -n "$DOC_MTIME" ] && [ "$DOC_MTIME" -lt "$(git log -1 --format=%ct)" ]; then
         echo possibly-stale           # doc older than the latest commit
       else
         echo unavailable              # emit the 'unavailable' token in the Last-handoff line
       fi
     fi
     ```

     The verdict is **advisory-only** — a soft label, never a destructive action — so the mtime fallback's imprecision (a `touch`/`checkout` can perturb mtime) is acceptable; it errs toward "possibly stale", the safe direction. No git / no commits → **freshness unavailable**. If no doc was found, the whole check is "none found".

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
**Last handoff:** <path> (<date>) — <one-line headline>. Freshness: <✓ fresh — sha == HEAD & matches live | ⚠️ possibly stale — HEAD is ahead of the handoff's recorded sha <DOC_SHA>; treated as background context, not the last session's outcome | ⚠️ doc says X, live is Y | unavailable | none found>.<append ` (+N older unread handoff(s) in inbox — not consumed this run)` when the inbox holds more than one `*.md`; N = count of `.internal/handoff/*.md` minus the one read>

| Bead | Pri | Title |
|---|---|---|
<Up to 10 open ready beads, sorted by priority. Top 3 were drilled into in Phase 3. Source: `bd ready`, or `bd query "status=open" --sort priority --limit 10` for the full open set.>

## Recent Activity
- <last 3–5 commits as a narrative of what shipped> [source: git log]
- <in-progress beads + where they were mid-way> [source: bd query in-progress]
- <after compaction: the prior in-session thread / decisions> [source: handoff doc]
<Backward delta only. Degrades to "Fresh session — no prior in-session delta" when none. Does NOT restate the open-ready bead table above, nor the Last release line.>

**Known operational quirks:** <from `bd memories` keyword scan + `bd kv list | grep '^bsp.kb'` (reference-class KB); from docs/known-issues/* if present> [source: bd memories + bsp.kb]
**Other captured memories:** <one line per memory not surfaced above>

---
<after-compaction only AND only when the handoff verdict is **fresh**: "Welcome back — last thread was <X>." If the verdict is **possibly stale / unavailable**, do NOT assert it is the last session — instead: "Note: the newest handoff on disk (<date>, sha <DOC_SHA>) predates HEAD — treating it as background context, not necessarily the last session.">
I'm ready for your next instruction. Highest-priority unblocked work: **`<bead-id>`** (<priority> — <title>).
If you want to start it, the fitting skill is **<skill>** — but I'll wait for your call; I won't claim or begin anything.
```

### Verification Gate (run before emitting)

Validate each line; fix or mark degraded, then re-check. Only emit once all pass:

1. Every Current State fact (git, working tree, ledger, continuity) traces to a command you ran THIS session — not memory, not assumption.
2. Every inferred claim has a confidence glyph + source tag.
3. Any section you could not fill from a command → degraded-state language from the Edge Cases table. NEVER invent.
4. The continuity check ran (or is marked skipped/unavailable).
5. The latest handoff doc was read and freshness+recency-checked — classified **fresh / possibly-stale / unavailable** — and the terminal "Welcome back" line is suppressed when not fresh (or marked "none found" if the inbox was empty).
6. The Progress Checklist is fully ticked (or items marked skipped with reason).

The trailing "I'm ready" line is the **terminal contract**: the skill stops here. Do NOT auto-claim the next bead. Do NOT start working on anything. The user drives the next move.

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

If orientation surfaced a Phase-1 memory that is now stale or wrong, remove it: `bd forget <id>`.

**Prune superseded continuation pointers.** Session-handoff writes a `continuation-*` pointer memory each run; they accumulate. After emitting the summary, cap them at one:

- **Keep** the `continuation-*` memory paired with the handoff doc you just read (content linkage — not a date-string sort).
- **Forget the rest** — match the `continuation-` **key prefix** only (never memory body text, which could match an unrelated semantic memory): `bd forget <key>` with a cited reason.
- **Fail safe:** if you cannot unambiguously link the keeper to the doc read, keep ALL `continuation-*` memories and skip the prune this run — never guess-delete.
- **Report it** (never silent): "Pruned N superseded continuation pointers; kept `<key>`."
- This keep-newest policy is shared with **memory-curator** (which forbids dropping the latest continuation/handoff) — keep the two consistent.

**Archive the consumed handoff (final close action).** The close steps run in a **fixed order** — the archive MUST come after the continuation-prune, which needs the doc still in the inbox to link its keeper:

1. Emit the summary.
2. Capture memories (`bd remember`).
3. Prune `continuation-*` pointers (the step above).
4. **Archive the doc read this run** — only if a handoff was read:

   ```bash
   mkdir -p .internal/handoff/archive && mv -f "<doc>" .internal/handoff/archive/
   ```

   Move **only the single doc read this run** (older unread inbox docs stay — the recency check catches their staleness if they later surface).

   - **Best-effort, non-fatal, reported.** On success: "Archived consumed handoff `<name>` → `archive/`." On failure (permissions/disk/race): "⚠️ could not archive `<name>` (<reason>); left in inbox" and continue — the doc stays in the inbox and self-heals next session (re-read + recency-flagged).
   - **Re-run idempotency.** The doc is *moved, not deleted* — it remains readable under `archive/`, and a later run finds an empty inbox and skips.
   - This `mv` is the **single local mutation** getting-up-to-speed makes — on the gitignored `.internal/` path, non-destructive to tracked state and to beads. (`.internal/handoff/archive/` is covered by the wholesale `.internal/` gitignore — verified.)

## Edge Cases

| Condition | Behavior |
|---|---|
| No `.git` directory | Skip the git phase entirely; emit "**Git:** not a git repo" in the summary |
| `bd` not installed | `orient.sh` still runs (scale + handoff); its beads sections read `SKIP` — skip Phase 3 and the beads lines of Phase 4; emit "**Beads:** not installed — skipped" |
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
| `.internal/handoff/` absent or empty | Skip the handoff read; emit "no handoff doc found" in the Last-handoff line |
| Handoff written to a non-default path | Not auto-detected; orientation only checks the default `.internal/handoff/` |
| Newest handoff predates latest commit / last session wrote no handoff | HEAD-recency check marks it **possibly stale**; narration suppresses "last session" — flag, don't mis-attribute (the `mu0s` case) |
| Inbox holds multiple unread handoffs | Read only the newest; append `+N older unread` to the Last-handoff line; older docs drain over later sessions |
| `mv` to `archive/` fails at close | Non-fatal: warn "left in inbox" and continue; the doc is re-read and recency-flagged next session |

## Red Flags / Anti-Rationalization

These thoughts mean STOP — you're rationalizing skipping orientation:

| Thought | Reality |
|---|---|
| "I already explored this last session" | Sessions don't carry state. Re-orient. |
| "I'll skip beads commands — I'll use TodoWrite" | This project IS beads. Beads context is mandatory — the session hook injects it, or run `bd prime` if it didn't. TodoWrite is forbidden. |
| "The README is enough" | README skips beads state, open work, and known issues. Run the full pipeline. |
| "I'll skip Phase 3 — looking at open beads is busywork" | Phase 3 is what surfaces "this Dolt setup is broken" before you waste 20 minutes on it. |
| "I'll auto-claim the top P0" | Forbidden. Orient and stop. User drives. |
| "This is a small repo, I can skim" | Run the Light path of this skill. It's still 30 seconds and produces a summary you can refer back to. |
| "The summary looks complete, I'll emit it" | Run the Verification Gate first — every line traces to a command this session. |
| "I'll tag confidence later" | An inferred claim without a glyph + source is an unverified guess. Tag inline. |
| "Beads and git probably agree" | Run the continuity check. A shipped-but-still-open bead is exactly what it catches. |
| "I'll suggest they start the top bead" | Suggest the *skill*; don't claim or begin. The terminal contract is absolute. |
| "I'll skip the handoff — `bd prime` covers it" | The handoff doc holds the narrative thread (WIP, decisions, loose threads) that beads context does not. Read it. |
| "`bd ready --claim` is efficient" | It's a consent violation here. Terminal contract wins — orient and stop. |

## Output Contract

The skill is complete when you have produced the structured summary, **the Verification Gate has passed**, AND emitted the trailing "I'm ready for your next instruction" line. No claiming, no continuation. Wait for user input.

## Integration

**Invoked by:** User on-demand or at session start. No other skill invokes this directly.

**Uses:** **dispatching-parallel-agents** — heavy path (150+ tracked files) dispatches @researcher + @explore in parallel.

**Pairs with:** **project-init** — for fresh/empty repos with nothing to orient on, use project-init instead.
