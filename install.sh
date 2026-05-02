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
FALLBACK_VERSION="0.4.1"
SKILLS_DIR="${BEADS_SUPERPOWERS_SKILLS_DIR:-$HOME/.claude/skills}"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
HOOK_SCRIPT="$HOOKS_DIR/beads-superpowers-session-start.sh"
REMINDER_SCRIPT="$HOOKS_DIR/beads-superpowers-reminder.sh"
VERSION_FILE="$SKILLS_DIR/.beads-superpowers-version"

KNOWN_SKILLS=(
  auditing-upstream-drift brainstorming dispatching-parallel-agents
  document-release executing-plans finishing-a-development-branch
  getting-up-to-speed project-init receiving-code-review
  requesting-code-review research-driven-development setup stress-test
  subagent-driven-development systematic-debugging test-driven-development
  using-git-worktrees using-superpowers verification-before-completion
  write-documentation writing-plans writing-skills
)

# --- Flags ---
FLAG_YES=false
FLAG_DRY_RUN=false
FLAG_UNINSTALL=false
FLAG_TEST=false
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
  --test          Install to /tmp/beads-superpowers-test/ (verifies then cleans up)
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
      --test)       FLAG_TEST=true ;;
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
    echo "  • Upgrade 22 skills in $SKILLS_DIR/"
  else
    echo "  • Download 22 skills to $SKILLS_DIR/"
  fi
  echo "  • Create SessionStart hook at $HOOK_SCRIPT"
  echo "  • Create UserPromptSubmit hook at $REMINDER_SCRIPT"
  echo "  • Register both hooks in $SETTINGS_FILE (backup created first)"
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

  info "Creating UserPromptSubmit hook..."
  write_reminder_script

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

write_reminder_script() {
  cat > "$REMINDER_SCRIPT" << 'REMINDEREOF'
#!/usr/bin/env bash
# beads-superpowers UserPromptSubmit hook (installed by install.sh)
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
REMINDEREOF
  chmod +x "$REMINDER_SCRIPT"
}

