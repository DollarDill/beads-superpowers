# Session Handoff — <YYYY-MM-DD> — <topic>

> **Read this FIRST on resume**, then run `bd prime`. This file + the continuation
> memory give full orientation. Gitignored (`.internal/`), local-only.

## Current State (TL;DR)
- Repo / branch @ <sha>, sync status, working tree, version, backlog counts.

## Work In Progress
> *Primary content for a mid-work handoff. Empty if the session ended cleanly.*
- Current task + bead: <id>
- Uncommitted changes: <git diff --stat summary>
- **Exact next action:** <one concrete step>
- Dead-ends already ruled out: <so the next session doesn't repeat them>

## What Shipped This Session
- <commit sha> — <subject> (<bead id>). Reference by path; don't paste diffs.

## Architectural Decisions
- <ADR path> — <one-line rationale>.

## Key File Paths
| Artifact | Path |
|---|---|
| Spec | <path> |
| Plan | <path> |
| This handoff | <path> |

## Loose Threads
- Uncommitted/unpushed, in-flight, deferred, separate-repo notes.

## How to Resume
1. `bd prime` (auto on session start). 2. Read this file. 3. `bd ready`. 4. <next>.

## Suggested Skills
- <skill the next session should invoke and why>.

## Continuation Memory
- `continuation-<date>-<topic>` — one-line pointer (written via `bd remember`).
