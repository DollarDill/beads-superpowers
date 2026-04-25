# install.sh — Curl-Based Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Each Task becomes a bead (`bd create -t task --parent <epic-id>`). Steps within tasks use checkbox (`- [ ]`) syntax for human readability.

**Goal:** Add `install.sh` to the repo root — a curl-pipe-bash one-command installer that replaces the 7-step npx flow with a single command.

**Architecture:** Single bash script (~300 lines) with 5-phase pipeline: checks → consent → install → verify → next steps. Downloads GitHub release tarball, extracts 20 skills to `~/.claude/skills/`, creates SessionStart hook, registers in `~/.claude/settings.json`. Supports `--yes`, `--dry-run`, `--uninstall`, `--version` flags.

**Tech Stack:** Bash, curl, tar, python3 (for JSON manipulation).

**Spec:** `docs/beads-superpowers/specs/2026-04-25-curl-installer-design.md`

---

## File Structure

| File | Responsibility | Status |
|---|---|---|
| `install.sh` | The installer script (~300 lines) | NEW |
| `README.md` | Add "Option C: curl" to "Try it in 60 seconds" | MODIFY |
| `CHANGELOG.md` | Add entry under `[Unreleased]` | MODIFY |

## Task Sequencing

```
T1 (write install.sh — complete script)
  └─→ T2 (test: shellcheck + dry-run + help)
        └─→ T3 (test: full install + verify + uninstall in sandbox)
              ├─→ T4 (README.md)
              └─→ T5 (CHANGELOG.md)
```

---

## Task 1: Write install.sh

**Files:**
- Create: `install.sh`

- [ ] **Step 1.1: Verify file doesn't exist**

```bash
test -f install.sh && echo "EXISTS" || echo "DOES_NOT_EXIST"
```
Expected: `DOES_NOT_EXIST`

- [ ] **Step 1.2: Create install.sh with the complete script**

Create `install.sh` at the repo root with the content shown below. The script is ~310 lines and implements all 5 phases, flag parsing, uninstall, and dry-run.