register_hook() {
  python3 << PYEOF
import json, os

sf = "$SETTINGS_FILE"
hs = "$HOOK_SCRIPT"
rs = "$REMINDER_SCRIPT"

if os.path.exists(sf):
    with open(sf) as f:
        settings = json.load(f)
else:
    os.makedirs(os.path.dirname(sf), exist_ok=True)
    settings = {}

hooks = settings.setdefault("hooks", {})

# SessionStart hook
ss = hooks.setdefault("SessionStart", [])
if not any("beads-superpowers" in json.dumps(e) for e in ss):
    ss.append({
        "matcher": "startup|clear|compact",
        "hooks": [{"type": "command", "command": f"bash {hs}"}]
    })

# UserPromptSubmit hook
ups = hooks.setdefault("UserPromptSubmit", [])
if not any("beads-superpowers" in json.dumps(e) for e in ups):
    ups.append({
        "matcher": "",
        "hooks": [{"type": "command", "command": f"bash {rs}"}]
    })

with open(sf, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
}

# --- Phase 4: Verify ---
do_verify() {
  local count
  count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -ge 21 ]; then
    success "Skill count: $count"
  else
    warn "Expected >= 22 skills, found $count"
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
  echo "  2. Run /skills to verify — you should see 22+ skills available"
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
    info "Removed SessionStart hook script"
  fi

  if [ -f "$REMINDER_SCRIPT" ]; then
    rm -f "$REMINDER_SCRIPT"
    info "Removed UserPromptSubmit hook script"
  fi

  if [ -f "$SETTINGS_FILE" ]; then
    cp -f "$SETTINGS_FILE" "${SETTINGS_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    python3 << PYEOF
import json
sf = "$SETTINGS_FILE"
with open(sf) as f:
    settings = json.load(f)
hooks = settings.get("hooks", {})
for key in ["SessionStart", "UserPromptSubmit"]:
    if key in hooks:
        hooks[key] = [e for e in hooks[key] if "beads-superpowers" not in json.dumps(e)]
with open(sf, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
    info "Removed hooks from settings.json"
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
  echo "  2. Copy 22 skills to $SKILLS_DIR/"
  echo "  3. Create hook script at $HOOK_SCRIPT"
  echo "  4. Backup $SETTINGS_FILE"
  echo "  5. Register SessionStart hook in settings.json"
  echo "  6. Write version marker to $VERSION_FILE"
  echo
  echo "No files were modified."
}

# --- Test Mode ---
do_test() {
  local test_home="/tmp/beads-superpowers-test"
  rm -rf "$test_home"

  info "Test mode: installing to $test_home/"
  echo

  # Re-run ourselves with overridden HOME and --yes
  BEADS_SUPERPOWERS_SKILLS_DIR="$test_home/skills" HOME="$test_home" bash "$0" --yes

  echo
  info "Running verification checks..."
  local pass=0 fail=0

  # Check skill count
  local count
  count=$(find "$test_home/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -ge 20 ]; then
    success "Skills installed: $count"; pass=$((pass + 1))
  else
    error "Skills installed: $count (expected >= 20)"; fail=$((fail + 1))
  fi

  # Check SessionStart hook
  if bash "$test_home/.claude/hooks/beads-superpowers-session-start.sh" 2>/dev/null | python3 -m json.tool > /dev/null 2>&1; then
    success "SessionStart hook: valid JSON"; pass=$((pass + 1))
  else
    error "SessionStart hook: invalid JSON"; fail=$((fail + 1))
  fi

  # Check UserPromptSubmit hook
  if bash "$test_home/.claude/hooks/beads-superpowers-reminder.sh" 2>/dev/null | python3 -m json.tool > /dev/null 2>&1; then
    success "UserPromptSubmit hook: valid JSON"; pass=$((pass + 1))
  else
    error "UserPromptSubmit hook: invalid JSON"; fail=$((fail + 1))
  fi

  # Check settings.json
  if python3 -c "
import json
d=json.load(open('$test_home/.claude/settings.json'))
assert d['hooks']['SessionStart']
assert d['hooks']['UserPromptSubmit']
" 2>/dev/null; then
    success "settings.json: both hooks registered"; pass=$((pass + 1))
  else
    error "settings.json: hooks missing"; fail=$((fail + 1))
  fi

  # Test uninstall
  BEADS_SUPERPOWERS_SKILLS_DIR="$test_home/skills" HOME="$test_home" bash "$0" --uninstall 2>&1

  if [ ! -f "$test_home/.claude/hooks/beads-superpowers-session-start.sh" ] && \
     [ ! -f "$test_home/.claude/hooks/beads-superpowers-reminder.sh" ]; then
    success "Uninstall: hooks removed"; pass=$((pass + 1))
  else
    error "Uninstall: hooks still exist"; fail=$((fail + 1))
  fi

  # Cleanup
  rm -rf "$test_home"

  echo
  if [ "$fail" -eq 0 ]; then
    success "All $pass checks passed"
  else
    error "$fail checks failed, $pass passed"
    exit 1
  fi
}

# --- Main ---
main() {
  parse_flags "$@"
  check_prerequisites

  # Handle test mode — runs install + verify + uninstall in temp dir
  if [ "$FLAG_TEST" = true ]; then
    do_test
    exit 0
  fi

  # Handle uninstall early — before version resolution or existing-install detection
  if [ "$FLAG_UNINSTALL" = true ]; then
    do_uninstall
    exit 0
  fi

  detect_upstream_conflict
  resolve_version

  # Handle dry-run before existing-install detection (which may exit 0)
  if [ "$FLAG_DRY_RUN" = true ]; then
    print_dry_run
    exit 0
  fi

  detect_existing_install
  detect_beads

  print_consent
  wait_for_consent
  do_install
  do_verify
  print_next_steps
}

main "$@"
