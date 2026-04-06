# Comparison, Insights & Customisation Opportunities

> How Superpowers compares to alternatives, key insights for our workflow, and opportunities for tweaks

## Comparison with Alternative Approaches

| Aspect | Superpowers | Typical CLAUDE.md | Traditional CI/CD | Our RPI Workflow |
|--------|-------------|-------------------|-------------------|-----------------|
| Design before code | Mandatory (brainstorming) | Optional | N/A | Mandatory (Research phase) |
| TDD | Iron Law, delete violating code | Suggested | Tests required, order not enforced | Superpowers skill |
| Code review | Two-stage subagent (spec + quality) | Manual | Manual PR review | Superpowers skill |
| Debugging | 4-phase systematic process | Ad hoc | Ad hoc | Superpowers skill |
| Skill testing | TDD with pressure scenarios | N/A | N/A | N/A |
| Branch isolation | Worktree with safety checks | Optional | Feature branches | Worktree via skill |
| Verification | Fresh evidence required | Trust agent | Trust CI | Superpowers skill |
| Issue tracking | TodoWrite (in-session) | N/A | Jira/GitHub Issues | Beads (persistent) |
| Knowledge management | N/A | N/A | Confluence | OpenViking |
| Session persistence | None (session-scoped) | CLAUDE.md persists | N/A | Beads + Dolt |

## Key Insights

### 1. The "Skill as Mandatory Process" Model Works

The most impactful design decision in Superpowers is treating skills as **mandatory process enforcement** rather than optional guidance. The anti-rationalization tables and bright-line rules are what make this work — without them, agents consistently find excuses to skip process.

**Insight for us:** Our CLAUDE.md instructions should adopt this pattern. Instead of "prefer TDD," we should say "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" and include a rationalization counter-table.

### 2. Two-Stage Review Is a Genuine Innovation

Separating spec compliance from code quality review is non-obvious and powerful. Most review processes conflate "does it work?" with "is it clean?" — Superpowers forces these to be answered separately, in order.

**Insight for us:** We could adopt this pattern for our code review skill integration.

### 3. The SessionStart Bootstrap Is Elegant

Loading only `using-superpowers` at session start (not all 14 skills) keeps the token cost low while ensuring the agent knows how to find and use skills on demand. The decision flowchart in `using-superpowers` serves as a routing table.

**Insight for us:** Our SessionStart hook could adopt a similar pattern — load a lightweight router that points to the right skill for the right situation.

### 4. Pressure Testing Reveals Real Failure Modes

The `writing-skills` meta-skill's approach of testing skills through adversarial scenarios (time pressure, sunk cost, authority pressure) produces much more robust skills than theoretical design. Every rule in the system has been tested against known failure modes.

**Insight for us:** When we create new skills or modify existing ones, we should adopt pressure testing.

### 5. CSO (Claude Search Optimisation) Is a Real Concern

The discovery that Claude follows `description` fields as workflow shortcuts (instead of reading full skills) is a subtle but critical finding. This means frontmatter descriptions must be pure trigger conditions, never workflow summaries.

**Insight for us:** Our skill descriptions should answer "when?" not "what?"

## Gaps and Opportunities for Customisation

### Gap 1: No Persistent Issue Tracking

Superpowers uses `TodoWrite` for in-session task tracking. This is session-scoped — when the session ends, the todo list is gone. There's no persistent issue tracking across sessions.

**Our advantage:** We have `beads` (bd) for persistent issue tracking with Dolt remote sync. We can integrate beads into the Superpowers workflow, replacing TodoWrite with bd commands.

### Gap 2: No Knowledge Management

Superpowers has no knowledge retrieval or documentation management system. Skills don't check for existing knowledge before creating documents.

**Our advantage:** We have OpenViking for knowledge management. We can add "check OpenViking first" steps to brainstorming and writing-plans.

### Gap 3: No Plan Update Mid-Execution

When implementation reveals design issues, the only guidance is "stop and ask." There's no structured skill for updating a plan mid-execution.

**Opportunity:** Create a `plan-revision` skill that handles mid-implementation plan changes with proper change tracking.

### Gap 4: verification-before-completion Is Under-Connected

The verification skill is only referenced by `systematic-debugging` but not by `finishing-a-development-branch` or `subagent-driven-development`. Completion verification should arguably be mandatory at those points too.

**Opportunity:** Wire verification-before-completion into the finishing and subagent-driven pipelines.

### Gap 5: No Session Close Protocol

Superpowers has no "land the plane" ritual. There's no guidance for what to do at the end of a session — no push-to-remote, no state handoff, no cleanup.

**Our advantage:** Our "Land the Plane" protocol (bd close → bd dolt push → git push → git status) fills this gap perfectly.

### Gap 6: No LSP-First Code Navigation

Superpowers doesn't prescribe how agents should navigate code. The TDD and debugging skills tell agents what to do but not how to explore the codebase.

