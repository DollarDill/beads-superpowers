# Installing beads-superpowers for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- `bd` (beads) CLI — `npm install -g @beads/bd` — required for persistent task memory

## Installation

Add beads-superpowers to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["beads-superpowers@git+https://github.com/DollarDill/beads-superpowers.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all skills.

Verify by asking: "Tell me about your superpowers"

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install beads-superpowers separately for each one.

## Migrating from the installer copy-mode (pre-0.12)

Earlier releases installed OpenCode support by copying files. If you used
`install.sh` before 0.12, remove the old copies to avoid double injection
once the git plugin is active:

```bash
rm -f ~/.config/opencode/plugins/beads-superpowers-plugin.ts
rm -f ~/.config/opencode/hooks/session-start
# Copied skills (superseded by the plugin's auto-registered skills):
for d in ~/.config/opencode/skills/*/; do [ -f "$d/SKILL.md" ] && rm -rf "$d"; done
```

Or run `install.sh --uninstall`, which removes the same artifacts.

## Usage

Use OpenCode's native `skill` tool:

```text
use skill tool to list skills
use skill tool to load brainstorming
```

## Updating

OpenCode installs beads-superpowers through a git-backed package spec. Some
OpenCode and Bun versions pin that resolved git dependency in a lockfile or
cache, so a restart may not pick up the newest beads-superpowers commit. If
updates do not appear, clear OpenCode's package cache or reinstall the plugin.

To pin a specific version:

```json
{
  "plugin": ["beads-superpowers@git+https://github.com/DollarDill/beads-superpowers.git#v0.11.0"]
}
```

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i beads-superpowers`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Windows install issues

Some Windows OpenCode builds have upstream installer issues with git-backed
plugin specs, including cache paths for `git+https` URLs and Bun not finding
`git.exe` even when it works in a normal terminal. If OpenCode cannot install
the plugin, try installing with system npm and pointing OpenCode at the local
package:

```powershell
npm install beads-superpowers@git+https://github.com/DollarDill/beads-superpowers.git --prefix "$HOME\.config\opencode"
```

Then use the installed package path in `opencode.json`:

```json
{
  "plugin": ["~/.config/opencode/node_modules/beads-superpowers"]
}
```

### Skills not found

1. Use `skill` tool to list what's discovered
2. Check that the plugin is loading (see above)

### Tool mapping

See skills/using-superpowers/references/opencode-tools.md — note this plugin
tracks ALL tasks with the bd (beads) CLI, not the todo tools.

## Getting Help

- Report issues: <https://github.com/DollarDill/beads-superpowers/issues>
- Full documentation: <https://github.com/DollarDill/beads-superpowers>
