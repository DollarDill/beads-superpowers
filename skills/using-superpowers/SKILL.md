---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, track it with beads (see Beads below) — TodoWrite is forbidden.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills carry it out. Brainstorming and systematic-debugging are the most common process skills, but the rule holds for any of them.

- "Let's build X" → beads-superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → beads-superpowers:systematic-debugging first, then domain skills.

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## Production-Grade Doctrine

Treat every project as a production system with real users, no matter how small it looks. You MUST NOT silently take a shortcut, descope a required behavior/edge-case, or accept a material-risk trade-off — surface it and let your human partner decide. You MUST NOT weaken, bypass, or remove a security control or introduce a vulnerability; a security regression is never acceptable, even for a deadline.

## Capturing Decisions

When a decision is hard to reverse, surprising without context, and a genuine trade-off, you MUST offer to record an ADR in `decisions/` (the user confirms; never auto-create). Bias toward offering rather than skipping. Routine clarifications and scope questions don't qualify.

## Beads

`bd` (beads) is the task tracker for ALL work — TodoWrite is forbidden, as are TaskCreate and markdown TODOs. `bd prime` injects the live workflow context and command reference at session start; rerun it after compaction if beads context is missing. Only the orchestrating agent manages beads — subagents never touch them. Include bead IDs in commit messages. Session close = land the plane: `bd close` → `bd dolt push` → `git push`.

## Platform Adaptation

If your harness appears here, read its reference file for special instructions:

- Codex: `references/codex-tools.md`
- OpenCode: `references/opencode-tools.md`
- Copilot CLI: `references/copilot-tools.md`
- Pi: `references/pi-tools.md`
- Antigravity: `references/antigravity-tools.md`

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, etc, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
