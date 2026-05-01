<p align="center">
  <img src="assets/banner.svg" alt="beads-superpowers — Process discipline and persistent memory for AI coding agents" width="100%" />
</p>

<p align="center">
  <em>Process discipline and persistent memory for AI coding agents.</em>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href=".claude-plugin/plugin.json"><img alt="Plugin version" src="https://img.shields.io/badge/plugin-v0.5.0-4f46e5.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml"><img alt="Release" src="https://github.com/DollarDill/beads-superpowers/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://github.com/DollarDill/beads-superpowers/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/DollarDill/beads-superpowers?style=social"></a>
</p>

---

## Quick Start

```bash
# Install the plugin (pick one)
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash

# Or via Claude Code Marketplace
claude plugin marketplace add DollarDill/beads-superpowers
claude plugin install beads-superpowers@beads-superpowers-marketplace
```

Then in any project:

```bash
bd init
```

That's it. 21 skills are now active. Run `/skills` in Claude Code to verify.

## Documentation

Everything you need is on the docs site:

| | |
|---|---|
| **[Getting Started](https://dollardill.github.io/beads-superpowers/getting-started.html)** | Installation, configuration, troubleshooting |
| **[Methodology](https://dollardill.github.io/beads-superpowers/methodology.html)** | Why this exists and how it works |
| **[Skills Reference](https://dollardill.github.io/beads-superpowers/skills.html)** | All 21 skills — triggers, categories, commands |
| **[Example Workflow](https://dollardill.github.io/beads-superpowers/workflow.html)** | Complete development lifecycle with diagrams |
| **[Tips & Tricks](https://dollardill.github.io/beads-superpowers/tips.html)** | Cheat sheet, common issues, best practices |

Want the full workflow out of the box? Grab the [example CLAUDE.md + agent configs](example-workflow/).

## Attribution

Built on two excellent projects:

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — composable skills for AI agents
- **[Beads](https://github.com/gastownhall/beads)** by Steve Yegge — persistent issue tracking for AI agents

## Contributing

Contributions are welcome! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the guide.

Have an idea for a new skill or improvement? **[Drop a suggestion in Discussions](https://github.com/DollarDill/beads-superpowers/discussions/27)** — we read every one.

## License

[MIT](LICENSE)
