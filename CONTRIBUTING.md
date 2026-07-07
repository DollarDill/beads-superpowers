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
- **Translations:** When you edit an English docs page or `README.md`, update its `.zh.md` / `README.zh-CN.md` sibling, or note the drift on the zh review bead. Untranslated/stale pages fall back to English silently.

## Making changes

**Skills:** Read the closest existing skill first and match its tone and structure. Use `bd` commands for task tracking. Include a `bd remember` prompt at the skill's natural completion point (see existing skills for the pattern). Update `CHANGELOG.md` when you're done.

**Hooks and scripts:** The session-start hook is bash on Unix, batch on Windows (polyglot via `run-hook.cmd`). See `.internal/windows/polyglot-hooks.md` for cross-platform details.

**Plugin manifests:** Eight files must stay in sync: `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.codex-plugin/marketplace.json`, `opencode/package.json`, `.cursor-plugin/plugin.json`, and `.kimi-plugin/plugin.json`. Use `./scripts/bump-version.sh <version>` to update all eight, or use `--check` to detect drift.

## Tests

Run `just check` before submitting changes that touch harness plumbing (hooks/, install.sh, manifests, opencode/). See CLAUDE.md § Build & Test.

```bash
just check      # deterministic set: guards + hooks + manifests + contracts + install-shape
just lint       # shellcheck gate over tracked .sh (baseline'd; skips visibly if shellcheck absent)
just selftest   # guard-the-guards: mutations that must fail
just docker     # installer E2E (requires Docker, slow)
```

The LLM-driven suites under `tests/` are deprecated in place — skill behavior testing moved to the external eval-harness project. See `tests/*/DEPRECATED.md`.

## Before you open a PR

- [ ] Lint passes: `npx markdownlint-cli2 "**/*.md"`
- [ ] No TodoWrite references in skills
- [ ] No hardcoded skill counts: `./scripts/check-skill-count.sh` passes
- [ ] Anti-rationalization tables, Iron Laws, Red Flags untouched
- [ ] Version bumped in all 8 manifests if metadata changed (`./scripts/bump-version.sh --check`)
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] Full audit run (maintainers): `.claude/skills/auditing-upstream-drift/SKILL.md`

## Security

Report vulnerabilities via [`SECURITY.md`](SECURITY.md), not public issues.

## License

Contributions are licensed under [MIT](LICENSE).
