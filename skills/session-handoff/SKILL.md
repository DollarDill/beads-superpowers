---
name: session-handoff
description: A human-invoked utility that writes a grounded session-handoff document (plus a continuation pointer memory) so a fresh agent can resume in-progress work. Not auto-invoked; a human runs it deliberately.
disable-model-invocation: true
---

# Session Handoff

Write a grounded handoff document — and a one-line continuation memory — so a fresh
session can resume exactly where this one left off.

**Announce at start:** "I'm using the session-handoff skill to write a session handoff."

> **Human-invoked only.** This skill is fired by a human (slash command or explicit
> ask) — before `/clear`, `/compact`, a context limit, or a teammate handoff. It is
> intentionally absent from every agent-trigger surface and is never auto-invoked.

## When a human uses this

- Before `/clear` or `/compact`, mid-task, when context is about to be lost.
- End of a working session, to seed the next one.
- Handing work to a teammate or another agent.

Optional argument: a short description of what the next session will focus on — used to
tailor Work In Progress / Loose Threads / Suggested Skills.

## Pipeline

1. **Gather (read-only, run the commands — do not recall):**
   `git status -sb`, `git log --oneline -15`, `git diff --stat`, branch + ahead/behind;
   `bd ready`, `bd blocked`, `bd count --by-status`, in-progress beads; list the
   spec, plan, and architecture-decision-record files touched this session.
2. **Synthesize** into the bundled template (`handoff-template.md`). **Reference
   artifacts by path — never paste their bodies** (commits, ADRs, specs, plans, diffs).
   Duplicating bloats the doc and goes stale.
3. **Write the doc** — Default: `.internal/handoff/YYYY-MM-DD[-HHMMSS]-<topic>-handoff.md`
   (`-HHMMSS` only if a same-day handoff exists). If the human names another location,
   write there. `mkdir -p` the target first.
4. **Write the continuation memory** —
   `bd remember "continuation-<date>-<topic>: <one-line pointer to doc path + headline state>"`
   (episodic continuation record; one-line pointer only).
5. **Verification (externally anchored — output the result block):**
   - Cross-check each state line against the **captured Phase-1 command output**.
   - **Gitignore safety:** `git check-ignore <output-path>`; if NOT ignored, warn the
     human ("⚠️ <dir> is not gitignored; a handoff can contain sensitive session
     state") and offer to add it to `.gitignore` **before** writing.
   - `ls <path>` confirms the doc exists; `bd memories <key>` confirms the memory.
   - **Secret-scan grep** over the doc (`sk-`, `ghp_`, `AKIA`, `-----BEGIN`,
     `password=`) — a backstop, not a guarantee.
   - The narrative synthesis is the author's recollection — not externally verified;
     that is why it references artifacts by path.

   Output a confirmation block: doc path · memory key · gitignore-safety result ·
   secret-scan result.

## Doctrine

- **Redact secrets** (keys, tokens, passwords, PII) — the doc lands on disk and may be
  shared. This is a hard rule; never weaken it.
- **Reference, don't duplicate** — point at commits/ADRs/specs by path.
- **Ground every fact** — run the gather commands; never invent state. If a command
  fails (not a git repo, `bd` absent), degrade gracefully and note the gap.

## Red Flags (low-independence backstop — not the primary guard)

| Rationalization | Reality |
|---|---|
| "I'll write it from memory" | Run the gather commands — recollection drifts. |
| "I'll paste the whole diff" | Reference by path; pasted output bloats and leaks. |
| "I'll add it to the skill index so the agent finds it" | Forbidden — human-invoked only. |
| "The output dir is probably gitignored" | Run `git check-ignore` — secrets to a tracked path is a leak. |

## Integration

**Standalone — human-invoked.** This skill is intentionally NOT referenced by any other
skill or hook, and does not appear in any agent routing or trigger surface. Its read-side
counterpart is `getting-up-to-speed`, which it does not call and is not called by.
