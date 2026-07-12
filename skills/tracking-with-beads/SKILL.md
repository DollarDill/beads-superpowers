---
name: tracking-with-beads
description: The beads (bd) conventions of record — frugality, consent boundaries, capture quality, and close-out policy. Use when another skill defers to bd conventions, or when deciding how work should be tracked ("how should this be tracked", "what's the bd convention for X", "which bead type/priority"). Not for routine bd operations — creating, closing, or querying beads needs no skill read.
---

# Tracking with Beads

House policy for the `bd` issue tracker. Commands themselves are not documented here — the binary is the single source of truth: `bd human` (essential commands), `bd --help` (all), `bd prime --export` (full workflow context).

**When NOT to use:** routine create/close/query operations — just run `bd`. This skill is the policy reference, not a wrapper.

## Frugal bd

Bounded reads only; never bare `bd memories`.

- Cap reads: `bd ready -n 10` · `bd show --short <id>` to skim (full `bd show` only when the body is needed) · `bd memories <keyword>` · `bd kv list | grep '^ *bsp.kb'` for the reference knowledge base (note the leading-space indent).
- Batch writes: several creates/updates/closes = one `bd batch` or `bd create --graph` call (`--dry-run` first), not a loop. Keep write confirmations — they are evidence.
- The binary is SSOT for syntax: on first use of an unverified bd command or flag this session, read `bd <cmd> --help` before running it — never assert syntax from memory.
- Filter big outputs before they hit context: `... | grep -E "PATTERN" | head -20`.

## Consent boundary

Claiming is consent-gated: `bd ready --claim` only in autonomous take-next-task flows, never where the user picks the work.

Orientation, brainstorming, and session close always end with the user choosing — efficiency never erodes a consent gate. Skills whose own steps claim work carry this line inline; it binds even when this skill is not loaded.

## Bead discipline

- One bead per unit of claimable, verifiable, closeable work; epics parent tasks (`--parent`).
- Bead IDs go in commit messages: `git commit -m "feat: thing (bd-a1b2)"`.
- Agent-filed beads are stamped per the `verification-before-completion` skill's Agent-Filed Bead Discipline.
- Evidence before close: `bd close <id> --reason` states what was verified, not what was intended.
- Only the orchestrating agent manages beads — subagents do NOT touch beads.

## Capture quality

`bd remember` stores only durable, evidence-backed insights — still true next month, tied to a file, test, or command. Never guesses, one-offs, or secrets (memories are injected into future sessions). Update in place (`--key`) over near-duplicates. Reference-class notes (research/design/decision pointers) belong in the `bsp.kb.` knowledge base, not injected memories — routing and sweeps are the `memory-curator` skill's job.

## Land the plane

Sessions close by landing, not stopping: close what finished, sync, push. The 3-step sequence lives inline in the `finishing-a-development-branch` skill (it performs the operation); this is the policy behind it — work is not done until the push succeeds, because beads state that only exists on one machine is state the team does not have. If `bd dolt push` fails (diverged history, push-protection), recover via the `project-init` skill rather than skipping the sync.
