# Audit Watchlist

Read this when you scan a draft for formula phrases, jargon defaults, plain-text formatting artifacts, or compound-modifier hyphenation.

These are not bans. They are quick places to scan when default LLM writing slips into formula.

### Formula phrases and sentence moves to scrutinize

- `It's important to note that` / `It's worth noting that`
- `When it comes to` / `In conclusion`
- `in today's fast-paced world` / `ever-evolving landscape`
- `dive deep into` / `embark on a journey`
- `navigate` used as a vague metaphor
- `It's not X, it's Y` / `Not because X, but because Y`
- `What matters is...` / `The real issue is...`
- `This is not just..., it is...`
- `is a testament to`
- `serves as` / `stands as` when `is` or `has` would be clearer
- `plays a key role` / `plays a pivotal role`
- `reflects broader`, `symbolizes`, `showcases`, `highlights`, or `underscores` when attached to generic significance rather than evidence
- vague source laundering: `experts say`, `observers note`, `research suggests`, `critics argue`, `many believe`
- unsupported causality: `drove`, `proved`, `showed that`, `made clear that`, `tracked with`, `led directly to`
- paragraph-closing type definitions (`the kind of X where Y`)
- persuasive three-part cadence or triadic rhythm used by reflex (`clearer, faster, cheaper`)
- one-thought-per-sentence strings where adjacent claims should be coordinated or subordinated
- decorative emoji and checkmark bullets in prose contexts
- internal tracker IDs in reader-facing prose (`ADR-NNNN`, `bd-xxxx`) — these belong in commits and `docs/decisions/`, not human docs; describe the change, not its ID
- generic-to-the-platform replies that reference nothing specific to the actual conversation
- `Great question` / `Absolutely` / `I hope this helps` / `Feel free to reach out`

### Jargon defaults to scrutinize

Use only when they are plainly the right words, not because the model fell into them:
`delve into`, `tapestry`, `realm`, `leverage`, `harness`, `foster`, `empower`, `unlock`, `unveil`, `vibrant`, `crucial`, `pivotal`, `compelling`, `robust`, `seamless`, `holistic`, `multifaceted`, `paradigm-shifting`, `underscore`, `testament`, `valuable insights`, `rich`, `profound`, `enhance`, `showcase`, `boast` / `boasts`, `ever-changing`, `ever-evolving`, `ever-growing`

The problem is repeated fallback diction, not the existence of any one word.

### Formatting artifacts in plain text to scrutinize

- smart quotes and curly apostrophes
- single-character ellipses
- other visible copy-paste formatting artifacts that do not fit the medium

### Compound-modifier hyphenation to scrutinize

For temporary compounds, hyphenate before the noun: `a well-known author`, `a high-quality service`, `a long-term plan`. After the noun, usually open the compound: `The author is well known`, `The service is high quality`, `The plan is long term`.

Watch for:
- predicative over-hyphenation: `is well-known`, `seems high-quality`
- `-ly` adverb compounds: `highly-qualified`, `newly-designed`
- reflexive `ever-` compounds: `ever-changing`, `ever-evolving`
- set phrases where the hyphen adds nothing: `high school`, `ice cream`

Do not strip all hyphens. Keep them when they prevent ambiguity, when the compound precedes the noun, or when the term is conventionally hyphenated. The problem is the reflex, not the mark.
