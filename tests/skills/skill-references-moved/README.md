# skill-references-moved registry

One `<skill>.txt` per skill checked by `tests/skills/test-skill-references.sh`
(`subagent-driven-development`, `executing-plans`, `write-documentation`).

Format: one `references/` filename per line (e.g. `batching.md`); `#` comments
and blank lines are ignored. A listed file is held to the stricter checks C5-C8
(pointer line with a gist, `Read this when ` header, `Contents:` past 100 lines,
no same-skill chaining); a listed file that is missing fails.

Writers: Task 2 fills `subagent-driven-development.txt`, Task 3
`executing-plans.txt`, Task 4 `write-documentation.txt` - each only its own file,
in the same commit that creates the references files.

Completeness (C9): every well-formed file in a skill's `references/` dir must be
listed in its `<skill>.txt`, so the stricter checks apply to it. Grandfathered
(existing, unregistered by design; named in `grandfathered()` in the test):
`subagent-driven-development`: `breaker-trip.md`, `dispatch-efficiency.md`,
`rulings-and-escalation.md`; `write-documentation`: `long-form-diagnostics.md`.
Any other unregistered file fails `FAIL C9:`. A missing `<skill>.txt` also fails
C9, as does checking zero skills while a registry lists a file.

Pointer line: `**Read `references/<f>.md` (in this skill's directory) before <step>** - <gist>.`
The gist starts with a non-space character, has at least 9 more, and ends in `.`.
A moved file starts `# Title`, a blank line, then `Read this when ...` (it may wrap;
`Contents: ` for files over 100 lines goes after that paragraph).
