# Contributing

## Setup

```bash
git clone git@github.com:<your-user>/beads-superpowers.git
cd beads-superpowers
git switch -c feat/my-improvement
```

## Conventions

- **Task tracking:** [`bd` (beads)](https://github.com/gastownhall/beads), not TodoWrite or markdown TODOs
- **Commits:** Conventional prefixes (`feat:`, `fix:`, `docs:`, `chore:`), small and focused
- **Branches:** `feat/<name>` or `fix/<name>` off `main`
- **Skills:** Markdown only. Don't soften bright-line rules, don't remove anti-rationalization tables or Iron Laws. See "Modifying Skills" in `CLAUDE.md`.

## Making changes

**Skills:** Read the closest existing skill first — match its tone and structure. Use `bd` commands for task tracking. Include a `bd remember` prompt at the skill's natural completion point (see existing skills for the pattern). Update `CHANGELOG.md` when you're done.

**Hooks and scripts:** The session-start hook is bash on Unix, batch on Windows (polyglot via `run-hook.cmd`). See `.internal/windows/polyglot-hooks.md` for cross-platform details.

**Plugin manifests:** Six files must stay in sync: `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.codex-plugin/marketplace.json`, and `opencode/package.json`. Use `./scripts/bump-version.sh <version>` to update all six, or `--check` to detect drift.

## Tests

```bash
# Skill content verification (~2 min)
cd tests/claude-code && ./run-skill-tests.sh

# Full workflow integration (10-30 min)
cd tests/claude-code && ./run-skill-tests.sh --integration
```

## Before you open a PR

- [ ] Lint passes: `npx markdownlint-cli2 "**/*.md"`
- [ ] No TodoWrite references in skills
- [ ] Anti-rationalization tables, Iron Laws, Red Flags untouched
- [ ] Version bumped in all 6 manifests if metadata changed (`./scripts/bump-version.sh --check`)
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

## Security

Report vulnerabilities via [`SECURITY.md`](SECURITY.md), not public issues.

## License

Contributions are licensed under [MIT](LICENSE).
