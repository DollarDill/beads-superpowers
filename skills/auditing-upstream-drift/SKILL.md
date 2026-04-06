---
name: auditing-upstream-drift
description: Use when checking if beads-superpowers skills are outdated compared to upstream obra/superpowers or gastownhall/beads, or when auditing the plugin for missing capabilities, version drift, or stale content
---

# Auditing Upstream Drift

Detect staleness, missing capabilities, and version drift between this plugin and its upstream sources.

## When to Use

- Periodically (monthly or after upstream releases)
- Before a new plugin release
- When a user reports a skill behaves differently than upstream superpowers
- When beads adds new features that skills should leverage

## Upstream Sources

| Source | Repository | What We Track |
|--------|-----------|---------------|
| **Superpowers** | [obra/superpowers](https://github.com/obra/superpowers) | Skills content, skill additions/removals, hook changes, plugin structure |
| **Beads** | [gastownhall/beads](https://github.com/gastownhall/beads) | CLI commands, new features, deprecations, bd prime format changes |

## The Audit Process

You MUST create an audit bead (`bd create "Audit: upstream drift check" -t chore`) and complete each phase in order.

### Phase 1: Clone and Compare Superpowers

```bash
# Clone latest upstream
git clone --depth 1 https://github.com/obra/superpowers.git /tmp/superpowers-upstream

# Get upstream version
grep '"version"' /tmp/superpowers-upstream/package.json

# Get our baseline version (forked from)
head -10 CHANGELOG.md   # Shows "Forked from obra/superpowers v5.0.7"
```

**Check 1.1 — Version Gap:**
Compare upstream version against our fork baseline. If upstream is newer, there are potentially new skills or skill changes.

**Check 1.2 — New Skills:**
```bash
# List upstream skills
ls -d /tmp/superpowers-upstream/skills/*/

# List our skills
ls -d skills/*/

# Diff the lists
diff <(ls /tmp/superpowers-upstream/skills/) <(ls skills/)
```

If upstream has skills we don't have, assess each:
- Is it relevant to beads-superpowers? → Copy and add beads integration
- Is it platform-specific (Codex, OpenCode, Gemini only)? → Skip

**Check 1.3 — Skill Content Changes:**
```bash
# For each skill, diff the upstream SKILL.md against ours
for skill in /tmp/superpowers-upstream/skills/*/SKILL.md; do
    name=$(basename $(dirname "$skill"))
    if [ -f "skills/$name/SKILL.md" ]; then
        echo "=== $name ==="
        diff "$skill" "skills/$name/SKILL.md" | head -30
        echo ""
    fi
done
```

For each skill with changes:
1. **Read the upstream diff carefully** — What changed and why?
2. **Check if the change conflicts with our beads integration** — Does it touch areas we modified (TodoWrite replacement, flowcharts, beads sections)?
3. **Categorise:**
   - **Safe merge**: Upstream change doesn't touch our modifications → apply upstream change
   - **Conflict**: Upstream change touches our beads-integrated sections → manual review required
   - **New content**: Upstream added new sections → assess and add with beads awareness
   - **Irrelevant**: Change is platform-specific or doesn't apply → skip

**Check 1.4 — New Companion Files:**
```bash
# Check for new files in upstream skill directories
for dir in /tmp/superpowers-upstream/skills/*/; do
    name=$(basename "$dir")
    if [ -d "skills/$name" ]; then
        diff <(ls "$dir" 2>/dev/null | sort) <(ls "skills/$name" 2>/dev/null | sort) | grep "^<"
    fi
done
```

**Check 1.5 — Hook Changes:**
```bash
diff /tmp/superpowers-upstream/hooks/session-start hooks/session-start
diff /tmp/superpowers-upstream/hooks/hooks.json hooks/hooks.json
```

Our hook is intentionally different (adds bd prime), but check if upstream changed the structure or added new hooks.

**Check 1.6 — Plugin Manifest Changes:**
```bash
diff /tmp/superpowers-upstream/.claude-plugin/plugin.json .claude-plugin/plugin.json
```

### Phase 2: Check Beads Capabilities

```bash
# Get current beads version
bd version

# Check for new commands since our integration
bd --help 2>&1 | head -50
```

**Check 2.1 — New bd Commands:**
Compare the commands listed in `bd --help` against the commands we reference in skills. Look for:
- New commands that could improve skill workflows
- Deprecated commands we still reference
- Changed flags or syntax

**Check 2.2 — bd prime Format Changes:**
```bash
bd prime 2>&1 > /tmp/current-prime.txt
```

Compare the prime output against what our `hooks/session-start` expects. If bd prime's format changed, our hook may need updating.

**Check 2.3 — New Beads Features:**
Check the beads CHANGELOG or release notes for new features:
```bash
bd version   # Note the version
# Then check: https://github.com/gastownhall/beads/releases
```

Features to watch for:
- New dependency types → update `bd dep add` references in skills
- New issue types → update `bd create -t` references
- New status codes → update lifecycle references
- New CLI flags → update quick reference tables
- Changes to gate/molecule/formula system → assess skill impact

### Phase 3: Content Staleness Check

**Check 3.1 — TodoWrite Residue:**
```bash
grep -r "TodoWrite" skills/ | grep -v "Do NOT use TodoWrite" | grep -v "replaces TodoWrite"
```
Any results here are bugs — active TodoWrite references that were missed.

**Check 3.2 — Beads Command Accuracy:**
```bash
# Verify all bd commands we reference actually exist
for cmd in "bd create" "bd update" "bd close" "bd ready" "bd dep add" "bd dolt push" "bd remember" "bd show" "bd list" "bd stats"; do
    if ! $cmd --help &>/dev/null; then
        echo "WARNING: $cmd may not exist or has changed"
    fi
done
```

**Check 3.3 — Cross-Reference Integrity:**
Verify the progressive skill chain is intact:
```bash
# brainstorming should reference writing-plans
grep -l "writing-plans" skills/brainstorming/SKILL.md

# writing-plans should reference subagent-driven-development and executing-plans
grep -l "subagent-driven-development" skills/writing-plans/SKILL.md
grep -l "executing-plans" skills/writing-plans/SKILL.md

# subagent-driven-development should reference finishing-a-development-branch
grep -l "finishing-a-development-branch" skills/subagent-driven-development/SKILL.md

# executing-plans should reference finishing-a-development-branch
grep -l "finishing-a-development-branch" skills/executing-plans/SKILL.md
```

**Check 3.4 — Beads Awareness Completeness:**
```bash
# Every execution skill should reference bd commands
for skill in subagent-driven-development executing-plans finishing-a-development-branch brainstorming; do
    count=$(grep -c "bd " "skills/$skill/SKILL.md" 2>/dev/null || echo 0)
    echo "$skill: $count bd references"
done
```

If any execution skill has 0 bd references, it's missing beads integration.

### Phase 4: Generate Audit Report

Create a bead for each finding:

```bash
# For each issue found:
bd create "Drift: [description of what changed]" -t chore -p 3 --parent <audit-bead-id>

# For critical issues (breaking changes, missing skills):
bd create "CRITICAL: [description]" -t bug -p 1 --parent <audit-bead-id>
```

Write the audit report to `docs/audits/YYYY-MM-DD-upstream-drift.md`:

```markdown
# Upstream Drift Audit — YYYY-MM-DD

## Summary
- Superpowers upstream: vX.Y.Z (our baseline: v5.0.7)
- Beads version: vX.Y.Z
- New skills found: N
- Changed skills: N
- New beads features: N
- Issues created: N

## Findings
### Critical
- [List critical findings]

### Important
- [List important findings]

### Minor
- [List minor findings]

## Recommendations
- [List recommended actions]
```

Close the audit bead:
```bash
bd close <audit-bead-id> --reason "Audit complete: N findings, M critical"
```

## Audit Frequency

| Trigger | Recommended Action |
|---------|-------------------|
| Monthly | Run full audit (Phases 1-4) |
| Upstream minor release (patch/minor) | Run Phase 1 checks 1.2-1.4 only |
| Upstream major release | Run full audit + plan integration session |
| Beads minor release | Run Phase 2 only |
| Beads major release | Run Phases 2-3 |
| User reports skill mismatch | Run Phase 1 check 1.3 for the specific skill |
| Before plugin release | Run full audit as pre-release gate |

## Cleanup

```bash
rm -rf /tmp/superpowers-upstream
```
