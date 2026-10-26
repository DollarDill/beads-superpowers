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
