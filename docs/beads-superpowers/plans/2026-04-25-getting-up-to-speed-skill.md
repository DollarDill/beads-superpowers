# getting-up-to-speed Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Each Task becomes a bead (`bd create -t task --parent beads-superpowers-53x`). Steps within tasks use checkbox (`- [ ]`) syntax for human readability.

**Goal:** Add a new beads-superpowers skill — `getting-up-to-speed` — that codifies the session-orientation workflow: parallel beads context commands, depth-adaptive codebase deep-dive, structured "current state" summary, terminating without auto-claim.

**Architecture:** Single SKILL.md file under `skills/getting-up-to-speed/` plus skill-count + table-row updates to README.md, CHANGELOG.md, and CLAUDE.md. Pure additive — no existing skill modified, no hook changed, no plugin manifest version bump.

**Tech Stack:** Markdown only. Validation: `markdownlint` + `ls -d skills/*/ | wc -l` (CI assertion is `-lt 15`, so 19→20 passes without CI changes).

**Spec:** `docs/beads-superpowers/specs/2026-04-25-getting-up-to-speed-skill-design.md`

**Epic bead:** `beads-superpowers-53x`

**Worktree:** Implementation runs in a worktree (`getting-up-to-speed`) branched from `main`. Created at S7 by the executor via `using-git-worktrees`.

---

## File Structure

| File | Responsibility | Status |
|---|---|---|
| `skills/getting-up-to-speed/SKILL.md` | The skill itself — frontmatter + 4-phase pipeline + output template + edge-case table + anti-rationalization table | NEW |
| `README.md` | Skill count `19 → 20` (3 occurrences) + new row in skills table | MODIFY |
| `CHANGELOG.md` | New `### Added` entry under `[Unreleased]` | MODIFY |
| `CLAUDE.md` | Skill count `19 → 20` (3 occurrences) + new row in skills table | MODIFY |
| `.claude-plugin/plugin.json` | `description`: "15 mandatory skills" → "20 mandatory skills" (stale since v0.2.0) | MODIFY |
| GitHub repo description (via `gh repo edit`) | Same stale "15" → "20" | EXTERNAL |

**Sequencing:** Tasks 1–4 build the SKILL.md sequentially (each appends a section). Tasks 5–7 (README, CHANGELOG, CLAUDE) are independent of each other — can be parallelized but each depends on Tasks 1–4 being complete (the skill must exist before docs reference it). Task 8 is end-to-end behavior validation.

```
T1 (skill: frontmatter + Pre-step + Phase 1)
  └─→ T2 (skill: Phase 2 + adaptive routing)
        └─→ T3 (skill: Phase 3 + Phase 4 + output template)
              └─→ T4 (skill: edge cases + anti-rationalization tables)
                    ├─→ T5 (README)
                    ├─→ T6 (CHANGELOG)
                    ├─→ T7 (CLAUDE.md)
                    └─→ T9 (plugin.json + GitHub repo description)
                          └─→ T8 (behavior validation, runs after all docs land)
```

**Beads dependency setup** (run after the executor creates the per-task child beads):
```bash
bd dep add <T2-id> <T1-id>
bd dep add <T3-id> <T2-id>
bd dep add <T4-id> <T3-id>
bd dep add <T5-id> <T4-id>
bd dep add <T6-id> <T4-id>
bd dep add <T7-id> <T4-id>
bd dep add <T9-id> <T4-id>
bd dep add <T8-id> <T5-id>
bd dep add <T8-id> <T6-id>
bd dep add <T8-id> <T7-id>
bd dep add <T8-id> <T9-id>
```

---

## Task 1: SKILL.md — frontmatter + Pre-step + Phase 1 (beads)

**Files:**
- Create: `skills/getting-up-to-speed/SKILL.md`

- [ ] **Step 1.1: Verify skill does not yet exist (failing-test equivalent)**

```bash
ls -d /Users/dillonfrawley/workplace/beads-superpowers/skills/getting-up-to-speed 2>&1
```
Expected: `ls: ...skills/getting-up-to-speed: No such file or directory`

