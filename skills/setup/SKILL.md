---
name: setup
description: Use after installing beads-superpowers skills via npx to configure the SessionStart and UserPromptSubmit hooks that make skills auto-activate. Also use when skills are installed but not triggering automatically, or when the user says "set up beads-superpowers", "configure hooks", or "skills aren't activating".
---

# Setup: Post-Install Hook Configuration

**Announce at start:** "I'm using the setup skill to configure hooks for beads-superpowers."

## Purpose

When beads-superpowers skills are installed via `npx skills add` (not the marketplace plugin), two hooks are missing:

1. **SessionStart hook** — injects the `using-superpowers` bootstrap skill + `bd prime` context at session start
2. **UserPromptSubmit hook** — injects a skill trigger reminder on every user message, preventing mid-session drift

Without these hooks, Claude doesn't automatically load skills or get reminded to use them.

This skill detects the gap and installs both hooks.

## Detection Phase

Check whether hooks are already configured:

```bash
# 1. Check if marketplace plugin is installed (has its own hooks)
ls ~/.claude/plugins/cache/beads-superpowers-marketplace/ 2>/dev/null && echo "PLUGIN INSTALLED"

# 2. Check if SessionStart hook already references beads-superpowers
grep -q "beads-superpowers" ~/.claude/settings.json 2>/dev/null && echo "HOOK EXISTS"

# 3. Check if skills are installed globally
ls ~/.claude/skills/using-superpowers/SKILL.md 2>/dev/null && echo "SKILLS INSTALLED (user-level)"
ls ~/.agents/skills/using-superpowers/SKILL.md 2>/dev/null && echo "SKILLS INSTALLED (agents)"
```

### Decision Matrix

| State | Action |
|-------|--------|
| Plugin installed | ✅ Already configured — hooks come from the plugin. Nothing to do. |
| Hook exists in settings.json | ✅ Already configured. Nothing to do. |
| Skills installed, no hook | ⚠️ **Install the hook** → proceed below |
| No skills, no plugin | ❌ Nothing to configure. Tell user to install first. |

## Scope Selection

Before installing, **use the `AskUserQuestion` tool** to ask where hooks should be installed:

```json
{
  "questions": [{
    "question": "Where should the SessionStart hook be installed?",
    "header": "Hook scope",
    "options": [
      {
        "label": "Global (Recommended)",
        "description": "Install to ~/.claude/settings.json — hook activates in every project on this machine"
      },
      {
        "label": "Project-level only",
        "description": "Install to .claude/settings.json in the current project — only activates in this repo"
      }
    ],
    "multiSelect": false
  }]
}
```

- **Global**: Hook script at `~/.claude/hooks/`, registered in `~/.claude/settings.json`
- **Project**: Hook script at `.claude/hooks/`, registered in `.claude/settings.json`

Adjust all paths in Steps 1-4 based on the user's choice.

## Hook Installation

### Step 1: Create the hook script

Create `~/.claude/hooks/beads-superpowers-session-start.sh`:

```bash
cat > ~/.claude/hooks/beads-superpowers-session-start.sh << 'HOOKSCRIPT'
#!/usr/bin/env bash
# SessionStart hook for beads-superpowers (npx install path)
# Injects using-superpowers skill content + bd prime context at session start.
set -euo pipefail

# Find using-superpowers SKILL.md (check multiple locations)
SKILL_FILE=""
for path in \
  "${HOME}/.claude/skills/using-superpowers/SKILL.md" \
  "${HOME}/.agents/skills/using-superpowers/SKILL.md" \
  "${HOME}/.config/superpowers/skills/using-superpowers/SKILL.md"; do
    if [ -f "$path" ]; then
        SKILL_FILE="$path"
        break
    fi
done

if [ -z "$SKILL_FILE" ]; then
    printf '{"additionalContext": "beads-superpowers skills not found. Run: npm exec --yes -- skills@latest add DollarDill/beads-superpowers --all -y -g"}\n'
    exit 0
fi

skill_content=$(cat "$SKILL_FILE" 2>/dev/null || echo "Error reading skill")

# Run bd prime if available
beads_context=""
if command -v bd &>/dev/null; then
    beads_context=$(bd prime 2>/dev/null || true)
fi

# Escape for JSON
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

skill_escaped=$(escape_for_json "$skill_content")
beads_escaped=$(escape_for_json "$beads_context")

ctx="<EXTREMELY_IMPORTANT>\nYou have beads-superpowers.\n\n**Below is the full content of your 'beads-superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${skill_escaped}\n</EXTREMELY_IMPORTANT>"

if [ -n "$beads_context" ]; then
    ctx="${ctx}\n\n<beads-context>\n${beads_escaped}\n</beads-context>"
fi

printf '{"additionalContext": "%s"}\n' "$ctx"
exit 0
HOOKSCRIPT

chmod +x ~/.claude/hooks/beads-superpowers-session-start.sh
```

### Step 1b: Create the UserPromptSubmit hook script

Create `~/.claude/hooks/beads-superpowers-reminder.sh`:

