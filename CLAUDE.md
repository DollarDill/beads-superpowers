# beads-superpowers — Claude Code Plugin

This project IS a Claude Code marketplace plugin that merges [Superpowers](https://github.com/obra/superpowers) skills with [Beads](https://github.com/gastownhall/beads) issue tracking.

## Plugin Structure

```
.claude-plugin/plugin.json   # Plugin manifest
hooks/                       # SessionStart hook (injects skills + bd prime)
skills/                      # 14 beads-native skills
agents/                      # Code reviewer agent
commands/                    # Deprecated slash commands
docs/                        # Analysis documentation
```

## Beads Integration

This plugin's skills use `bd` (beads) for ALL task tracking. The SessionStart hook runs `bd prime` automatically. Skills reference `bd create`, `bd close`, `bd update --claim`, `bd ready`, and `bd dep add` throughout.

**If you have `bd setup claude` hooks installed:** Run `bd setup claude --remove` to avoid duplicate SessionStart hooks. This plugin already handles `bd prime` injection.

## Build & Test

This is a documentation-only plugin (Markdown skills, no build step). To test:

```bash
# Verify plugin structure
cat .claude-plugin/plugin.json | python3 -m json.tool
ls skills/*/SKILL.md | wc -l   # Should be 14

# Verify zero TodoWrite usage
grep -r "TodoWrite" skills/ | grep -v "Do NOT use TodoWrite" | grep -v "replaces TodoWrite"
# Should return empty

# Verify beads integration
grep -r "bd create\|bd close\|bd ready" skills/ | wc -l   # Should be 30+

# Test hook
bash hooks/session-start 2>&1 | python3 -m json.tool
```

## Conventions

- Skills are plain Markdown with YAML frontmatter — no code, no build step
- Every task reference uses `bd` commands, never TodoWrite
- Subagent prompts (implementer, spec-reviewer, code-quality-reviewer) do NOT touch beads — orchestrator only
- The "Land the Plane" protocol is in `finishing-a-development-branch` Step 6
