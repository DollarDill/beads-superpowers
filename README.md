<p align="center">
  <img src="assets/banner.svg" alt="beads-superpowers — Process discipline and persistent memory for AI coding agents" width="100%" />
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href=".claude-plugin/plugin.json"><img alt="Plugin version" src="https://img.shields.io/badge/plugin-v0.5.3-4f46e5.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml"><img alt="Release" src="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/DollarDill/beads-superpowers?style=social"></a>
</p>

---

A plugin for Claude Code, Codex, and OpenCode that makes your AI coding agent write tests before code, debug systematically instead of guessing, and remember what it worked on yesterday. 22 skills enforce the practices; a Dolt-backed issue tracker keeps context across sessions.

## Install

### curl (recommended — works with all supported CLIs)

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

The installer auto-detects which CLIs you have and installs accordingly:

| CLI | What gets installed |
|-----|-------------------|
| Claude Code | Skills to `~/.claude/skills/`, SessionStart + UserPromptSubmit hooks |
| Codex | Skills to `~/.codex/skills/`, enable with `codex_hooks = true` in `~/.codex/config.toml` |
| OpenCode | Skills to `~/.config/opencode/skills/`, native TypeScript plugin to `~/.config/opencode/plugins/` |

Supports `--yes` (skip prompts), `--version X.Y.Z` (pin version), `--dry-run` (preview), and `--uninstall`.

### Claude Code Marketplace

```bash
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

### Codex CLI Marketplace

```bash
codex plugin marketplace add DollarDill/beads-superpowers
codex plugin install beads-superpowers@beads-superpowers-marketplace
```

After installing, enable hooks in `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

### npx (Vercel Skills CLI)

```bash
npx skills add DollarDill/beads-superpowers --all -y -g
# npx installs skills only — no hooks. Run the setup skill in your
# chosen agentic terminal to configure the SessionStart and
# UserPromptSubmit hooks.
```

## First project setup

Initialise beads in your project:

```bash
cd your-project
bd init
```

## Docs

**[dollardill.github.io/beads-superpowers](https://dollardill.github.io/beads-superpowers/)** — getting started, methodology, skills reference, example workflow, and tips.

## Built on

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — the skill system and development practices
- **[Beads](https://github.com/gastownhall/beads)** by Steve Yegge — persistent issue tracking with cross-session memory

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Ideas welcome in **[Discussions](https://github.com/DollarDill/beads-superpowers/discussions/27)**.

## License

[MIT](LICENSE)