```bash
#!/usr/bin/env bash
# beads-superpowers installer
# https://github.com/DollarDill/beads-superpowers
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
#   curl -fsSL <url> | bash -s -- --yes            # CI / non-interactive
#   curl -fsSL <url> | bash -s -- --version 0.4.0  # Pin version
#   curl -fsSL <url> | bash -s -- --dry-run         # Preview
#   curl -fsSL <url> | bash -s -- --uninstall       # Remove

set -euo pipefail

# --- Configuration ---
REPO="DollarDill/beads-superpowers"
FALLBACK_VERSION="0.4.0"
SKILLS_DIR="${BEADS_SUPERPOWERS_SKILLS_DIR:-$HOME/.claude/skills}"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
HOOK_SCRIPT="$HOOKS_DIR/beads-superpowers-session-start.sh"
VERSION_FILE="$SKILLS_DIR/.beads-superpowers-version"

KNOWN_SKILLS=(
  auditing-upstream-drift brainstorming dispatching-parallel-agents
  document-release executing-plans finishing-a-development-branch
  getting-up-to-speed project-init receiving-code-review
  requesting-code-review setup stress-test
  subagent-driven-development systematic-debugging test-driven-development
  using-git-worktrees using-superpowers verification-before-completion
  writing-plans writing-skills
)

# --- Flags ---
FLAG_YES=false
FLAG_DRY_RUN=false
FLAG_UNINSTALL=false
FLAG_VERSION=""
UPGRADING=false
HAS_BEADS=false
VERSION=""

# --- Colors (TTY-aware) ---
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

# --- Helpers ---
info()    { printf "${BLUE}info${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}warn${NC}  %s\n" "$1"; }
error()   { printf "${RED}error${NC} %s\n" "$1" >&2; }
success() { printf "${GREEN}✓${NC} %s\n" "$1"; }

usage() {
  cat <<'USAGE'
beads-superpowers installer

Usage:
  curl -fsSL <url> | bash
  curl -fsSL <url> | bash -s -- [flags]

Flags:
  --yes, -y       Skip consent prompt (CI mode)
  --dry-run       Print what would happen without doing it
  --uninstall     Remove beads-superpowers skills, hook, and settings entry
  --version X.Y.Z Pin to a specific version (default: latest GitHub release)
  --help, -h      Show this help

Environment:
  BEADS_SUPERPOWERS_SKILLS_DIR  Override skills install location (default: ~/.claude/skills)
USAGE
}

parse_flags() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y)     FLAG_YES=true ;;
      --dry-run)    FLAG_DRY_RUN=true ;;
      --uninstall)  FLAG_UNINSTALL=true ;;
      --version)    shift; FLAG_VERSION="${1:-}"; [ -z "$FLAG_VERSION" ] && { error "--version requires a value"; exit 1; } ;;
      --help|-h)    usage; exit 0 ;;
      *)            error "Unknown flag: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

# --- Phase 1: Checks ---
check_prerequisites() {
  local missing=()
  command -v curl >/dev/null 2>&1    || missing+=(curl)
  command -v python3 >/dev/null 2>&1 || missing+=(python3)
  command -v tar >/dev/null 2>&1     || missing+=(tar)
  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing required tools: ${missing[*]}"
    echo "  Install via: brew install ${missing[*]}  (macOS)"
    echo "           or: apt install ${missing[*]}   (Linux)"
    exit 1
  fi
}

detect_upstream_conflict() {
  if [ -f "$PLUGINS_FILE" ]; then
    if python3 -c "
import json, sys
try:
    d = json.load(open('$PLUGINS_FILE'))
    if 'superpowers@claude-plugins-official' in d.get('plugins', {}):
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null; then
      error "Upstream superpowers plugin detected."
      echo
      echo "  beads-superpowers supersedes the upstream superpowers plugin."
      echo "  Having both installed causes duplicate skill loading."
      echo
      echo "  Uninstall it first:"
      echo "    claude plugin uninstall superpowers@claude-plugins-official"
      echo
      echo "  Then re-run this installer."
      exit 1
    fi
  fi
}

resolve_version() {
  if [ -n "$FLAG_VERSION" ]; then
    VERSION="$FLAG_VERSION"
    return
  fi
  VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'].lstrip('v'))" 2>/dev/null) || true
  if [ -z "$VERSION" ]; then
    warn "Could not fetch latest version from GitHub API. Using fallback: v$FALLBACK_VERSION"
    VERSION="$FALLBACK_VERSION"
  fi
}

detect_existing_install() {
  if [ -f "$VERSION_FILE" ]; then
    local installed
    installed=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    if [ "$installed" = "$VERSION" ]; then
      success "beads-superpowers v$VERSION is already installed."
      exit 0
    fi
    info "Upgrading beads-superpowers: v$installed → v$VERSION"
    UPGRADING=true
  fi
}

detect_beads() {
  command -v bd >/dev/null 2>&1 && HAS_BEADS=true || true
}

# --- Phase 2: Consent ---
print_consent() {
  echo
  printf "${BOLD}beads-superpowers v%s installer${NC}\n" "$VERSION"
  echo
  echo "This script will:"
  if [ "$UPGRADING" = true ]; then
    echo "  • Upgrade 20 skills in $SKILLS_DIR/"
  else
    echo "  • Download 20 skills to $SKILLS_DIR/"
  fi
  echo "  • Create SessionStart hook at $HOOK_SCRIPT"
  echo "  • Register hook in $SETTINGS_FILE (backup created first)"
  echo
}

wait_for_consent() {
  if [ "$FLAG_YES" = true ] || [ ! -t 0 ]; then
    return
  fi
  printf "Press Enter to continue (or Ctrl+C to cancel)... "
  read -r
}

# --- Phase 3: Install ---
do_install() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  info "Downloading beads-superpowers v$VERSION..."
  local tarball_url="https://github.com/$REPO/archive/refs/tags/v${VERSION}.tar.gz"
  if ! curl -fsSL "$tarball_url" -o "$tmpdir/release.tar.gz"; then
    error "Failed to download: $tarball_url"
    echo "  Check your network connection or try: --version <known-tag>"
    exit 1
  fi

  info "Extracting..."
  mkdir -p "$tmpdir/extracted"
  tar xzf "$tmpdir/release.tar.gz" --strip-components=1 -C "$tmpdir/extracted"

  mkdir -p "$SKILLS_DIR" "$HOOKS_DIR"

  info "Installing skills to $SKILLS_DIR/..."
  local installed_count=0
  for skill in "${KNOWN_SKILLS[@]}"; do
    if [ -d "$tmpdir/extracted/skills/$skill" ]; then
      rm -rf "${SKILLS_DIR:?}/$skill"
      cp -rf "$tmpdir/extracted/skills/$skill" "$SKILLS_DIR/$skill"
      installed_count=$((installed_count + 1))
    else
      warn "Skill not found in release tarball: $skill"
    fi
  done

  info "Creating SessionStart hook..."
  write_hook_script

  if [ -f "$SETTINGS_FILE" ]; then
    local backup="${SETTINGS_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    cp -f "$SETTINGS_FILE" "$backup"
    info "Settings backup: $(echo "$backup" | sed "s|$HOME|~|")"
  fi

  info "Registering hook in settings.json..."
  register_hook

  echo "$VERSION" > "$VERSION_FILE"

  success "Installed $installed_count skills"
}

write_hook_script() {
  cat > "$HOOK_SCRIPT" << 'HOOKEOF'
#!/usr/bin/env bash
# beads-superpowers SessionStart hook (installed by install.sh)
set -euo pipefail

SKILL_CONTENT=""
for dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  if [ -f "$dir/using-superpowers/SKILL.md" ]; then
    SKILL_CONTENT=$(cat "$dir/using-superpowers/SKILL.md" 2>/dev/null || true)
    break
  fi
done

if [ -z "$SKILL_CONTENT" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"beads-superpowers: using-superpowers skill not found."}}\n'
  exit 0
fi

BEADS_CONTEXT=""
if command -v bd >/dev/null 2>&1; then
  BEADS_CONTEXT=$(bd prime 2>/dev/null || true)
fi

escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

SKILL_ESC=$(escape_json "$SKILL_CONTENT")
CONTEXT="<EXTREMELY_IMPORTANT>\\nYou have beads-superpowers.\\n\\n**Below is the full content of your 'beads-superpowers:using-superpowers' skill:**\\n\\n${SKILL_ESC}\\n</EXTREMELY_IMPORTANT>"

if [ -n "$BEADS_CONTEXT" ]; then
  BEADS_ESC=$(escape_json "$BEADS_CONTEXT")
  CONTEXT="${CONTEXT}\\n\\n<beads-context>\\n${BEADS_ESC}\\n</beads-context>"
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CONTEXT"
HOOKEOF
  chmod +x "$HOOK_SCRIPT"
}

register_hook() {
  python3 << PYEOF
import json, os

sf = "$SETTINGS_FILE"
hs = "$HOOK_SCRIPT"

if os.path.exists(sf):
    with open(sf) as f:
        settings = json.load(f)
else:
    os.makedirs(os.path.dirname(sf), exist_ok=True)
    settings = {}

hooks = settings.setdefault("hooks", {})
ss = hooks.setdefault("SessionStart", [])

if not any("beads-superpowers" in json.dumps(e) for e in ss):
    ss.append({
        "matcher": "startup|clear|compact",
        "hooks": [{"type": "command", "command": f"bash {hs}"}]
    })
    with open(sf, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\\n")
PYEOF
}

# --- Phase 4: Verify ---
do_verify() {
  local count
  count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -ge 20 ]; then
    success "Skill count: $count"
  else
    warn "Expected >= 20 skills, found $count"
  fi

  if bash "$HOOK_SCRIPT" 2>/dev/null | python3 -m json.tool > /dev/null 2>&1; then
    success "Hook produces valid JSON"
  else
    warn "Hook did not produce valid JSON — check $HOOK_SCRIPT"
  fi

  if [ -f "$SETTINGS_FILE" ] && python3 -c "
import json; d=json.load(open('$SETTINGS_FILE'))
assert any('beads-superpowers' in json.dumps(e) for e in d.get('hooks',{}).get('SessionStart',[]))
" 2>/dev/null; then
    success "Hook registered in settings.json"
  else
    warn "Hook not found in settings.json"
  fi
}

# --- Phase 5: Next Steps ---
print_next_steps() {
  local count
  count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo
  success "beads-superpowers v$VERSION installed ($count skills, hook configured)"
  echo
  echo "Next steps:"
  echo "  1. Restart Claude Code (or start a new session) to activate skills"
  echo "  2. Run /skills to verify — you should see 20+ skills available"
  if [ "$HAS_BEADS" = false ]; then
    echo
    echo "  3. Install beads for persistent task tracking:"
    echo "       brew install beads          # macOS (Homebrew)"
    echo "       npm install -g @beads/bd   # any platform (npm)"
    echo "  4. In each project: bd init"
  fi
  echo
}

# --- Uninstall ---
do_uninstall() {
  info "Uninstalling beads-superpowers..."

  local removed=0
  for skill in "${KNOWN_SKILLS[@]}"; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      rm -rf "${SKILLS_DIR:?}/$skill"
      removed=$((removed + 1))
    fi
  done
  info "Removed $removed skill directories"

  if [ -f "$HOOK_SCRIPT" ]; then
    rm -f "$HOOK_SCRIPT"
    info "Removed hook script"
  fi

  if [ -f "$SETTINGS_FILE" ]; then
    cp -f "$SETTINGS_FILE" "${SETTINGS_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    python3 << PYEOF
import json
sf = "$SETTINGS_FILE"
with open(sf) as f:
    settings = json.load(f)
ss = settings.get("hooks", {}).get("SessionStart", [])
settings["hooks"]["SessionStart"] = [e for e in ss if "beads-superpowers" not in json.dumps(e)]
with open(sf, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\\n")
PYEOF
    info "Removed hook from settings.json"
  fi

  rm -f "$VERSION_FILE"
  success "beads-superpowers uninstalled"
}

# --- Dry Run ---
print_dry_run() {
  echo
  printf "${BOLD}beads-superpowers v%s installer (dry run)${NC}\n" "$VERSION"
  echo
  echo "Would perform these actions:"
  echo "  1. Download release tarball from GitHub"
  echo "  2. Copy 20 skills to $SKILLS_DIR/"
  echo "  3. Create hook script at $HOOK_SCRIPT"
  echo "  4. Backup $SETTINGS_FILE"
  echo "  5. Register SessionStart hook in settings.json"
  echo "  6. Write version marker to $VERSION_FILE"
  echo
  echo "No files were modified."
}

# --- Main ---
main() {
  parse_flags "$@"
  check_prerequisites
  detect_upstream_conflict
  resolve_version
  detect_existing_install
  detect_beads

  if [ "$FLAG_UNINSTALL" = true ]; then
    do_uninstall
    exit 0
  fi

  if [ "$FLAG_DRY_RUN" = true ]; then
    print_dry_run
    exit 0
  fi

  print_consent
  wait_for_consent
  do_install
  do_verify
  print_next_steps
}

main "$@"
```

