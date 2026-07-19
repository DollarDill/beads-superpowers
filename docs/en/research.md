---
sidebar:
  order: 8
description: The evidence behind the design - external literature and this project's own measurements.
---

<!-- Role: the evidence behind the design - external literature and our own measurements. Does NOT belong here: the decisions themselves (philosophy.md) or the mechanism (methodology.md). -->

# Research

This page collects the evidence behind beads-superpowers' design choices: the external literature the project draws on, and the measurements the project ran on itself. It exists for adopters who want to check the sources before trusting a plugin with their development workflow, not just take "it's been tested" on faith. For why each choice was made, see [Philosophy](philosophy.md); for how the resulting mechanism works day to day, see [Methodology](methodology.md).

## What the literature says

### Cialdini, *Influence* (2021)

Robert Cialdini's *Influence: The Psychology of Persuasion* (New and Expanded Edition, Harper Business, 2021) documents a small set of principles that change human compliance: authority, consistency, scarcity, reciprocity, liking, social proof, and unity. Three of them shape how beads-superpowers' skills are written. Authority: Iron Laws use absolute phrasing ("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST") because an instruction that reads as authoritative is harder for an agent to talk itself out of than a suggestion. Consistency: once an agent starts a skill's checklist, the pressure to stay consistent with a process it already began keeps it moving through the remaining steps instead of drifting off. Scarcity: phrasing like "you cannot rationalize your way out of this" removes the sense that an alternative path exists.

### Meincke et al. (2025) - persuasion principles tested on AI compliance

Cialdini's principles were built on human subjects. Meincke, Shapiro, Duckworth, Mollick, Mollick, and Cialdini tested whether they hold for AI models in ["Call Me A Jerk: Persuading AI to Comply with Objectionable Requests"](https://www.pnas.org/doi/10.1073/pnas.2535868123) (PNAS, 2025). Across 28,000 conversations, they asked GPT-4o-mini to do one of two things it would normally refuse (insult the user, or explain how to synthesize a regulated drug), varying the prompt to invoke one of the seven principles above. Average compliance rose from about a third with a plain control prompt to about seventy percent when a principle was invoked (33.3% to 72.0%); authority, commitment, and scarcity produced the largest gains.

The study tested principles like citing a credible source (authority) or a shrinking time window (scarcity), not instruction phrasing directly. The specific claim that firm, absolute phrasing ("MUST", "NEVER") outperforms hedged phrasing ("consider", "when feasible") for the same reason is drawn from upstream superpowers' own [writing-skills research notes](https://github.com/obra/superpowers/blob/main/skills/writing-skills/persuasion-principles.md), which connect that design choice to the same authority principle Meincke et al. measured. beads-superpowers inherited that design choice along with the skills themselves.

### MAST: why multi-agent systems fail (NeurIPS 2025)

