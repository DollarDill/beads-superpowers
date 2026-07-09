---
name: research-driven-development
description: Use when the user asks a question about a topic, requests research, or when you need to understand something before planning. Dispatches parallel research agents, synthesizes findings into a persistent document, and writes it to the project's research directory. Triggers on "research this", "what is X", "how does Y work", "compare A vs B", "investigate", "deep dive", "look into".
---

# Research-Driven Development

Dispatch parallel research agents, synthesize their findings, and write a persistent research document. Research is not complete until there is a written artifact — verbal answers without documents are prohibited.

**Announce at start:** "I'm using the research-driven-development skill to investigate this topic."

## When to Use

- User asks a question about a technology, concept, or approach
- User says "research this", "deep dive", "investigate", "look into"
- User asks "what is X", "how does Y work", "compare A vs B"
- Before planning a non-trivial task that requires understanding first
- When you need to understand something before making a decision

## When NOT to Use

- User asks about a specific file in the current codebase (just read it)
- The answer is a single fact you already know with certainty
- User explicitly asks for a quick verbal answer

## Iron Law

> **NO RESEARCH WITHOUT A DOCUMENT.**
> Every research task produces a written artifact. Verbal answers without persistent documents are prohibited. If you researched it, write it down.

## Output Path

Research documents are written to **`.internal/research/`** — the project-local, gitignored knowledge base. Not configurable.

## Pipeline

```
Step 0: Scope check (conditional)
Step 1: Create bead + calibrate effort
Step 2: Check existing knowledge
Step 3: Decompose + dispatch parallel research agents
Step 4: Synthesize + verify findings
Step 4.5: Gap-closing round (if needed)
Step 5: Write document
Step 6: Close bead
```

## Step 0: Scope Check (conditional)

If the question is already specific, **skip this step**. Fire it **only when you cannot name the sources you'd search or the decision the answer informs** — e.g. "research databases" (too vague). Do NOT fire when scope is already present — e.g. "compare Postgres vs SQLite for our embedded Dolt use case".

When it fires, ask 2–3 clarifying questions via your structured question tool (scope · use-case · the decision it informs), then weave the answers into the research question before Step 1. This is disambiguation, not a quality gate — mandatory scope-gating just duplicates what a capable model already does. The "When NOT to Use" list still applies.

## Step 1: Create a Bead + Calibrate Effort

```bash
bd create "Research: <topic>" -t task -p 2
bd update <id> --claim
```

**Calibrate effort — the query tier picks the agent count (this is the throttle, not a vibe):**

| Tier | When | Agents | Searches |
|------|------|--------|----------|
| Simple fact-finding | one factual answer | 0–1 (no decomposition) | ~3–10 |
| Comparison / decision | weigh 2+ options | 2–4 sub-questions, one agent each | ~10–15 each |
| Complex / open-ended | broad or architectural | up to 5 sub-questions | as needed |

**Hard ceiling: at most 5 parallel agents per round.** `@explore` (Step 3), when dispatched, counts as one of the 5. Scale effort to the question — do not over-dispatch.

## Step 2: Check Existing Knowledge

Before launching new research, search for existing coverage:

```bash
# Check beads memories for prior context
bd memories <keyword>
# Also search the kv knowledge base (reference-class notes live here, not in memories)
bd kv list | grep -i '^ *bsp.kb' | grep -i <keyword>

# Search project research directory
find .internal/research -name "*.md" -exec grep -l "<keyword>" {} \; 2>/dev/null
```

**If comprehensive coverage already exists:** Reference it, add any new findings as updates, and close the bead. Do not duplicate existing research.

## Step 3: Decompose + Dispatch Parallel Research Agents

**Decompose first** (skip for the Simple tier): break the topic into **3–6 complementary sub-questions** (for opinion/design topics, 2–3 perspectives) that collectively cover it. Assign **one researcher agent per sub-question** — never hand every agent the raw topic. Launch all agents in a **single message with multiple `Agent` tool calls** so they run concurrently. **Cap: 5 parallel agents (Step 1).**