**Our advantage:** Our LSP-first navigation rules (hover > Read, findReferences before modifying, documentSymbol before reading large files) complement Superpowers skills.

### Gap 7: No Model Selection Specifics

The model selection guidance in `subagent-driven-development` is qualitative ("cheap", "standard", "most capable"). There's no mapping to actual model names.

**Opportunity:** Map model selection guidance to specific models (e.g., "cheap" = haiku, "standard" = sonnet, "most capable" = opus).

## Superpowers + Our Workflow: Integration Points

| Our Workflow Component | Superpowers Component | Integration |
|----------------------|----------------------|-------------|
| **Beads (bd)** | TodoWrite | Replace TodoWrite with bd commands |
| **OpenViking** | N/A (no knowledge mgmt) | Add knowledge search to brainstorming, writing-plans |
| **LSP-first navigation** | N/A (no code nav guidance) | Add LSP instructions to implementer prompts |
| **RPI phases** | Brainstorming → Plans → Implementation | Direct alignment — RPI maps cleanly to the skill chain |
| **Land the Plane** | N/A (no session close) | Add as finishing-a-development-branch companion |
| **Dolt remote sync** | N/A (session-scoped) | Add bd dolt push to session close |
| **Code review skill** | requesting-code-review | Augment with our specific review criteria |

## What to Adopt vs What to Customise

### Adopt As-Is (These Are Already Excellent)

- **test-driven-development** — The Iron Law, RED-GREEN-REFACTOR cycle, and anti-rationalization table are production-ready
- **systematic-debugging** — The 4-phase process with escalation path is comprehensive
- **verification-before-completion** — The gate function is clear and effective
- **receiving-code-review** — The anti-sycophancy rules are important

### Customise (Good Foundation, Needs Tweaking)

- **brainstorming** — Good flow but needs OpenViking integration and our spec location preferences
- **writing-plans** — Good granularity rules but needs our plan output format (phases, beads, acceptance criteria)
- **subagent-driven-development** — Excellent two-stage review but needs bd integration, model name mapping, LSP instructions
- **finishing-a-development-branch** — Good 4-option decision tree but needs our "Land the Plane" ritual

### Replace (Our Approach Is Better)

- **TodoWrite usage** → **Beads (bd)** — Persistent, cross-session, with Dolt sync
- **No knowledge management** → **OpenViking** — Semantic search, tiered loading, dedup

### Add (Skills That Don't Exist Yet)

- **Plan revision** — Handling mid-execution design changes
- **Session close** — "Land the Plane" ritual as a skill
- **Research phase** — Structured research before brainstorming (our Phase 1)

## Summary: The Superpowers Playbook

If you could distill Superpowers into a set of principles:

1. **Skills are mandatory, not optional** — Anti-opt-out design with bright-line rules
2. **Test everything, even the process** — TDD for code, TDD for skills, TDD for debugging
3. **Anticipate failure modes** — Pre-load counter-arguments for every known rationalization
4. **Separate concerns in review** — Spec compliance before code quality, always
5. **Explicit terminal states** — Every skill says exactly what happens next
6. **Hard gates before human-critical decisions** — No auto-proceeding past design approval, plan review, or test verification
7. **Context isolation for subagents** — Full text, not file references; explicit status codes
8. **Escalation paths prevent infinite loops** — Count failures, stop at 3, escalate to architecture
9. **Zero dependencies, platform agnostic** — Pure Markdown, works everywhere
10. **Empirically derived, not theoretically designed** — Every rule tested through adversarial pressure

---

## Sources

All analysis sourced from the obra/superpowers repository at:
- Repository: https://github.com/obra/superpowers
- Version analysed: 5.0.7
- Clone location: /tmp/superpowers-analysis/

Key source files:
- `skills/using-superpowers/SKILL.md` — Bootstrap and mandatory invocation
- `skills/brainstorming/SKILL.md` — Design-before-code workflow
- `skills/writing-plans/SKILL.md` — Plan structure and task granularity
- `skills/subagent-driven-development/SKILL.md` — Two-stage review orchestration
- `skills/test-driven-development/SKILL.md` — Iron Law of TDD
- `skills/systematic-debugging/SKILL.md` — 4-phase debugging methodology
- `skills/verification-before-completion/SKILL.md` — Evidence-before-claims
- `skills/writing-skills/SKILL.md` — Meta-skill with CSO and pressure testing
- `skills/writing-skills/persuasion-principles.md` — Research citations (Cialdini 2021, Meincke et al. 2025)
- `skills/writing-skills/testing-skills-with-subagents.md` — Adversarial testing methodology
- `hooks/session-start` — Bootstrap injection mechanism
- `.claude-plugin/plugin.json` — Plugin manifest
- `README.md` — Installation and workflow overview
- `CLAUDE.md` — Contributor guidelines and PR acceptance criteria
