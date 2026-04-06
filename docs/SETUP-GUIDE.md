# Setup Guide: beads-superpowers

> Detailed installation, configuration, hook management, and troubleshooting.

## Prerequisites

### Required

1. **Claude Code** — Install from [claude.ai/claude-code](https://claude.ai/claude-code)
2. **Beads** — Install the `bd` CLI:
   ```bash
   # Homebrew (macOS/Linux)
   brew install beads

   # npm (any platform)
   npm install -g @beads/bd

   # Direct install script
   curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

   # Verify installation
   bd version
   ```

### Optional

- **Git** — Required for the Land the Plane protocol (`git push`)
- **Dolt remote** — Required for `bd dolt push/pull` (cross-session sync). Sign up at [dolthub.com](https://dolthub.com)

## Installation

### Method 1: Claude Code Marketplace (Recommended)

When the plugin is published to the marketplace:

```bash
# In Claude Code
/plugin install beads-superpowers
```

### Method 2: From GitHub Repository

```bash
# Add the marketplace
/plugin marketplace add dollardill/beads-superpowers

# Install the plugin
/plugin install beads-superpowers@beads-superpowers
```

### Method 3: Local Development

Clone the repo and register it locally:

```bash
git clone https://github.com/dollardill/beads-superpowers.git
cd beads-superpowers

# Register as a local plugin in Claude Code
# (Follow Claude Code's local plugin registration docs)
```

## Post-Installation Setup

### Step 1: Initialize Beads in Your Project

If your project doesn't have beads yet:

```bash
cd your-project
bd init
```

This creates:
- `.beads/` directory with config, metadata, and git hooks
- `CLAUDE.md` with beads instructions (will be superseded by the plugin)
- `AGENTS.md` with agent instructions (will be superseded by the plugin)

### Step 2: Remove Duplicate Beads Hooks

**This is important.** `bd init` installs Claude Code hooks that run `bd prime` on SessionStart. The beads-superpowers plugin's SessionStart hook **also** runs `bd prime`. Having both causes redundant context injection (~2x token overhead).

```bash
# Remove bd's Claude Code hooks
bd setup claude --remove

# Verify removal
cat .claude/settings.json
# Should NOT contain "bd prime" entries
```

If you forget this step, the plugin will detect the duplication and display a warning at session start.

### Step 3: Set Up Dolt Remote (Optional but Recommended)

For cross-session persistence:

```bash
# Create a DoltHub account at dolthub.com, then:
bd dolt remote add origin https://doltremoteapi.dolthub.com/your-org/your-repo

# Test the connection
bd dolt push
```

### Step 4: Verify Everything Works

```bash
# Start a new Claude Code session
# You should see the beads-superpowers context injected automatically

# Verify skills are available
/skills
# Should list 14 beads-superpowers: skills

# Verify bd is working
bd ready
bd stats
```

## How the Hooks Work

### SessionStart Hook

The plugin registers a single `SessionStart` hook in `hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|clear|compact",
      "hooks": [{
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
        "async": false
      }]
    }]
  }
}
```

This fires on every session start, clear, and compact event. The `hooks/session-start` script:

1. **Reads `using-superpowers/SKILL.md`** — the bootstrap skill that routes to all other skills
2. **Runs `bd prime`** — captures beads workflow context and persistent memories
3. **Checks for duplicate hooks** — warns if `bd setup claude` hooks are still installed
4. **Outputs platform-specific JSON** — Claude Code, Cursor, and Copilot CLI each expect different formats

The combined output (~2-3k tokens) provides the agent with:
- Skill routing instructions (which skill to invoke when)
- Beads awareness (key concepts, quick reference, rules)
- Beads CLI context (commands, workflow, memories)
- Anti-rationalization enforcement (Red Flags table)

### How the Plugin Detects Duplicate Hooks

The `session-start` script checks for `"bd prime"` in `.claude/settings.json`:

```bash
if grep -q '"bd prime"' ".claude/settings.json" 2>/dev/null; then
    # Warn user to run: bd setup claude --remove
fi
```

This means if you've run `bd setup claude` (or `bd init` which calls it), the plugin will detect the overlap and warn you.

### Platform Detection

The hook outputs JSON in the correct format for each platform:

| Platform | Detection | Output Format |
|----------|-----------|--------------|
| Cursor | `CURSOR_PLUGIN_ROOT` set | `{"additional_context": "..."}` |
| Claude Code | `CLAUDE_PLUGIN_ROOT` set, no `COPILOT_CLI` | `{"hookSpecificOutput": {"additionalContext": "..."}}` |
| Copilot CLI | `COPILOT_CLI` set | `{"additionalContext": "..."}` |
| Other | Fallback | `{"additionalContext": "..."}` |

### Windows Support

The `hooks/run-hook.cmd` file is a polyglot wrapper:
- On Windows: `cmd.exe` runs the batch portion, which finds Git Bash and executes the hook
- On Unix: The shell interprets the file as a bash script (`:` is a no-op)

This means the plugin works on Windows without WSL, as long as Git for Windows (Git Bash) is installed.

## Configuration

### Plugin Configuration

The plugin itself requires no configuration. It reads skills from `skills/`, agents from `agents/`, and runs hooks from `hooks/`.

### Beads Configuration

Beads is configured per-project in `.beads/config.yaml`:

```yaml
# Issue ID prefix (default: directory name)
# issue:
#   prefix: my-project

# Dolt auto-commit policy
# dolt:
#   auto-commit: on|off|batch

# Sync settings
# sync:
#   mode: dolt-native
```

### Customizing Skills

To modify a skill's behaviour for your project:

1. The plugin's skills are read-only (managed by the plugin system)
2. Override behaviour via your project's `CLAUDE.md` — user instructions take priority over skills
3. Or fork the plugin and modify skills directly

**Instruction priority:**
```
1. User's CLAUDE.md instructions — HIGHEST
2. Plugin skills — override default behaviour
3. Default system prompt — LOWEST
```

## Troubleshooting

### "bd: command not found"

Beads is not installed. Install it:
```bash
brew install beads
# or
npm install -g @beads/bd
```

### "No .beads directory found"

Initialize beads in your project:
```bash
cd your-project
bd init
```

### Skills not showing up

Verify the plugin is installed:
```bash
/plugins          # In Claude Code — should list beads-superpowers
/skills           # Should show beads-superpowers: prefixed skills
```

### Duplicate context injection (double bd prime)

The plugin's hook already runs `bd prime`. Remove the duplicate:
```bash
bd setup claude --remove
```

### Hook not firing

Check that the hook is executable:
```bash
ls -la hooks/session-start
# Should show -rwxr-xr-x

# If not:
chmod +x hooks/session-start
```

### "bd dolt push" fails

Set up a Dolt remote first:
```bash
bd dolt remote add origin <url>
```

Or if you don't need remote sync, the push failure is harmless — beads still works locally.

### Skills reference TodoWrite

If you see any active TodoWrite references in skills (not "Do NOT use TodoWrite"), report it as a bug. The migration should have caught all instances.

Verify:
```bash
grep -r "TodoWrite" skills/ | grep -v "Do NOT use" | grep -v "replaces"
# Should return empty
```

## Updating

### Plugin Updates

```bash
# In Claude Code
/plugin update beads-superpowers
```

### Beads Updates

```bash
brew upgrade beads
# or
npm update -g @beads/bd
```

## Uninstalling

### Remove the Plugin

```bash
# In Claude Code
/plugin uninstall beads-superpowers
```

### Restore bd setup claude Hooks (if desired)

If you want to go back to standalone beads without the plugin:
```bash
bd setup claude
```

This re-installs the SessionStart hook that runs `bd prime` independently.
