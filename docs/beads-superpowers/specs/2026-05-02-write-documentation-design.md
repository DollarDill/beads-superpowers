# Design: write-documentation Skill

**Date:** 2026-05-02
**Status:** Approved
**Bead:** bd-zky (brainstorming), bd-yk7 (epic)
**Source:** Adapted from [Anbeeld/WRITING.md](https://github.com/Anbeeld/WRITING.md) v1.3.1 (MIT)

## Overview

A new beads-superpowers skill that makes Claude write human-quality prose for all human-facing text: documentation, README, guides, blog posts, emails, Slack messages, PR descriptions, release notes, and any other text a human will read.

The skill adapts the 14-rule WRITING.md system with a context-first drafting workflow: identify context, draft with rules internalized, run required checks as a revision pass, cut, and present.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scope | All human-facing prose | Medium routing already adapts rules per context; no need to artificially restrict |
| Relationship to document-release | Independent, complementary | document-release handles when/what to sync; write-documentation handles how to write well |
| Skill file structure | Full ruleset inline in SKILL.md | Heavier on context but no risk of agent skipping reference files |
| Workflow approach | Context-first drafting | Matches how good writers work; checks catch problems without constraining the draft |
| Skill name | write-documentation | Action-oriented verb-noun; matches existing pattern (test-driven-development, requesting-code-review) |

## Skill Identity

```yaml
---
name: write-documentation
description: "Use when writing or substantially rewriting human-facing prose: documentation, README, guides, blog posts, emails, Slack messages, PR descriptions, release notes, or any text a human will read. Not for code comments, commit messages, or agent-to-agent communication."
---
```

### Trigger Conditions

- User says "write a README", "draft documentation", "write a blog post", "help me write this email"
- User asks to create or substantially rewrite any `.md` file that humans read
- User asks for help with prose quality, tone, or style
- Another skill (like document-release) identifies a section needing a major rewrite

### Explicitly NOT Triggered By

- Code comments, docstrings (for developers reading code)
- Commit messages (their own conventions)
- Agent prompts, skill files, CLAUDE.md (for AI agents)
- Minor doc edits like fixing a typo or updating a version number

### Announcement

"I'm using the write-documentation skill to write human-quality prose."

## Core Workflow

```
Step 1: Context Identification
  - What is this text? (medium: README, email, blog post, Slack, guide...)
  - Who reads it? (developers, end users, managers, public...)
  - What do they need? (answer, next action, understanding, decision...)
  - What register? (formal tech docs, casual chat, professional email...)

Step 2: Structure Decision
  - Task-oriented: answer/action first
  - Long-form: decide through-line and one concrete example
  - Apply medium routing rules

Step 3: Draft
  - Write to fit the identified context
  - Rules are internalized, not mechanically applied
  - Focus on substance over style

Step 4: Required Checks (revision pass)
  - Short pieces (~150 words): checks 1-3, 5, 7, 10
  - Longer pieces: all checks 1-10
  - Fix issues inline during this pass

Step 5: Cut
  - Remove what sounds generic, ceremonial, over-engineered
  - Collapse restatements
  - Replace the most generic clause with something specific or delete it

Step 6: Present to user
  - Show the final text
  - If user requests changes, loop back to Step 3
  - Close bead with evidence of checks run
```

### Beads Integration

```bash
# At skill start
bd create "Write: <description of what's being written>" -t task

# At completion
bd close <id> --reason "Written: <what>, checks run: <which checks passed>"
```

## Precedence Chain

When rules conflict:
1. Truth, safety, accessibility, and platform/legal requirements
2. Explicit user instructions
3. Genre and medium norms
4. Core rules
5. Optional watchlists and heuristics

## Medium Routing

| Medium | Default Format | Key Guidance |
|--------|---------------|-------------|
| Chat, Slack, DMs, forums | Running prose | No decorative formatting, no canned tone. Straight ASCII quotes. Prefer commas/colons/connectors over em dashes. |
| Email | Prose first | Lists for discrete items, decisions, action points |
| README, CONTRIBUTING, guides, API docs | Structure expected | Headings, bullets, sequences. Preserve scannability and accessibility. |
| Web pages, help centers, UI text | Answer early | Descriptive headings, lists for steps, descriptive link text |
| Blog posts, articles, retrospectives | Structure on purpose | Pick an angle, not a timeline. Don't let dates or milestones become the spine. |
| PR descriptions, release notes | Hybrid | Lead with what changed and why. Structure for scanning. Concrete over ceremonial. |

## The 14 Core Rules

1. **Anchor to context before drafting** - Decide what the text is, who it is for, what register it uses, what answer or next action the reader needs
2. **Fit format to medium** - Over-structuring casual writing makes it templated. Under-structuring technical writing makes it unusable.
3. **Concrete specificity over polished generality** - Every substantial paragraph needs a concrete anchor (proper noun, specific number, checkable detail)
4. **Specificity must be earned** - No invented milestones, synthetic quotes, hidden-mechanism claims, vague authority laundering
5. **Plain words, ordinary repetition, prefer verbs** - `we changed it` not `the implementation of the change`
6. **Cohere through reference and sentence shape** - Pronouns, coordination/subordination for related thoughts; no false crispness
7. **Do not perform** - No keynote cadence, service-desk tone, ceremonial wrap-ups
8. **Calibrate confidence/stance to genre** - Visible writer where expected, neutral where expected
9. **Show concrete before generalizing** - What happened, where pattern appeared, what mattered, what changed, what it means
10. **Watch regularity** - Break repeated sentence structures, paragraph arcs, punctuation moves
11. **Let thought develop** - Longer pieces should not feel pre-solved
12. **Choose structure consciously** - Default shapes fine when they fit; avoid reflex chronology
13. **No catalog or system-tour prose** - Cross-wire paragraphs, don't give one per milestone
14. **Revise by reading and cutting** - Most edits should shorten; don't confuse concision with chopping

## Safety Rails

- Do NOT invent typos or break grammar to sound human
- Do NOT inject fake uncertainty or staged messiness
- Do NOT remove needed headings, lists, citations, or next steps
- Do NOT program sentence-length wobble
- Em dashes, semicolons, `however`, and competent punctuation are NOT AI tells by themselves

## Required Checks

Short pieces (~150 words): checks 1-3, 5, 7, 10. Longer pieces: all 10.

1. **Register fit** - Format, punctuation, structure match medium and user request? Accessibility preserved?
2. **Concrete-anchor audit** - One concrete anchor per substantial paragraph
3. **Fact discipline** - Three most fragile claims verified. Cannot vouch? Attribute, soften, or cut.
4. **Source-fit check** - Every quote, paraphrase, metric: does the source support the exact claim?
5. **Regularity and continuity tripwire** - Name the most repeated pattern. 3+ occurrences? Rewrite one. Scan for false crispness.
6. **Repeated-frame check** - Central metaphor: useful motif or too-neat scaffold?
7. **Stance and voice** - Genre expects a writer? State the view. Genre expects neutrality? Keep it.
8. **Developed thought** - One place where prose pauses, doubles back, or notices a detail
9. **Shape and spine** - Organizing principle in 5 words. Genre default? Restructure.
10. **Over-correction** - Added fake-human moves to break a pattern?

Checks are tripwires, not goals. Do NOT output the audit unless asked.

## Jargon Watchlist (Not Bans)

Scrutinize when defaulting to: `delve`, `tapestry`, `leverage`, `realm`, `robust`, `seamless`, `holistic`, `underscore`, `ever-changing`, `ever-evolving`, `ever-growing`, `it's important to note`, `when it comes to`, `in conclusion`, `is a testament to`, `serves as`/`stands as` when `is` would work, `plays a key/pivotal role`, `reflects broader` without evidence, `experts say` unnamed.

## Formula Phrases to Scrutinize

- `It's not X, it's Y` / `Not because X, but because Y`
- `What matters is...` / `The real issue is...`
- `This is not just..., it is...`
- Paragraph-closing type definitions (`the kind of X where Y`)
- Three-part cadence by reflex (`clearer, faster, cheaper`)
- One-thought-per-sentence strings where adjacent claims should be coordinated
- `Great question` / `I hope this helps` / `Feel free to reach out`

## Anti-Rationalization Table

| Thought | Reality |
|---------|---------|
| "The rules will make my writing worse" | The rules target LLM defaults. If you're writing well already, they won't change much. |
| "I'll skip the checks -- the draft is good enough" | The checks catch regularity and genericity you can't see while drafting. Run them. |
| "Technical docs don't need prose quality" | Technical docs are the most-read prose in most orgs. Bad docs cost more than bad blog posts. |
| "I'll just run the watchlist as a find-and-replace" | The watchlist targets repeated fallback, not individual words. `robust` is fine once; `robust` in every paragraph is the problem. |
| "Sounding human means adding typos and slang" | Sounding human means fitting the context. Fake humanity is worse than default LLM prose. |
| "I'll strip all structure to avoid looking AI-generated" | Removing needed headings and lists from technical writing is not a style improvement. |

## Integration

**Pairs with:**
- `document-release` - fires post-ship to sync docs; write-documentation fires when writing/rewriting prose
- `verification-before-completion` - prose checks are part of completion evidence
- `brainstorming` - design docs written during brainstorming benefit from these rules

**Called by:**
- Any workflow where the agent is producing human-facing text
- User requests to write, draft, or rewrite documentation

## Attribution

> Adapted from [Anbeeld/WRITING.md](https://github.com/Anbeeld/WRITING.md) v1.3.1, MIT licensed.
