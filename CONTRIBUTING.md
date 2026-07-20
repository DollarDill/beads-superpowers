# Contributing

**PRs target the `dev` branch, not `main`.** `main` is the released branch; all work lands on `dev` first and reaches `main` at release cut. PRs opened against `main` will be asked to retarget.

## Setup

```bash
git clone git@github.com:<your-user>/beads-superpowers.git
cd beads-superpowers
git switch dev
git switch -c feat/my-improvement
```

## Conventions

- **Branches:** `feat/<name>` or `fix/<name>` off `dev`
- **Commits:** Conventional prefixes (`feat:`, `fix:`, `docs:`, `chore:`), small and focused
- **Task tracking (maintainer-side):** this repo runs on [`bd` (beads)](https://github.com/gastownhall/beads). The beads database is private — **you don't need `bd` to contribute.** External PRs are judged on code and tests; bead IDs in commit messages are maintainer discipline, not a requirement for you.
- **Skills:** Markdown only. Don't soften bright-line rules, don't remove anti-rationalization tables or Iron Laws. See "Modifying Skills" in `CLAUDE.md`.
- **Translations:** When you edit an English docs page or `README.md`, update its `.zh.md` / `README.zh-CN.md` sibling, or say so in the PR — untranslated/stale pages fall back to English silently.

## Making changes

**Skills:** Read the closest existing skill first and match its tone and structure. Use `bd` commands in skill content for task tracking (never TodoWrite). Update `CHANGELOG.md` when you're done.

**Hooks and scripts:** The session-start hook is bash on Unix, batch on Windows (polyglot via `run-hook.cmd`).

**Plugin manifests:** Version lives in several manifests that must stay in sync — always use `./scripts/bump-version.sh <version>` (or `--check` to detect drift); never hand-edit version fields.

## Tests

Run `just check` before opening a PR that touches harness plumbing (hooks/, install.sh, manifests, .opencode/). Guards SKIP visibly when an optional tool (shellcheck, node, docker) isn't installed — that's fine.

```bash
just check      # deterministic set: guards + hooks + manifests + contracts + install-shape
just lint       # shellcheck gate over tracked .sh
just selftest   # guard-the-guards: mutations that must fail
just docker     # installer E2E (requires docker or podman, slow)
```

## Before you open a PR

- [ ] Targets `dev`
- [ ] Lint passes: `npx markdownlint-cli2 "**/*.md"`
- [ ] Guards pass: `just guards`
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] EN/ZH siblings in sync (or drift noted in the PR)

## Questions

Open a thread in [Discussions](https://github.com/DollarDill/beads-superpowers/discussions) or email <dillon@algocents.com>.

## Security

Report vulnerabilities via [`SECURITY.md`](SECURITY.md), not public issues.

## License

Contributions are licensed under [MIT](LICENSE).
