---
name: getting-up-to-speed
description: Orients on an unfamiliar or stale codebase at the start of a session, after compaction, or whenever the project state is unclear. Loads beads context, deep-dives the codebase, and produces a structured 'current state' summary. Triggers on phrases like "catch me up", "where are we", "orient me", "what's the state of this project", "bring me up to speed", "load context", "session orientation".
---

# Getting Up to Speed

Orient on the project before any work: re-derive the current state from **ground truth** — commands run THIS session, never memory — and stop for the user's call.

**Announce at start:** "I'm using the getting-up-to-speed skill to orient on the project."

**When NOT to use:** a single targeted question; already oriented this session and nothing changed; a fresh empty repo (use the `project-init` skill).

**frugal bd kernel:** bounded reads only; never bare `bd memories`. `bd ready --claim` is FORBIDDEN here — orientation ends at the terminal contract and the user picks the work.

## Steps

Copy this checklist into your working response and tick as you go:

- [ ] 1 Gathered (orient.sh + handoff)
- [ ] 2 Explored (path by scale)
- [ ] 3 Drilled (top beads)
- [ ] 4 Summary emitted through the gate
- [ ] 5 Closed (capture → prune → archive)

### 1 — Gather (at most 2 tool calls)

Run `bash <skill-base-dir>/scripts/orient.sh` once. It emits raw labeled sections: `scale` (tracked=N, git=0|1), `ledger`, `ready`, `in-progress`, `blocked`, `memories` (count only), `handoff` (`path=`, `head_sha=`, `doc_sha=`, `doc_mtime=`, `last_commit_time=`, `inbox_count=`). It never runs `bd dolt` commands — orientation stays read-only. If `== handoff ==` has a `path=` line, `Read` that file (the second call); quote only its short headline — never echo doc body sections that could carry secrets. The handoff is a synthesized narrative → cross-check it in step 4 and tag it ⚠️, never "verified".

- No `<beads-context>` block visible this session → run `bd prime` once before the script.
- bd missing / `.beads` absent → the bd sections read SKIP: skip step 3 and the beads lines of the summary; emit "**Beads:** not installed — skipped".

Done when: every orient.sh section is read, and the handoff is read or recorded as "none".

### 2 — Explore (one parallel batch — never serialize)

Pick the path from `tracked=`:

- **< 40 (Light):** top-level `find`, `git log --oneline -15` + `git status -sb` + top 5 tags, `Read` README.
- **40–150 (Medium, default):** Light + `Read` any of package.json/pyproject.toml/Cargo.toml/go.mod, CHANGELOG/CLAUDE.md/AGENTS.md, project manifests; `find` on skills/agents/docs/hooks/tests/src/lib that exist.
- **> 150 (Heavy):** dispatch via the `dispatching-parallel-agents` skill — @researcher (CLAUDE/README/CHANGELOG → architecture, <300 words) + @explore (layout + file counts, <200 words) in one message; then read 1–3 files they flag.

Done when: every planned read of the chosen path has returned.

### 3 — Drill (bounded)

`bd show <id> | head -30` on the top 3 open ready beads by priority — this feeds the "Known operational quirks" line. The summary table still lists up to 10 from `bd ready`.

Done when: 3 beads drilled (or step skipped with reason).

### 4 — Synthesize through the gate

Compute the cross-checks yourself (never delegated):

- **Working tree:** `git status --porcelain` + `git diff --numstat`; top-N by churn with `+X/-Y`, binary as `(binary)`, untracked as a count. Never dump the diff.
- **Continuity (in-progress beads only):** base branch from `git symbolic-ref refs/remotes/origin/HEAD` (fallback main/master); `git log --grep="<bead-id>" --oneline <base>` per bead. A hit is **advisory**: `⚠️ <bead> appears in <sha> on <base> — verify it shouldn't be closed`. No commit hit = NOT flagged. Deeper hygiene → point at `bd doctor` / `bd stale`.
- **Handoff freshness (if a doc was read):** compare its stated branch/sha/claims to live git+bd (divergence is advisory), then HEAD-recency from the `@ <sha>` token on its TL;DR branch line:

  ```bash
  DOC="<path>"; HEAD=$(git rev-parse HEAD)
  DOC_SHA=$(grep -m1 -oE '@ *[`*]*[0-9a-f]{7,40}' "$DOC" | grep -oE '[0-9a-f]{7,40}' | head -1)
  case "$HEAD" in "$DOC_SHA"*) echo fresh ;; *)
    if [ -n "$DOC_SHA" ] && git merge-base --is-ancestor "$DOC_SHA" HEAD 2>/dev/null; then echo possibly-stale
    else
      DOC_MTIME=$(stat -c %Y "$DOC" 2>/dev/null || stat -f %m "$DOC")
      [ -n "$DOC_MTIME" ] && [ "$DOC_MTIME" -lt "$(git log -1 --format=%ct)" ] && echo possibly-stale || echo unavailable
    fi ;;
  esac
  ```

  The verdict is advisory-only; sha absent / no git → `unavailable`; no doc → "none found".

Then emit **exactly** this structure. Deterministic sections (`(verified)`) carry no per-line tags; inferred claims carry `[<✅|⚠️|❓> source: <file/cmd>]` (+ `verify:` below high confidence). Sections you cannot fill use the degraded-state language in [references/edge-cases.md](references/edge-cases.md) — never invented.

```markdown
## What `<project>` Is
<1–3 sentences: language, purpose, lineage.> [✅ source: ...]