- [ ] **Step 1.3: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 1.4: Verify line count**

```bash
wc -l install.sh
```
Expected: between 280 and 350 lines.

- [ ] **Step 1.5: Commit**

```bash
git add install.sh
git commit -m "feat: add curl-based one-command installer (bd-alt)"
```

---

## Task 2: Static analysis + basic flag tests

**Files:**
- (No files modified — testing only)

- [ ] **Step 2.1: Run shellcheck**

```bash
shellcheck install.sh 2>&1 | head -30
```
Expected: either 0 issues or only SC2059 (printf format string warnings from color codes — documented exception).

Fix any real issues found.

- [ ] **Step 2.2: Test --help**

```bash
bash install.sh --help
```
Expected: prints usage text including all 5 flags.

- [ ] **Step 2.3: Test --dry-run**

```bash
bash install.sh --dry-run
```
Expected: prints "Would perform these actions..." without creating any files. Verify no files were created:
```bash
test -f ~/.claude/skills/.beads-superpowers-version-test-sentinel && echo "BAD" || echo "GOOD"
```

- [ ] **Step 2.4: Test unknown flag**

```bash
bash install.sh --bogus 2>&1; echo "exit: $?"
```
Expected: prints "Unknown flag: --bogus", exits non-zero.

- [ ] **Step 2.5: Commit if fixes were needed**

