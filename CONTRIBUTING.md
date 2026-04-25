# Contributing to beads-superpowers

Thanks for considering a contribution. This project is a small, focused
Claude Code plugin — issues and PRs are welcome, especially around skill
content, hook portability, and beads integration polish.

## Quick start for contributors

```bash
# 1. Fork on GitHub, then clone your fork
git clone git@github.com:<your-user>/beads-superpowers.git
cd beads-superpowers

# 2. Create a feature branch
git switch -c feat/my-improvement

# 3. Make your changes (see "Making changes" below)

# 4. Lint locally before pushing
npx markdownlint-cli2 "**/*.md"

# 5. Push and open a PR against main
git push -u origin feat/my-improvement
gh pr create
```

## Project conventions

This project uses [`bd` (beads)](https://github.com/gastownhall/beads) for
all task tracking and writes commit messages with conventional-commit
prefixes (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, `build:`).

- **Branches:** Use a descriptive branch name like `feat/<short-name>` or
  `fix/<short-name>`. Default branch is `main`.
- **Commits:** Small, focused commits. Tests, code, and docs land together
  when they belong together.
- **Skills:** Markdown only. No TodoWrite. No softening of bright-line
  rules. See the "Modifying Skills" section in `CLAUDE.md`.

## Making changes

### Adding or modifying a skill

1. Read the existing skill closest to what you want — copy its tone and
   structure
2. Use `bd` commands for task tracking inside the skill
3. Do **not** add TodoWrite references
4. Do **not** remove anti-rationalization tables, Iron Laws, or Red Flags
5. Update `README.md` skill table and `CHANGELOG.md`

### Modifying hooks or scripts

The session-start hook is bash on Unix, batch on Windows (polyglot via
`run-hook.cmd`). Test on both if you can. See `docs/windows/polyglot-hooks.md`.

### Modifying plugin manifests

Three files must stay in sync:

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `package.json`

Use the helper script:

```bash
./scripts/bump-version.sh 0.4.1   # Bump to a new version
./scripts/bump-version.sh --check # Detect drift
```

## Cache sync during development

When you edit skills locally, the installed plugin cache at
`~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.4.1/`
goes stale. Symlink the cache to your dev checkout once and you're done:

```bash
rm -rf ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.4.1
ln -s ~/workplace/beads-superpowers \
  ~/.claude/plugins/cache/beads-superpowers-marketplace/beads-superpowers/0.4.1
```

## Tests

```bash
# Fast tests (skill content verification, ~2 min)
cd tests/claude-code && ./run-skill-tests.sh

# Integration tests (full workflow execution, 10-30 min)
cd tests/claude-code && ./run-skill-tests.sh --integration
```

## Pull request checklist

The PR template auto-populates this — read it before you push:

- [ ] CI passes locally (`npx markdownlint-cli2 "**/*.md"`)
- [ ] No TodoWrite references in skills
- [ ] Anti-rationalization tables, Iron Laws, Red Flags preserved
- [ ] Version bumped in all 3 manifests if metadata changed
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`
- [ ] `README.md` updated if user-facing behaviour changed

## Code of conduct

Be kind. Assume good intent. Disagree about technical things directly and
respectfully. We do not have a separate CODE_OF_CONDUCT document — the
default is "act like a professional engineer."

## Reporting security issues

Please follow the policy in [`SECURITY.md`](SECURITY.md). Do **not** open
public issues for security vulnerabilities.

## License

By contributing, you agree that your contributions will be licensed under
the MIT License (see [`LICENSE`](LICENSE)).