[Why Do Multi-Agent LLM Systems Fail?](https://arxiv.org/abs/2503.13657) (Cemri et al., NeurIPS 2025 Datasets and Benchmarks Track) built a failure taxonomy, MAST, from over 1,600 annotated traces across seven multi-agent frameworks. It groups 14 distinct failure modes into three categories:

- **System design issues**: the system was given an ambiguous task or role specification and built on it anyway.
- **Inter-agent misalignment**: a breakdown in the information flowing between agents during execution - a dropped handoff, an ignored update, a conversation reset.
- **Task verification**: no check, an incomplete check, or a check that missed the actual error, before the system called the task done.

Each maps to a mechanism already in beads-superpowers. System design issues are what `brainstorming` and `writing-plans` exist to prevent: a design spec and a bite-sized task plan happen before any agent writes code, so there's no ambiguous specification left for an implementer to run with. Inter-agent misalignment doesn't get a countermeasure so much as a structure that avoids it: only the orchestrating agent holds cross-task state and creates, claims, or closes beads, so subagents never coordinate directly with each other in the first place. Task verification failures are what `verification-before-completion` targets directly: a bead cannot close without evidence that a check actually ran.

### Single-threaded agents in practice

[Cognition](https://cognition.ai/blog/dont-build-multi-agents), the team behind the Devin coding agent, argues against parallel subagent architectures from production experience rather than a benchmark. Their example: split a "build Flappy Bird" task between two subagents, one for the background and one for the bird, and each makes its own unstated decisions about art style with no visibility into the other's work. One agent builds a Super Mario Bros.-style background; the other builds a bird that looks nothing like a game asset and moves nothing like the one in Flappy Bird. Nothing reconciles them. Cognition's prescription is to keep a single continuous thread with full shared context as the default, arguing against parallel subagent architectures in general. beads-superpowers' orchestrator-only rule follows the same shape: subagents run in parallel to implement independent tasks, but only the orchestrator touches beads, and each subagent's output goes back through a file-based handoff rather than a live conversation with its siblings.

## What we measured

The findings above are secondhand: literature, and other teams' production experience. These three are ours, measured on this project's own skills and hook.

**Skill Discovery Optimization.** Early versions of some skills had a YAML `description` field that summarized the workflow, e.g. "code review between tasks." When a skill was written that way, we found the agent read the description and acted on it directly, skipping steps the full `SKILL.md` body specified. Once descriptions were rewritten to state only a trigger condition ("use when task X happens"), the agent went on to read the full skill before acting. Every skill's `description` field states a trigger condition now, never a workflow summary.

**Salience-curated context injection.** The plugin's session-start hook composes a beads context (curated memories plus a `bd prime` pointer) instead of injecting the full `bd prime` dump. Measured against a 218-memory store, the curated version cut injected context by 91.6%. That measurement set the hook's 8 KB ceiling.

**Adversarial pressure-testing of skill rules.** We ran every rule in every skill through a RED/GREEN cycle before shipping: RED is an agent given the pressure scenario without the skill, violating the rule; GREEN is the same scenario with the skill present, and the agent complying. Where GREEN still turned up a loophole, we rewrote the rule and re-tested it rather than leave it to theory. It's TDD's RED-GREEN-REFACTOR loop applied to the skill documents themselves, not just to code.

## From finding to mechanism

| Finding | Design response | Where it lives |
|---|---|---|
| Authority, consistency, and scarcity framing raise agent compliance (Cialdini; Meincke et al. 2025) | Iron Laws use absolute MUST/NEVER phrasing, never a hedged suggestion | Every discipline-enforcing skill, e.g. `test-driven-development`, `systematic-debugging` |
| Consistency pressure keeps an agent on-process once it starts | Multi-step skills run as an ordered checklist, not an optional menu | `brainstorming`, `writing-plans` |
| System design and specification failures are a leading multi-agent failure class (MAST) | Design and planning happen in dedicated skills before any code is written | `brainstorming`, `writing-plans` |
| Inter-agent misalignment is a leading multi-agent failure class (MAST); a single continuous thread avoids it structurally (Cognition) | Only the orchestrator creates, claims, or closes beads; subagents hand off through files, not a live conversation | Orchestrator-only design, `subagent-driven-development` |
| Task verification failures are a leading multi-agent failure class (MAST) | A bead cannot close without evidence a check ran | `verification-before-completion` |
| A workflow-summarizing skill description gets followed instead of the skill body (measured on this project) | Descriptions state a trigger condition only | Every skill's YAML frontmatter |
| The full `bd prime` dump costs far more injected context than a curated one (measured on this project: -91.6% on a 218-memory store) | Session hook composes a salience-curated context under an 8 KB ceiling | `session-start` hook |
| Untested skill rules tend to have loopholes (measured on this project) | RED/GREEN adversarial pressure-testing before a rule ships | Every discipline-enforcing skill |

## Sources

- Cialdini, R. B. (2021). *Influence: The Psychology of Persuasion* (New and Expanded Edition). Harper Business.
- Meincke, L., Shapiro, D., Duckworth, A., Mollick, E., Mollick, L., & Cialdini, R. (2025). ["Call Me A Jerk: Persuading AI to Comply with Objectionable Requests."](https://www.pnas.org/doi/10.1073/pnas.2535868123) *PNAS*.
- Upstream superpowers, [writing-skills persuasion-principles notes](https://github.com/obra/superpowers/blob/main/skills/writing-skills/persuasion-principles.md).
- Cemri, M., Pan, M. Z., Yang, S., et al. (2025). ["Why Do Multi-Agent LLM Systems Fail?"](https://arxiv.org/abs/2503.13657) NeurIPS 2025 Datasets and Benchmarks Track.
- Cognition. (2025). ["Don't Build Multi-Agents."](https://cognition.ai/blog/dont-build-multi-agents)
- [Methodology](methodology.md) - the mechanism these findings feed into.
- [Philosophy](philosophy.md) - the reasoning behind each design choice.