```bash
ls -d /Users/dillonfrawley/workplace/beads-superpowers/skills/*/ | wc -l
```
Expected: `19`

- [ ] **Step 1.2: Create skill directory and write the file's first section**

Create `skills/getting-up-to-speed/SKILL.md` with this exact content:

````markdown
---
name: getting-up-to-speed
description: Use at the start of a session, after compaction, or whenever you need to orient on an unfamiliar or stale codebase. Loads beads context, deep-dives the codebase, and produces a structured 'current state' summary. Triggers on phrases like "catch me up", "where are we", "orient me", "what's the state of this project", "bring me up to speed", "load context", "session orientation".
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

## Pre-step: Detect repo scale

Run this single command first to pick a path:

```bash
TRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
HAS_BEADS=$([ -d .beads ] && echo 1 || echo 0)
HAS_GIT=$([ -d .git ] && echo 1 || echo 0)
echo "tracked=$TRACKED beads=$HAS_BEADS git=$HAS_GIT"
```

| Tracked files | Path | Behavior |
|---|---|---|
| `< 50` or no `.git` | **Light** | bd commands + read README + git log; skip Phase 2 medium drilldown. |
| `50 – 500` | **Medium** *(default)* | Parallel bd + parallel codebase reads + key-file drilldown + open-bead details. |
| `> 500` | **Heavy** | Dispatch `@researcher` + `@explore` in parallel via the `Agent` tool (use `dispatching-parallel-agents`). |

## Phase 1 — Beads context (single parallel batch)

Issue all six commands in **one message, multiple Bash tool calls in parallel**:

- `bd prime`
- `bd ready`
- `bd blocked`
- `bd list --status open --status in_progress`
- `bd memories`
- `bd stats`

If `bd` is not installed or `.beads/` is missing, skip Phase 1 entirely and emit "**Beads:** not installed/initialized — skipped" in the Phase 4 summary.

**Do NOT run `bd dolt status`, `bd dolt show`, or `bd dolt push` here** — these fail in embedded-Dolt-mode repos and are not needed for orientation.
````

- [ ] **Step 1.3: Verify skill count incremented**

```bash
ls -d /Users/dillonfrawley/workplace/beads-superpowers/skills/*/ | wc -l
```
Expected: `20`

- [ ] **Step 1.4: Verify markdownlint passes on the new file**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'skills/getting-up-to-speed/SKILL.md' 2>&1
```
Expected: clean exit (no output, exit code 0). If markdownlint isn't globally installed, run via the project's existing config: the `.markdownlint-cli2.jsonc` and `.markdownlintignore` files at repo root govern.

- [ ] **Step 1.5: Commit**

```bash
git add skills/getting-up-to-speed/SKILL.md
git commit -m "feat: add getting-up-to-speed skill — frontmatter + Phase 1 (bd-53x.T1)"
```

---

## Task 2: SKILL.md — Phase 2 (codebase exploration)

**Files:**
- Modify: `skills/getting-up-to-speed/SKILL.md` (append)

- [ ] **Step 2.1: Append Phase 2 section**

Append exactly this to `skills/getting-up-to-speed/SKILL.md`:

````markdown

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
````

- [ ] **Step 2.2: Verify markdownlint still clean**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'skills/getting-up-to-speed/SKILL.md' 2>&1
```
Expected: clean exit.

- [ ] **Step 2.3: Commit**

```bash
git add skills/getting-up-to-speed/SKILL.md
git commit -m "feat: add Phase 2 (adaptive codebase exploration) (bd-53x.T2)"
```

---

## Task 3: SKILL.md — Phase 3 (drilldown) + Phase 4 (output template)

**Files:**
- Modify: `skills/getting-up-to-speed/SKILL.md` (append)

- [ ] **Step 3.1: Append Phase 3 + Phase 4 sections**

Append exactly this:

````markdown

## Phase 3 — Top open beads drilldown (all paths)