## Architecture Highlights
<3–6 sourced bullets with glyphs.>

## Repo Layout (verified)
<code-fenced tree of directories actually present per find.>

## Current State
**Git:** <branch> · <clean | N uncommitted> · <sync vs origin> · latest `<sha>` <subject> · tags <top 5>.
**Working tree:** <top-N +X/-Y · +K untracked> (omit if clean).
**Last release:** <version + CHANGELOG gist; [Unreleased] count>.
**Beads ledger:** <total · closed · open · in-progress · blocked> (verified).
**Continuity check:** <✓ | ⚠️ advisory | skipped | unavailable>.
**Last handoff:** <path> (<date>) — <headline>. Freshness: <✓ fresh | ⚠️ possibly stale — HEAD ahead of <DOC_SHA> | unavailable | none found>.<+N older unread if inbox_count>1>

| Bead | Pri | Title |
<up to 10 open ready beads by priority>

## Recent Activity
<3–5 commits as narrative · in-progress beads · prior thread from handoff. Degrades to "Fresh session — no prior in-session delta".>

**Known operational quirks:** <from bd memories keyword scan + kb-labeled beads (`bd search`) + docs/known-issues>
**Other captured memories:** <count + retrieval pointer>

---
<"Welcome back — last thread was <X>." ONLY when the freshness verdict is fresh; if possibly-stale: "Note: the newest handoff (<date>, <DOC_SHA>) predates HEAD — background context, not necessarily the last session.">
I'm ready for your next instruction. Highest-priority unblocked work: **<bead-id>** (<pri> — <title>).
If you want to start it, the fitting skill is **<skill>** — but I'll wait for your call; I won't claim or begin anything.
```

**Verification gate — run before emitting, fix or degrade, then re-check:**
1. Every Current State fact traces to a command run THIS session.
2. Every inferred claim carries glyph + source.
3. Unfillable sections use edge-cases degraded language — never invented.
4. Continuity + freshness checks ran (or are marked skipped/unavailable); the "Welcome back" line is suppressed unless fresh.
5. The checklist is fully ticked (or items marked skipped with reason).

Done when: all five pass and the summary is emitted ending on the terminal contract.

### 5 — Close

1. Capture durable, evidence-backed insights: `bd remember "<kind>: <insight>"`. Stale Phase-1 memory → `bd forget <id>`.
2. Prune continuation pointers to one: keep the memory paired with the doc read; forget the rest matching the `continuation-` **key prefix** only. Ambiguous keeper → keep ALL and skip (never guess-delete). Report: "Pruned N superseded continuation pointers; kept `<key>`."
3. Archive the consumed doc (only if one was read; AFTER the prune):
   `mkdir -p .internal/handoff/archive && mv -f "<doc>" .internal/handoff/archive/`
   Report "Archived consumed handoff `<name>` → `archive/`." — or on failure "⚠️ could not archive (<reason>); left in inbox" and continue (it self-heals next session). This mv is the skill's only local mutation.

Done when: all three reported (or explicitly skipped).

## Terminal contract

The summary's closing lines are the contract: Do NOT auto-claim the next bead. Do NOT start work. Suggest the fitting *skill* and wait — the user drives.

## Red flags

| Pressure | Rule |
|---|---|
| "I remember this repo" | Sessions don't carry state — re-derive from ground truth. |
| "The summary looks complete" | Emit only through the verification gate. |
| "I'll claim the top bead to save time" | Terminal contract wins — `--claim` is forbidden here. |
| "The handoff says so" | Handoffs are narrative — cross-check against live state, tag ⚠️. |
| "Skimming is enough for a small repo" | Run the Light path; it still ends in a gated summary. |

## Edge cases

Anything off-path — no git, detached HEAD, empty log, hundreds of changed files, multi-doc inbox, archive failure, bd errors — has a prescribed behavior in [references/edge-cases.md](references/edge-cases.md); open it whenever a step returns something unexpected.

## Integration

**Uses:** `dispatching-parallel-agents` (Heavy path). **Pairs with:** `project-init` (fresh/empty repos).
