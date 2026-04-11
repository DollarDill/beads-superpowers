# Security Policy

## Supported versions

This project is in active development. Security fixes apply only to the
latest released version.

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub
issues, discussions, or pull requests.**

Instead, use GitHub's private vulnerability reporting:

1. Navigate to the [Security tab](https://github.com/DollarDill/beads-superpowers/security)
2. Click **Report a vulnerability**
3. Fill in the advisory form with as much detail as you can provide

GitHub will notify the maintainer privately and create a draft advisory.

If you cannot use GitHub's private reporting, email the maintainer directly
via the contact details on [DollarDill's GitHub profile](https://github.com/DollarDill).

## What to include

- A description of the vulnerability and its impact
- Steps to reproduce — ideally a minimal repro
- The version of `beads-superpowers` you tested against
- Whether the vulnerability has been disclosed elsewhere

## Response timeline

- **Initial acknowledgement:** within 5 business days
- **Triage and severity assessment:** within 10 business days
- **Patch or mitigation:** depends on severity; critical issues prioritised

## Scope

This policy covers:

- The `beads-superpowers` plugin code (skills, hooks, scripts)
- The `.github/` automation (CI workflow, Dependabot, templates)
- The plugin manifests (`.claude-plugin/plugin.json`, `marketplace.json`)

This policy does **not** cover:

- Upstream [Superpowers](https://github.com/obra/superpowers) — report there
- Upstream [Beads](https://github.com/gastownhall/beads) — report there
- Claude Code itself — report at [anthropics/claude-code](https://github.com/anthropics/claude-code)

## Recognition

Reporters who follow this policy will be credited in the security advisory
unless they request otherwise.
