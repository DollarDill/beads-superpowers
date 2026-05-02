# beads-superpowers

A Claude Code plugin with **{{ skill_count }}** skills that enforce development practices — TDD, systematic debugging, design-before-code, two-stage code review — and a persistent issue tracker that remembers context across sessions.

The skills come from [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent. The tracker comes from [Beads](https://github.com/gastownhall/beads) by Steve Yegge. This plugin wires them together so skills create and close issues as they run, and the tracker feeds context back into each new session.

**Current version:** v{{ version }} · {{ skill_count }} skills

## Where to start

**[Getting Started](getting-started.md)** if you want to install and configure the plugin.

**[Methodology](methodology.md)** if you want to understand the development lifecycle before installing.

**[Skills Reference](skills.md)** if you already have it installed and want to know what each skill does.

**[Example Workflow](workflow.md)** if you want a ready-to-use orchestrator agent that ties everything together.

**[Tips & Tricks](tips.md)** for the cheat sheet and common issues.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

Then in any project: `bd init`. Run `/skills` in Claude Code to confirm.