```bash
cat > ~/.claude/hooks/beads-superpowers-reminder.sh << 'REMINDERSCRIPT'
#!/usr/bin/env bash
# UserPromptSubmit hook for beads-superpowers (npx install path)
# Injects a skill trigger reminder on every user message.
set -euo pipefail

cat << 'REMINDER'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "SUPERPOWERS REMINDER: Before responding, check if any beads-superpowers skill applies to this task. Key triggers:\n- Bug/test failure → beads-superpowers:systematic-debugging\n- Writing code → beads-superpowers:test-driven-development\n- New feature/design → beads-superpowers:brainstorming\n- Challenge/stress-test design → beads-superpowers:stress-test\n- Writing a plan → beads-superpowers:writing-plans\n- Executing a plan → beads-superpowers:subagent-driven-development or beads-superpowers:executing-plans\n- Research question → beads-superpowers:research-driven-development\n- Complex task (6+ files) → beads-superpowers:using-git-worktrees\n- About to claim done → beads-superpowers:verification-before-completion\n- Code review needed → beads-superpowers:requesting-code-review\n- Received review feedback → beads-superpowers:receiving-code-review\n- Branch complete → beads-superpowers:finishing-a-development-branch\nAlso available: document-release, getting-up-to-speed, dispatching-parallel-agents, project-init, setup, writing-skills, auditing-upstream-drift\nIf even 1% chance a skill applies, you MUST invoke it via the Skill tool."
  }
}
REMINDER

exit 0
REMINDERSCRIPT

chmod +x ~/.claude/hooks/beads-superpowers-reminder.sh
```

### Step 2: Backup settings.json

**Always back up before modifying.** This is non-negotiable.

```bash
# Create timestamped backup
cp -f ~/.claude/settings.json ~/.claude/settings.json.backup-$(date +%Y%m%d-%H%M%S)
echo "✓ Backup created at ~/.claude/settings.json.backup-$(date +%Y%m%d-%H%M%S)"
```

If anything goes wrong, restore with:
```bash
cp -f ~/.claude/settings.json.backup-<timestamp> ~/.claude/settings.json
```

### Step 3: Register the hook in settings.json

Read `~/.claude/settings.json`, add the SessionStart hook entry, and write back:

```bash
# Use python3 to safely modify JSON (preserves existing hooks)
python3 << 'PYSETUP'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")

# Read existing settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

# Ensure hooks.SessionStart exists
hooks = settings.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [])

# Check if our hook is already registered
hook_cmd = os.path.expanduser("~/.claude/hooks/beads-superpowers-session-start.sh")
already_exists = any(
    hook_cmd in h.get("hooks", [{}])[0].get("command", "")
    for h in session_hooks
    if isinstance(h, dict) and "hooks" in h
)

if not already_exists:
    session_hooks.append({
        "matcher": "startup|clear|compact",
        "hooks": [{
            "type": "command",
            "command": hook_cmd
        }]
    })
    print("✓ SessionStart hook registered")
else:
    print("✓ SessionStart hook already registered")

# UserPromptSubmit hook
reminder_cmd = os.path.expanduser("~/.claude/hooks/beads-superpowers-reminder.sh")
prompt_hooks = hooks.setdefault("UserPromptSubmit", [])
reminder_exists = any(
    "beads-superpowers" in str(h) for h in prompt_hooks
)
if not reminder_exists:
    prompt_hooks.append({
        "matcher": "",
        "hooks": [{
            "type": "command",
            "command": reminder_cmd
        }]
    })
    print("✓ UserPromptSubmit hook registered")
else:
    print("✓ UserPromptSubmit hook already registered")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYSETUP
```

### Step 4: Verify

```bash
# Test both hooks produce valid JSON
bash ~/.claude/hooks/beads-superpowers-session-start.sh 2>&1 | python3 -m json.tool > /dev/null && echo "✓ SessionStart hook: valid JSON"
bash ~/.claude/hooks/beads-superpowers-reminder.sh 2>&1 | python3 -m json.tool > /dev/null && echo "✓ UserPromptSubmit hook: valid JSON"

# Verify settings.json has both hooks
grep -q "beads-superpowers-session-start" ~/.claude/settings.json && echo "✓ SessionStart hook registered"
grep -q "beads-superpowers-reminder" ~/.claude/settings.json && echo "✓ UserPromptSubmit hook registered"
```

### Step 5: Report

```
✓ beads-superpowers hooks installed.

What was configured:
  SessionStart hook: ~/.claude/hooks/beads-superpowers-session-start.sh
  UserPromptSubmit hook: ~/.claude/hooks/beads-superpowers-reminder.sh
  Registered in: ~/.claude/settings.json (hooks.SessionStart + hooks.UserPromptSubmit)
  Backup at: ~/.claude/settings.json.backup-<timestamp>

Restart Claude Code for hooks to take effect.

SessionStart injects the using-superpowers skill + bd prime context.
UserPromptSubmit injects a skill trigger reminder on every message.
```

## Uninstall

To remove the hook:

```bash
# Remove both hook scripts
rm -f ~/.claude/hooks/beads-superpowers-session-start.sh
rm -f ~/.claude/hooks/beads-superpowers-reminder.sh

# Remove both hook entries from settings.json
python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
s = json.load(open(path))
for key in ['SessionStart', 'UserPromptSubmit']:
    if key in s.get('hooks', {}):
        s['hooks'][key] = [
            h for h in s['hooks'][key]
            if 'beads-superpowers' not in str(h)
        ]
json.dump(s, open(path,'w'), indent=2)
print('✓ Both hooks removed from settings.json')
"
```

## Red Flags

**Never:**
- Overwrite the entire settings.json — always read-modify-write
- Skip the backup step — always back up before modifying settings
- Install hooks if the marketplace plugin is already active (duplicate injection)
- Install to global settings when user chose project-level, or vice versa

**Always:**
- Check for existing hooks before adding
- Verify hook output is valid JSON after installation
- Tell the user to restart Claude Code

## Integration

**Called after:**
- `npm exec --yes -- skills@latest add DollarDill/beads-superpowers --all -y -g`
- Any npx/manual skills installation

**Pairs with:**
- **project-init** — setup handles hooks, project-init handles beads/Dolt database
- **using-superpowers** — the skill this hook injects at session start