- Run `bd show <id> | head -30` on the **top 3 open ready beads by priority** from Phase 1's `bd ready` output.
- This is the agent's drilldown — used to feed the "Known operational quirks" line in the Phase 4 summary.
- The output table in Phase 4 lists **up to 10 open ready beads** (not just the 3 drilled), so the user sees the whole queue.

If Phase 1 was skipped (no beads), skip Phase 3.

## Phase 4 — Synthesize the structured summary

Produce **exactly this Markdown structure**. Heading levels are H2; tables and lists scale to project content. Sections you cannot fill from earlier phases are marked with the degraded-state language from the Edge Cases table — never invented.

```markdown
## What `<project>` Is
<1–3 sentence synthesis. Mentions language/runtime, primary purpose, and any merge/fork lineage if discoverable from CHANGELOG/README.>

| Layer | Source | Role |
|---|---|---|
<Optional table — used when project merges/wraps multiple subsystems. Skipped for simple repos.>

## Architecture Highlights
- **<key design decision 1>** — <one-line consequence>
- **<key design decision 2>** — <one-line consequence>
<3–6 bullets, sourced from CLAUDE.md / README / a METHODOLOGY-style doc.>

## Repo Layout (verified)
<code-fenced tree, ONLY directories actually present per `find` output. Never invented.>

## Current State
**Git:** <branch> <clean|N changes>, <in sync|N ahead|N behind> origin. Latest = `<sha>` <subject>. Tags: <top 5>.
**Last release:** <if version detectable> shipped: <CHANGELOG bullet summary>. `[Unreleased]` <empty|has N entries>.
**Beads ledger:** <total> total · <closed> closed · <open> open · <in-progress> · <blocked>.

| Bead | Pri | Title |
|---|---|---|
<Up to 10 open ready beads, sorted by priority. Top 3 were drilled into in Phase 3.>

**Known operational quirks:** <from `bd memories` keyword scan; from docs/known-issues/* if present>
**Other captured memories:** <one line per memory not surfaced above>

---
I'm ready for your next instruction. The highest-priority unblocked work right now is **`<bead-id>`** (<priority> — <title>).
```

The trailing "I'm ready" line is the **terminal contract**: the skill stops here. Do NOT auto-claim the next bead. Do NOT start working on anything. The user drives the next move.
````

- [ ] **Step 3.2: Verify markdownlint still clean**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'skills/getting-up-to-speed/SKILL.md' 2>&1
```
Expected: clean exit.

- [ ] **Step 3.3: Commit**

```bash
git add skills/getting-up-to-speed/SKILL.md
git commit -m "feat: add Phase 3 + Phase 4 with mandated output template (bd-53x.T3)"
```

---

## Task 4: SKILL.md — Edge Cases + Anti-Rationalization tables

**Files:**
- Modify: `skills/getting-up-to-speed/SKILL.md` (append)

- [ ] **Step 4.1: Append the two reference tables**

Append exactly this:

````markdown

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

## Output Contract

The skill is complete when you have produced the structured summary AND emitted the trailing "I'm ready for your next instruction" line. No claiming, no continuation. Wait for user input.
````

- [ ] **Step 4.2: Verify markdownlint still clean**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'skills/getting-up-to-speed/SKILL.md' 2>&1
```
Expected: clean exit.

- [ ] **Step 4.3: Verify zero TodoWrite residue introduced**

```bash
grep -r "TodoWrite" /Users/dillonfrawley/workplace/beads-superpowers/skills/getting-up-to-speed/ | grep -v "Do NOT use" | grep -v "replaces" | grep -v "TodoWrite is forbidden" || echo "clean"
```
Expected: `clean` (the only TodoWrite hits should be the negative reference inside the Red Flags table, which is excluded by the grep filters above).

- [ ] **Step 4.4: Verify total line count is in the 180–250 range from the spec**