```bash
git add install.sh
git commit -m "fix: shellcheck issues in install.sh (bd-alt)"
```
(Only if Step 2.1 required fixes.)

---

## Task 3: Full install + uninstall integration test

**Files:**
- (No files modified — testing in a sandboxed HOME)

- [ ] **Step 3.1: Create sandboxed test environment**

```bash
SANDBOX=$(mktemp -d)
echo "Sandbox: $SANDBOX"
```

- [ ] **Step 3.2: Test fresh install (sandboxed)**

```bash
HOME="$SANDBOX" bash install.sh --yes --version 0.4.0
```
Expected: installs 20 skills, creates hook, registers in settings.json.

Verify:
```bash
HOME="$SANDBOX" bash -c '
  echo "skills: $(find ~/.claude/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d " ")"
  echo "hook: $(test -f ~/.claude/hooks/beads-superpowers-session-start.sh && echo exists || echo missing)"
  echo "settings: $(test -f ~/.claude/settings.json && echo exists || echo missing)"
  echo "version: $(cat ~/.claude/skills/.beads-superpowers-version 2>/dev/null || echo missing)"
  echo "hook json valid: $(bash ~/.claude/hooks/beads-superpowers-session-start.sh 2>/dev/null | python3 -m json.tool > /dev/null 2>&1 && echo yes || echo no)"
'
```
Expected: skills=20, hook=exists, settings=exists, version=0.4.0, hook json valid=yes.

