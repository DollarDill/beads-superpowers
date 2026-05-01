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
- Before planning a non-trivial task (FSM state S2)
- When you need to understand something before making a decision

## When NOT to Use

- User asks about a specific file in the current codebase (just read it)
- The answer is a single fact you already know with certainty
- User explicitly asks for a quick verbal answer

## Iron Law

> **NO RESEARCH WITHOUT A DOCUMENT.**
> Every research task produces a written artifact. Verbal answers without persistent documents are prohibited. If you researched it, write it down.

## Pipeline

```
Step 1: Create bead
Step 2: Check existing knowledge
Step 3: Dispatch parallel research agents
Step 4: Synthesize findings
Step 5: Write document
Step 6: Close bead
```

## Step 1: Create a Bead

```bash
bd create "Research: <topic>" -t task -p 2
bd update <id> --claim
```

## Step 2: Check Existing Knowledge

Before launching new research, search for existing coverage:

```bash
# Check beads memories for prior context
bd memories <keyword>

# Search project research directory
find docs/research/ -name "*.md" -exec grep -l "<keyword>" {} \;

# Search knowledge base if one exists
find ~/workplace/knowledge/ -name "*.md" -exec grep -l "<keyword>" {} \; 2>/dev/null
```

**If comprehensive coverage already exists:** Reference it, add any new findings as updates, and close the bead. Do not duplicate existing research.

## Step 3: Dispatch Parallel Research Agents

Launch BOTH agents in a **single message with multiple Agent tool calls** so they run concurrently:

### Agent A: @researcher (web + documentation)

Dispatch via the `Agent` tool with `subagent_type: "researcher"`:

> Research [topic]. I need:
> 1. Official documentation and primary sources
> 2. Current best practices (note versions and dates)
> 3. Common pitfalls and known issues
> 4. Comparisons with alternatives if relevant
>
> Search at least 3-5 varied queries. Cross-reference across 3+ independent sources. Flag any contradictions. Report in structured format with Sources section.

### Agent B: @explore (codebase)

Dispatch via the `Agent` tool with `subagent_type: "Explore"`:

> Search the codebase for any existing implementations, patterns, or references related to [topic]. Check:
> 1. Existing code that does something similar
> 2. Configuration or dependencies related to this
> 3. Tests that exercise related functionality
> 4. Documentation mentioning this topic
>
> Report: what exists, where it is, and how it relates to [topic].

### If Only One Agent Applies

- **Pure topic research** (no codebase relevance): Dispatch only @researcher
- **Pure codebase question**: Dispatch only @explore
- **Both relevant** (default): Dispatch both in parallel

## Step 4: Synthesize Findings

After both agents return, the **orchestrator** (you) synthesizes:

1. **Merge findings** — Combine web research with codebase findings
2. **Resolve contradictions** — If agents disagree or sources conflict, determine which is authoritative
3. **Identify gaps** — Note anything neither agent covered
4. **Extract actionable items** — If research reveals work to do, note recommended beads

## Step 5: Write the Document

Write the research document to the project's research directory:

```bash
# Create directory if needed
mkdir -p docs/research/

# Write to: docs/research/YYYY-MM-DD-<topic-slug>.md
```

### Document Format

```markdown
# Research: [Topic]

> **Date:** YYYY-MM-DD
> **Bead:** <bead-id>
> **Status:** Complete

## Summary

[2-3 sentence overview of key findings. What did we learn? What's the recommendation?]

## Key Findings

### [Finding 1: Title]

[Details with specific facts, numbers, commands, code examples. Be concrete — no vague claims.]

### [Finding 2: Title]

[Details]

### [Finding 3: Title]

[Details]

## Comparisons

[Table comparing options/approaches if applicable]

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| ... | ... | ... | ... |

## Codebase Context

[What already exists in the codebase related to this topic. File paths, patterns, relevant tests.]

## Recommendations

[Clear, actionable recommendations based on findings. What should we do next?]

## Recommended Beads

[If research reveals follow-up work, list as bd create commands]

- `bd create "Title" -t <type> -p <priority>` — [Why]

## Open Questions

[Anything unresolved or needing further investigation]

## Sources

- [Source Title](URL) — [What was extracted and why it's authoritative]
- [Source Title](URL) — [What was extracted]
```

### Quality Checklist

Before writing, verify your document passes these checks:

- [ ] **Summary exists** and is 2-3 sentences (not a paragraph)
- [ ] **Every finding has evidence** — no unsourced claims
- [ ] **Sources section has 3+ entries** with URLs (not "various sources")
- [ ] **Dates and versions noted** for time-sensitive information
- [ ] **Contradictions resolved** — if sources disagreed, which is right and why
- [ ] **Codebase context included** — what exists now, not just what the web says
- [ ] **Recommendations are actionable** — "do X" not "consider doing X"

## Step 6: Close the Bead

```bash
bd close <id> --reason "Research complete: <1-line summary of finding>"
```

If research revealed follow-up work, create the recommended beads:

```bash
bd create "Follow-up: <title>" -t task -p <priority>
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

## Example

User asks: "How does Dolt handle merge conflicts?"

```
1. bd create "Research: Dolt merge conflict handling" -t task -p 2
2. bd memories "dolt merge" → check for prior research
3. Dispatch @researcher: "Research Dolt merge conflict resolution..."
   Dispatch @explore: "Search codebase for Dolt merge, conflict..."
4. Synthesize: researcher found cell-level merge docs, explore found bd dolt pull usage
5. Write to docs/research/2026-05-01-dolt-merge-conflict-handling.md
6. bd close <id> --reason "Research complete: Dolt uses cell-level merge on SQL tables"
```