```bash
wc -l /Users/dillonfrawley/workplace/beads-superpowers/skills/getting-up-to-speed/SKILL.md
```
Expected: between 150 and 280 lines (loose bound around the spec's 180–250 estimate).

- [ ] **Step 4.5: Commit**

```bash
git add skills/getting-up-to-speed/SKILL.md
git commit -m "feat: add edge cases + anti-rationalization tables, complete SKILL.md (bd-53x.T4)"
```

---

## Task 5: README.md — skill count + table row

**Files:**
- Modify: `README.md:42` `README.md:64` `README.md:185`
- Modify: `README.md` skills-reference table (insert new row after `auditing-upstream-drift`)

- [ ] **Step 5.1: Update the three "19" mentions to "20"**

Make these three edits to `README.md`:

| Line | Before | After |
|---|---|---|
| 42 | `In Claude Code, run `/skills` to verify — you should see 19 skills available.` | `In Claude Code, run `/skills` to verify — you should see 20 skills available.` |
| 64 | `- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — 19 mandatory skills enforcing TDD, brainstorming, systematic debugging, and two-stage code review.` | `- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — 20 mandatory skills enforcing TDD, brainstorming, systematic debugging, and two-stage code review.` |
| 185 | `├── skills/                 19 beads-native skills` | `├── skills/                 20 beads-native skills` |

- [ ] **Step 5.2: Add the skills table row**

In the "Skills reference" table (currently last row is `auditing-upstream-drift`), insert as the new last row:

```markdown
| **getting-up-to-speed** | Meta | Start of session or post-compaction — runs bd commands, deep-dives the codebase, produces a structured current-state summary |
```

- [ ] **Step 5.3: Verify both edits landed**

```bash
grep -c "20 skills" /Users/dillonfrawley/workplace/beads-superpowers/README.md
grep -c "20 mandatory" /Users/dillonfrawley/workplace/beads-superpowers/README.md
grep -c "20 beads-native" /Users/dillonfrawley/workplace/beads-superpowers/README.md
grep -c "getting-up-to-speed" /Users/dillonfrawley/workplace/beads-superpowers/README.md
```
Expected: each command outputs `1` or higher.

- [ ] **Step 5.4: markdownlint pass**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'README.md' 2>&1
```
Expected: clean exit.

- [ ] **Step 5.5: Commit**

```bash
git add README.md
git commit -m "docs: README — bump skill count 19→20, add getting-up-to-speed row (bd-53x.T5)"
```

---

## Task 6: CHANGELOG.md — `[Unreleased]` entry

**Files:**
- Modify: `CHANGELOG.md` `[Unreleased]` section

- [ ] **Step 6.1: Find the current `[Unreleased]` `### Added` block**

```bash
grep -n "Unreleased\|### Added\|### Changed" /Users/dillonfrawley/workplace/beads-superpowers/CHANGELOG.md | head -10
```
Confirms `[Unreleased]` exists and shows whether `### Added` already exists under it.

- [ ] **Step 6.2: Insert this entry under `[Unreleased] → ### Added`**

If `### Added` already exists under `[Unreleased]`, append the bullet to it. If not, create `### Added` immediately after `## [Unreleased]`.

```markdown
- `getting-up-to-speed` skill — depth-adaptive session orientation: parallel bd context commands, parallel codebase deep-dive (light/medium/heavy by tracked-file count), top-3-open-beads drilldown, mandated structured "current state" summary, terminating without auto-claim. Brings skill total from 19 → 20.
```

- [ ] **Step 6.3: Verify**

```bash
grep -A 2 "getting-up-to-speed skill" /Users/dillonfrawley/workplace/beads-superpowers/CHANGELOG.md | head -5
```
Expected: shows the new bullet.

- [ ] **Step 6.4: markdownlint pass**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'CHANGELOG.md' 2>&1
```
Expected: clean exit.

- [ ] **Step 6.5: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG — add getting-up-to-speed under [Unreleased] (bd-53x.T6)"
```

---

## Task 7: CLAUDE.md — skill count + skills table row

**Files:**
- Modify: `CLAUDE.md:13` `CLAUDE.md:28` `CLAUDE.md:87`
- Modify: `CLAUDE.md` skills table

- [ ] **Step 7.1: Update the three "19" mentions to "20"**

| Line | Before | After |
|---|---|---|
| 13 | `1. **Process discipline** — 19 composable skills enforcing TDD, brainstorming, systematic debugging, two-stage code review, and verification` | `1. **Process discipline** — 20 composable skills enforcing TDD, brainstorming, systematic debugging, two-stage code review, and verification` |
| 28 | `skills/                    # 19 beads-native skills (auto-discovered)` | `skills/                    # 20 beads-native skills (auto-discovered)` |
| 87 | `## Skills (19 Total)` | `## Skills (20 Total)` |

- [ ] **Step 7.2: Add the skills table row**

In the `## Skills (20 Total)` table, insert the new row as the last row (after `auditing-upstream-drift`):

```markdown
| getting-up-to-speed | Session orientation — bd context + adaptive codebase deep-dive + structured current-state summary |
```

- [ ] **Step 7.3: Verify**

```bash
grep -c "20 composable" /Users/dillonfrawley/workplace/beads-superpowers/CLAUDE.md
grep -c "20 beads-native" /Users/dillonfrawley/workplace/beads-superpowers/CLAUDE.md
grep -c "20 Total" /Users/dillonfrawley/workplace/beads-superpowers/CLAUDE.md
grep -c "getting-up-to-speed" /Users/dillonfrawley/workplace/beads-superpowers/CLAUDE.md
```
Expected: each `1` or higher.

- [ ] **Step 7.4: markdownlint pass**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && npx markdownlint-cli2 'CLAUDE.md' 2>&1
```
Expected: clean exit.

- [ ] **Step 7.5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md — bump skill count 19→20, add getting-up-to-speed row (bd-53x.T7)"
```

---

## Task 9: plugin.json description + GitHub repo description sync

**Files:**
- Modify: `.claude-plugin/plugin.json:3` (the `description` field)
- External: GitHub repo description (via `gh repo edit`)

**Why this task:** the `plugin.json` `description` and the GitHub repo description both contain the literal string "15 mandatory skills" — stale since v0.2.0 (we passed 15 long ago, currently at 20 with this PR). This is user-visible text on the marketplace and on the GitHub repo card, so it's a high-impact, low-risk update. `marketplace.json` does not contain a count so no change is needed there.

- [ ] **Step 9.1: Confirm the stale strings**

```bash
grep -n "15 mandatory" /Users/dillonfrawley/workplace/beads-superpowers/.claude-plugin/plugin.json
gh repo view DollarDill/beads-superpowers --json description --jq .description
```
Expected: both contain `15 mandatory skills`.

- [ ] **Step 9.2: Update `.claude-plugin/plugin.json`**

Change the `description` field from:
```text
Claude Code plugin merging Superpowers skills with Beads issue tracking. 15 mandatory skills + persistent task memory for AI coding agents.
```
to:
```text
Claude Code plugin merging Superpowers skills with Beads issue tracking. 20 mandatory skills + persistent task memory for AI coding agents.
```

- [ ] **Step 9.3: Validate plugin.json**

```bash
cd /Users/dillonfrawley/workplace/beads-superpowers && python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('valid')"
```
Expected: `valid`.

If `claude plugin validate` is available locally:
```bash
claude plugin validate /Users/dillonfrawley/workplace/beads-superpowers/.claude-plugin/plugin.json
```
Expected: validation passes.

- [ ] **Step 9.4: Update GitHub repo description**

```bash
gh repo edit DollarDill/beads-superpowers \
  --description "Claude Code plugin merging Superpowers skills with Beads issue tracking. 20 mandatory skills + persistent task memory for AI coding agents."
```
Expected: command exits 0 (no output is normal for `gh repo edit`).

- [ ] **Step 9.5: Verify GitHub description**

```bash
gh repo view DollarDill/beads-superpowers --json description --jq .description
```
Expected: prints the new string with `20 mandatory skills`.

- [ ] **Step 9.6: Commit the plugin.json change**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: plugin.json description — 15 → 20 mandatory skills (bd-53x.T9)"
```

GitHub repo description change is API-side and does not need a commit.

---

## Task 8: Behavior validation (manual, three scenarios)

**Files:**
- (No file modifications — validation only)

- [ ] **Step 8.1: Scenario 1 — invoke skill in this repo (medium path)**

In a fresh Claude Code session in this repo, type: `catch me up`. The agent should invoke `getting-up-to-speed` and produce a summary. Verify:
- Pre-step output shows `tracked >= 50` and `< 500` → medium path picked
- Phase 1: 6 bd commands run in parallel
- Phase 2: README, CHANGELOG, plugin.json, CLAUDE.md, top-level dirs read
- Phase 3: top 3 open beads drilled
- Phase 4 summary contains all six required sections (`## What ... Is`, `## Architecture Highlights`, `## Repo Layout`, `## Current State`, `**Known operational quirks**`, `I'm ready for your next instruction`)
- Embedded-Dolt-mode quirk surfaced from memories
- No `bd dolt push/show/status` calls attempted
- Skill terminates without auto-claiming any bead

- [ ] **Step 8.2: Scenario 2 — empty git repo (light path)**

```bash
SCRATCH=$(mktemp -d)
cd "$SCRATCH" && git init && touch README.md && git add README.md && git commit -m init
```
Then in a session targeted at `$SCRATCH`, type: `orient me`. Verify:
- Pre-step output shows `tracked == 1` → light path picked
- Phase 1: skill emits "Beads: not installed/initialized — skipped"
- Phase 2: only Light path reads (top-level dirs + git log + README) — no medium reads
- Phase 4 summary still produced, but Beads section shows degraded state
- `cd /Users/dillonfrawley/workplace/beads-superpowers && rm -rf "$SCRATCH"` cleanup

- [ ] **Step 8.3: Scenario 3 — loose folder, no git (degraded state)**

```bash
SCRATCH=$(mktemp -d)
cd "$SCRATCH"
```
Then in a session targeted at `$SCRATCH`, type: `where are we`. Verify:
- Pre-step output shows `git=0`
- Skill emits "Git: not a git repo" in the summary
- No Phase 2 git commands attempted
- Skill exits gracefully without errors
- Cleanup: `rm -rf "$SCRATCH"`

- [ ] **Step 8.4: Document validation outcomes**

Append a short validation note to the bottom of `docs/beads-superpowers/specs/2026-04-25-getting-up-to-speed-skill-design.md` under a new `## Validation Results` heading: one bullet per scenario with PASS/FAIL and any deviation notes.

- [ ] **Step 8.5: Commit (only if Step 8.4 made changes)**

```bash
git add docs/beads-superpowers/specs/2026-04-25-getting-up-to-speed-skill-design.md
git commit -m "docs: validation results for getting-up-to-speed skill (bd-53x.T8)"
```

---

## Self-Review Checklist (executor runs this before requesting code review)

- [ ] All 9 tasks complete, every step's checkbox ticked
- [ ] `ls -d skills/*/ | wc -l` returns `20`
- [ ] No new TodoWrite references introduced (`grep -r "TodoWrite" skills/getting-up-to-speed/ | grep -v "Do NOT use" | grep -v "replaces" | grep -v "TodoWrite is forbidden"` is empty)
- [ ] `markdownlint` clean across `skills/getting-up-to-speed/SKILL.md`, `README.md`, `CHANGELOG.md`, `CLAUDE.md`
- [ ] `plugin.json` description string contains `20 mandatory skills` (not `15`)
- [ ] GitHub repo description (via `gh repo view`) contains `20 mandatory skills`
- [ ] All 3 behavior scenarios pass
- [ ] `bd preflight` passes
- [ ] No bd-dolt commands present in the new skill (`grep "bd dolt" skills/getting-up-to-speed/SKILL.md` only finds the negative reference inside the Edge Cases table)

## Rollback

`git revert <merge-sha>` restores 19 skills cleanly. The skill is purely additive — no existing files are modified except the 4 docs (README, CHANGELOG, CLAUDE.md, the spec), and those revert losslessly.