- [ ] **Step 3.3: Test idempotency (same version re-run)**

```bash
HOME="$SANDBOX" bash install.sh --yes --version 0.4.0
```
Expected: prints "beads-superpowers v0.4.0 is already installed." and exits 0.

- [ ] **Step 3.4: Test custom skill protection**

```bash
HOME="$SANDBOX" bash -c 'mkdir -p ~/.claude/skills/my-custom-skill && echo "custom" > ~/.claude/skills/my-custom-skill/SKILL.md'
HOME="$SANDBOX" bash install.sh --yes --version 0.4.0
# Force upgrade by bumping version marker
HOME="$SANDBOX" bash -c 'echo "0.3.0" > ~/.claude/skills/.beads-superpowers-version'
HOME="$SANDBOX" bash install.sh --yes --version 0.4.0
HOME="$SANDBOX" bash -c 'cat ~/.claude/skills/my-custom-skill/SKILL.md'
```
Expected: prints "custom" — the custom skill survived the upgrade.

- [ ] **Step 3.5: Test --uninstall**

```bash
HOME="$SANDBOX" bash install.sh --uninstall
```
Expected: removes 20 skill dirs + hook + settings entry. Then verify:
```bash
HOME="$SANDBOX" bash -c '
  echo "skills: $(find ~/.claude/skills -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d " ")"
  echo "custom survived: $(test -f ~/.claude/skills/my-custom-skill/SKILL.md && echo yes || echo no)"
  echo "hook: $(test -f ~/.claude/hooks/beads-superpowers-session-start.sh && echo exists || echo removed)"
  echo "version: $(test -f ~/.claude/skills/.beads-superpowers-version && echo exists || echo removed)"
'
```
Expected: skills=1 (only my-custom-skill), custom survived=yes, hook=removed, version=removed.

- [ ] **Step 3.6: Cleanup sandbox**

```bash
rm -rf "$SANDBOX"
```

---

## Task 4: Update README.md

**Files:**
- Modify: `README.md` ("Try it in 60 seconds" section)

- [ ] **Step 4.1: Add curl install option**

After the existing "Option B: npx" section and before the "After installing" paragraph, insert:

```markdown
### Option C: curl (one command, no dependencies)

```bash
curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
```

Installs 20 skills to `~/.claude/skills/` and configures the SessionStart hook automatically. Supports `--yes` (CI mode), `--version X.Y.Z`, `--dry-run`, and `--uninstall`. See [install.sh](install.sh) for details.
```

- [ ] **Step 4.2: Verify markdownlint**

```bash
npm exec -- markdownlint-cli2 'README.md' 2>&1 | tail -3
```
Expected: 0 errors.

- [ ] **Step 4.3: Commit**

```bash
git add README.md
git commit -m "docs: add curl install path to README (bd-alt)"
```

---

## Task 5: Update CHANGELOG.md

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 5.1: Add entry under [Unreleased]**

Add this bullet at the top of the `[Unreleased]` section (or create `### Added` under `[Unreleased]` if not present):

```markdown
- `install.sh` — curl-pipe-bash one-command installer. Downloads skills, configures SessionStart hook, and registers in settings.json in one step. Replaces the 7-step npx + setup-skill flow. Supports `--yes`, `--version`, `--dry-run`, and `--uninstall`.
```

- [ ] **Step 5.2: Verify markdownlint**

```bash
npm exec -- markdownlint-cli2 'CHANGELOG.md' 2>&1 | tail -3
```
Expected: 0 errors.

- [ ] **Step 5.3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add install.sh to CHANGELOG [Unreleased] (bd-alt)"
```

---

## Self-Review Checklist

- [ ] `install.sh` exists at repo root, 280-350 lines
- [ ] `shellcheck install.sh` passes (or has documented exceptions)
- [ ] `bash install.sh --help` prints usage
- [ ] `bash install.sh --dry-run` prints plan without writing files
- [ ] Full install in sandbox creates 20 skills + hook + settings entry
- [ ] Same-version re-run exits 0 with "already installed"
- [ ] Custom skills survive install and uninstall
- [ ] `--uninstall` removes only beads-superpowers artifacts
- [ ] README documents the curl install path
- [ ] CHANGELOG has the entry
- [ ] Script is function-wrapped (`main()`) and starts with `set -euo pipefail`
- [ ] 20 known skill names match `ls -d skills/*/` in the repo

## Rollback

`bash install.sh --uninstall` removes everything. `settings.json.backup-<timestamp>` restores pre-install state.