### The delegation contract (every dispatch)

Each agent's brief MUST state all four parts (Anthropic's delegation contract — vague briefs cause duplicated and missed work):

1. **Objective** — the specific sub-question, not the whole topic.
2. **Output format** — structured findings, and a **verbatim supporting quote for every load-bearing claim** (this is what lets Step 4 verify soundness without re-fetching).
3. **Tools / sources** — which to prefer (official docs over blogs).
4. **Boundaries** — what this agent owns vs. its neighbours, so sub-questions don't overlap.

Add to every brief: **start wide, then narrow** — open with a SHORT broad query, see what's available, then narrow. Never lead with a long, hyper-specific query.

### Agent A: Researchers (web + documentation)

Dispatch via the `Agent` tool:

1. `Read` the prompt template at `./researcher-prompt.md`
2. Use its content as the `prompt` parameter, appending the sub-question + the four contract parts above + bead context (bead ID, what decision this informs, prior knowledge from `bd memories`)
3. Use `subagent_type: "general-purpose"` (do NOT use `"researcher"` — that built-in agent's system prompt overrides the template)

### Agent B: @explore (codebase) — one agent, conditional

Dispatch **exactly one** `@explore` agent (`subagent_type: "Explore"`) **only when the topic has codebase relevance** ("how does X work *here*", "should we adopt Y"). It counts as one of the 5 and is **not decomposed** (it's already a broad codebase sweep), but gets the same 4-part contract:

> Objective: find existing implementations, patterns, config, tests, and docs related to [topic] in this repo. Output: what exists, where (`file:line`), and how it relates. Boundaries: codebase only — no web. Report concisely.

### How many agents

- **Topic touches our codebase** (common case): N web sub-question agents + **1 `@explore`**, total ≤ 5.
- **Pure external topic**: skip `@explore`; all slots go to web sub-questions.
- **Pure codebase question**: dispatch only `@explore`.

## Step 4: Synthesize + Verify Findings

After the agents return, you synthesize. The three review touches operate at distinct granularities — claim-level here, coverage-level in Step 4.5, document-level in the Step 5 checklist — and are not redundant.

1. **Merge findings** — combine the sub-question results + codebase findings; merge semantic duplicates.
2. **Verify soundness (the one claim-verification pass)** — for each **load-bearing** claim, check it against the **verbatim quote** the agent returned and confirm the source *actually supports* it (entailment, not topical proximity). Drop or downgrade unsupported claims. Tag each load-bearing claim inline with its source (`[S1]`).
3. **Assign confidence per finding** — **high** (multiple primary sources agree) / **medium** (secondary or split) / **low** (single source / blog / contested), with a one-line rationale.
4. **Resolve contradictions, keep the verdict** — when sources conflict, determine which is authoritative and recommend. When the conflict is load-bearing, also record both positions in an optional **Disagreements** note — but never silently average, and never abdicate the call.
5. **Identify gaps** — list load-bearing claims that rest on a single source or are unresolved (feeds Step 4.5).
6. **Extract actionable items** — note recommended beads.

## Step 4.5: Gap-Closing Round (if needed)

If Step 4 surfaced load-bearing claims resting on a single source or unresolved, **dispatch one narrow follow-up round of 1–2 targeted agents** aimed only at those gaps (not a second full fan-out), then re-synthesize. **Cap: 1–2 rounds total.** Record each: `bd note <id> "reflection round N: chasing <gaps>"`. If no gaps, skip.

## Step 5: Write the Document

List existing category subdirectories and pick the one that best matches the research topic:

```bash
find .internal/research -maxdepth 1 -mindepth 1 -type d 2>/dev/null
```

If a category fits, write inside it; if none fits (or none exist), write to `.internal/research/` directly.

```bash
# Example: research about CI/CD → engineering-and-technology subdirectory
mkdir -p .internal/research/<category>
```

Filename: `YYYY-MM-DD-<topic-slug>.md`

Write the document using the structure in **`./document-template.md`** (read it now).

### Quality Checklist

Before writing, verify your document passes these checks:

- [ ] **Summary exists** and is 2-3 sentences (not a paragraph)
- [ ] **Every finding has evidence** — no unsourced claims
- [ ] **Sources section has 3+ entries** with URLs (not "various sources")
- [ ] **Dates and versions noted** for time-sensitive information
- [ ] **Contradictions resolved** — if sources disagreed, which is right and why
- [ ] **Codebase context included** — what exists now, not just what the web says
- [ ] **Recommendations are actionable** — "do X" not "consider doing X"

**Self-grade before closing** (if any axis fails, run one Step-4.5 round):

- [ ] **Factual accuracy** — claims match their sources
- [ ] **Citation soundness** — each load-bearing claim's source actually supports it (verified against the quote)
- [ ] **Completeness** — every sub-question answered
- [ ] **Source quality** — ≥1 primary/official source for each load-bearing claim
- [ ] **Effort efficiency** — agent count matched the query tier (no over-dispatch)

## Step 6: Close the Bead

**Capture what you learned.** At close, record every durable, evidence-backed insight from this work — anything still true next month, tied to a file, test, or command. Don't skip because it feels minor: if it would save a future session time or stop a repeated mistake, record it. Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update an existing memory in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

```bash
bd close <id> --reason "Research complete: <1-line summary of finding>"
```

If research revealed follow-up work, create the recommended beads — stamp each per **Agent-Filed Bead Discipline** (`beads-superpowers:verification-before-completion`):

```bash
bd create "Follow-up: <title>" -t task -p <priority> --notes "Severity: <Critical|Important|Minor>
Confidence: <Confirmed|Speculative>
Evidence: <file:line / source / repro | none>"
```

## Red Flags / Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "I already know the answer" | You might be wrong. Check sources. The document is for future sessions too. |
| "This is a simple question, I'll just answer verbally" | Iron Law: NO RESEARCH WITHOUT A DOCUMENT. Write it down. |
| "I'll skip the codebase search — this is a general topic" | The codebase might already have an implementation. Always check. |
| "I'll write the document later" | You won't. Write it now while the research is fresh. |
| "One source is enough" | Cross-reference across 3+ independent sources. Single-source findings get flagged. |
| "I'll skip the knowledge base check" | You might duplicate existing research. Always search first. |
| "The first pass answered it" | First passes miss the non-obvious. Run the Step-4 gap check. |
| "The source is about the right topic" | Topical ≠ supporting. Verify the quote actually states the claim. |
| "I'll hand the agents the whole topic" | Decompose. Give each agent one bounded sub-question + the 4-part contract. |
| "This needs 10 agents" | Cap at 5. Scale effort to the query tier. |
| "The cheaper recommendation is fine to default to" | Any recommendation that advises a shortcut, descope, material-risk trade-off, or security regression must be flagged as such — never the default path (Production-Grade Doctrine). |

## Example

User asks: "How does Dolt handle merge conflicts?"

```
1. bd create "Research: Dolt merge conflict handling" -t task -p 2
2. bd memories "dolt merge" → check for prior research
3. Dispatch researcher (via ./researcher-prompt.md): "Research Dolt merge conflict resolution..."
   Dispatch @explore: "Search codebase for Dolt merge, conflict..."
4. Synthesize: researcher found cell-level merge docs, explore found bd dolt pull usage
5. Write to .internal/research/2026-05-01-dolt-merge-conflict-handling.md
6. bd close <id> --reason "Research complete: Dolt uses cell-level merge on SQL tables"
```

## Integration

**Invoked by:** User on-demand, or during the research phase before planning. No other skill invokes this directly.

**Invokes:** None. Dispatches @researcher and @explore agents in parallel internally, but does not invoke other skills.
