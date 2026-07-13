#!/usr/bin/env bash
# beads-superpowers installer (scripted / advanced install)
# https://github.com/DollarDill/beads-superpowers
#
# Preferred install for Claude Code / Codex: use the native plugin system.
# For OpenCode: git-install via opencode.json — see .opencode/INSTALL.md.
# Use this script for: beads/Dolt bootstrap, npx/scripted hook registration,
# optional yegge.md agent install (--with-yegge), version pinning (--version), or CI automation.
#
# Scripted usage:
#   curl -fsSL https://raw.githubusercontent.com/DollarDill/beads-superpowers/main/install.sh | bash
#   curl -fsSL <url> | bash -s -- --yes            # CI / non-interactive
#   curl -fsSL <url> | bash -s -- --version 0.4.0  # Pin version
#   curl -fsSL <url> | bash -s -- --dry-run         # Preview
#   curl -fsSL <url> | bash -s -- --uninstall       # Remove

# shellcheck disable=SC2034  # detection/flag vars consumed by later install tiers
set -euo pipefail

# --- Configuration ---
REPO="DollarDill/beads-superpowers"
FALLBACK_VERSION="0.5.3"
SKILLS_DIR="${BEADS_SUPERPOWERS_SKILLS_DIR:-$HOME/.claude/skills}"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
HOOK_SCRIPT="$HOOKS_DIR/beads-superpowers-session-start.sh"
AGENTS_DIR="$HOME/.claude/agents"
VERSION_FILE="$SKILLS_DIR/.beads-superpowers-version"

KNOWN_SKILLS=(
  brainstorming dispatching-parallel-agents
  document-release executing-plans finishing-a-development-branch
  getting-up-to-speed memory-curator project-init
  receiving-code-review requesting-code-review research-driven-development
  session-handoff stress-test subagent-driven-development
  systematic-debugging test-driven-development using-git-worktrees
  using-superpowers verification-before-completion write-documentation
  writing-plans
)

# Skills shipped by past releases but no longer distributed (ADR-0044).
# Removed on upgrade/uninstall ONLY — never on fresh install (evidence gate:
# we only delete from roots a prior beads-superpowers install owned).
LEGACY_SKILLS=(auditing-upstream-drift writing-skills tracking-with-beads)

KNOWN_AGENTS=(yegge)

# --- Flags ---
FLAG_YES=false
FLAG_DRY_RUN=false
FLAG_UNINSTALL=false
FLAG_TEST=false
FLAG_WITH_YEGGE=false
FLAG_VERSION=""
FLAG_SOURCE=""
# shellcheck disable=SC2034  # FLAG_SKIP_CHECKSUM used in later install tiers
FLAG_SKIP_CHECKSUM=false
UPGRADING=false
# shellcheck disable=SC2034  # PREVIOUS_TIER used in later install tiers
PREVIOUS_TIER=""
HAS_BEADS=false
HAS_CLAUDE=0
HAS_CODEX=0
HAS_OPENCODE=0
HAS_NPX=0
HAS_GIT=0
HAS_CURL=0
HAS_WGET=0
HAS_PYTHON3=0
# shellcheck disable=SC2034  # INSTALL_TIER used in later install tiers
INSTALL_TIER=""
# shellcheck disable=SC2034  # STAGING_DIR used in later install tiers
STAGING_DIR=""
VERSION=""
agent_count=0

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

# --- Checksum ---
compute_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    echo ""
  fi
}

verify_checksum() {
  local tarball="$1" checksums_url="$2"

  if [ "$FLAG_SKIP_CHECKSUM" = true ]; then
    info "Checksum verification skipped (--skip-checksum)"
    return 0
  fi

  local checksums_file
  checksums_file=$(mktemp)

  # Download checksums.txt
  if ! curl -fsSL "$checksums_url" -o "$checksums_file" 2>/dev/null; then
    warn "No checksums.txt found for this release — skipping verification"
    rm -f "$checksums_file"
    return 0
  fi

  # One tarball per release — read first hash (don't match by filename,
  # which differs between GitHub's name and our local download name)
  local expected_hash actual_hash
  expected_hash=$(awk '{print $1; exit}' "$checksums_file")
  rm -f "$checksums_file"

  if [ -z "$expected_hash" ]; then
    warn "Empty checksums.txt — skipping verification"
    return 0
  fi

  # Compute actual hash
  actual_hash=$(compute_sha256 "$tarball")

  if [ -z "$actual_hash" ]; then
    warn "No SHA-256 tool available (tried sha256sum, shasum, openssl) — skipping verification"
    return 0
  fi

  if [ "$expected_hash" != "$actual_hash" ]; then
    error "Checksum mismatch — tarball may be corrupted or tampered with."
    echo "  Expected: $expected_hash"
    echo "  Got:      $actual_hash"
    echo "  Use --skip-checksum to bypass this check."
    return 1
  fi

  success "Checksum verified (SHA-256)"
  return 0
}

# --- Staging helpers ---
create_staging() {
  # Clean up any previous staging dir (prevents leak when tiers cascade)
  [ -n "${STAGING_DIR:-}" ] && rm -rf "$STAGING_DIR"
  STAGING_DIR=$(mktemp -d)
  trap 'rm -rf "${STAGING_DIR:-}"' EXIT
}

# Move staged skills to final destinations. Primary target (Claude Code) is required;
# secondary target (Codex) warns on failure. OpenCode is git-install only (see
# .opencode/INSTALL.md) — this just prints a pointer.
promote_staging() {
  local source_skills="$1"
  local count=0

  mkdir -p "$SKILLS_DIR"
  for skill in "${KNOWN_SKILLS[@]}"; do
    if [ -d "$source_skills/$skill" ]; then
      rm -rf "${SKILLS_DIR:?}/$skill"
      mv -f "$source_skills/$skill" "$SKILLS_DIR/$skill"
      count=$((count + 1))
    fi
  done

  if [ "$count" -lt 20 ]; then
    warn "Only $count skills found (expected 21)"
    return 1
  fi

  # Secondary CLIs — warn on failure, don't rollback primary
  if [ "$HAS_CODEX" = 1 ]; then
    install_codex_from "$SKILLS_DIR" || warn "Codex skill install failed — Claude Code install succeeded"
  fi
  if [ "$HAS_OPENCODE" = 1 ]; then
    info "OpenCode detected — install via the git plugin spec in opencode.json (see .opencode/INSTALL.md); this script no longer copies OpenCode artifacts."
  fi

  success "Installed $count skills"
  return 0
}

usage() {
  cat <<'USAGE'
beads-superpowers — scripted / advanced installer

Preferred install for Tier-1 CLIs:
  Claude Code:  claude plugin marketplace add DollarDill/beads-superpowers
  Codex:        codex plugin marketplace add DollarDill/beads-superpowers
  OpenCode:     see .opencode/INSTALL.md (git plugin spec)

Use this script when you need:
  - beads/Dolt bootstrap and hook registration outside the plugin system
  - npx/scripted install path with SessionStart hook wiring
  - optional yegge.md orchestrator agent install (opt-in via --with-yegge)
  - version pinning (--version) or CI automation

Usage:
  curl -fsSL <url> | bash
  curl -fsSL <url> | bash -s -- [flags]

Flags:
  --yes, -y       Skip consent prompt (CI mode)
  --dry-run       Print what would happen without doing it
  --test          Install to /tmp/beads-superpowers-test/ (verifies then cleans up)
  --with-yegge    Also install the yegge.md orchestrator agent (default: not installed;
                  forces the tarball/git install tier — plugin/npx tiers are skipped)
  --uninstall     Remove beads-superpowers skills, hook, and settings entry
  --version X.Y.Z Pin to a specific version (default: latest GitHub release)
  --source DIR    Install from a local checkout (dev/test; bypasses download tiers, no network)
  --skip-checksum   Skip SHA-256 checksum verification (tarball downloads)
  --help, -h      Show this help

Environment:
  BEADS_SUPERPOWERS_SKILLS_DIR  Override skills install location (default: ~/.claude/skills)
USAGE
}

parse_flags() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y)          FLAG_YES=true ;;
      --dry-run)         FLAG_DRY_RUN=true ;;
      --test)            FLAG_TEST=true ;;
      --with-yegge)      FLAG_WITH_YEGGE=true ;;
      --uninstall)       FLAG_UNINSTALL=true ;;
      --version)         shift; FLAG_VERSION="${1:-}"; [ -z "$FLAG_VERSION" ] && { error "--version requires a value"; exit 1; } ;;
      --source)          shift; FLAG_SOURCE="${1:-}"; [ -z "$FLAG_SOURCE" ] && { error "--source requires a directory"; exit 1; } ;;
      --skip-checksum)   FLAG_SKIP_CHECKSUM=true ;;
      --help|-h)         usage; exit 0 ;;
      *)                 error "Unknown flag: $1"; usage; exit 1 ;;
    esac
    shift
  done

  if [ -n "$FLAG_SOURCE" ] && [ "$FLAG_TEST" = true ]; then
    error "--source and --test are mutually exclusive (use the install-shape suite for local testing)"
    exit 1
  fi
}

# --- Phase 1: Checks ---
# shellcheck disable=SC2034  # vars are consumed by later install tiers
detect_tools() {
  command -v claude   >/dev/null 2>&1 && HAS_CLAUDE=1
  command -v codex    >/dev/null 2>&1 && HAS_CODEX=1
  command -v opencode >/dev/null 2>&1 && HAS_OPENCODE=1
  command -v npx      >/dev/null 2>&1 && HAS_NPX=1
  command -v git      >/dev/null 2>&1 && HAS_GIT=1
  command -v curl     >/dev/null 2>&1 && HAS_CURL=1
  command -v wget     >/dev/null 2>&1 && HAS_WGET=1
  command -v python3  >/dev/null 2>&1 && HAS_PYTHON3=1
  command -v bd       >/dev/null 2>&1 && HAS_BEADS=true
  command -v cursor-agent >/dev/null 2>&1 && HAS_CURSOR=1 || HAS_CURSOR=0
  command -v copilot      >/dev/null 2>&1 && HAS_COPILOT=1 || HAS_COPILOT=0
  command -v droid        >/dev/null 2>&1 && HAS_DROID=1 || HAS_DROID=0
  command -v agy          >/dev/null 2>&1 && HAS_AGY=1 || HAS_AGY=0
  command -v kimi         >/dev/null 2>&1 && HAS_KIMI=1 || HAS_KIMI=0
  command -v pi           >/dev/null 2>&1 && HAS_PI=1 || HAS_PI=0
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
  if [ -n "$FLAG_SOURCE" ]; then
    VERSION=$(grep -m1 '"version"' "$FLAG_SOURCE/package.json" 2>/dev/null | sed -E 's/.*"([0-9][^"]*)".*/\1/')
    [ -z "$VERSION" ] && { error "--source: cannot read version from $FLAG_SOURCE/package.json"; exit 1; }
    info "Version $VERSION (from --source checkout)"
    return 0
  fi
  if [ -n "$FLAG_VERSION" ]; then
    VERSION="$FLAG_VERSION"
    return
  fi
  if [ "$HAS_CURL" = 1 ]; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/') || true
  fi
  if [ -z "$VERSION" ]; then
    warn "Could not fetch latest version from GitHub API. Using fallback: v$FALLBACK_VERSION"
    VERSION="$FALLBACK_VERSION"
  fi
}

detect_existing_install() {
  if [ -f "$VERSION_FILE" ]; then
    local installed installed_version installed_tier
    installed=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    installed_version="${installed%%:*}"
    installed_tier="${installed#*:}"
    # If no colon separator, legacy format — treat as tarball tier
    if [ "$installed_version" = "$installed_tier" ]; then
      installed_tier="tarball"
    fi
    if [ "$installed_version" = "$VERSION" ] && [ -z "$INSTALL_TIER" ]; then
      success "beads-superpowers v$VERSION is already installed (via $installed_tier)."
      exit 0
    fi
    if [ "$installed_version" != "$VERSION" ]; then
      info "Upgrading beads-superpowers: v$installed_version → v$VERSION"
    else
      info "Reinstalling beads-superpowers v$VERSION (tier change: $installed_tier → new)"
    fi
    UPGRADING=true
    # shellcheck disable=SC2034  # PREVIOUS_TIER used in later install tiers
    PREVIOUS_TIER="$installed_tier"
  fi
}


# --- Phase 2: Consent ---
print_consent() {
  echo
  printf "${BOLD}beads-superpowers v%s — scripted / advanced installer${NC}\n" "$VERSION"
  echo
  echo "This script installs the beads-superpowers skill suite via the best available fallback method."
  echo "(For Claude Code / Codex / OpenCode, native plugin install is preferred.)"
  if [ "$HAS_CLAUDE" = 1 ] || [ "$HAS_CODEX" = 1 ]; then
    echo "  1. Plugin system (Claude Code / Codex) — used when CLI detected"
  fi
  [ "$HAS_NPX" = 1 ] && echo "  2. npx skills add"
  echo "  3. Direct download (tarball / git clone)"
  echo
  if [ "$HAS_CODEX" = 1 ]; then
    echo "  Codex CLI detected — skills will also be installed to ~/.codex/skills/"
  fi
  if [ "$HAS_OPENCODE" = 1 ]; then
    echo "  OpenCode detected — install via the git plugin spec in opencode.json (see .opencode/INSTALL.md)"
  fi
  echo
}

wait_for_consent() {
  if [ "$FLAG_YES" = true ] || [ ! -t 0 ]; then
    return
  fi
  printf "Press Enter to continue (or Ctrl+C to cancel)... "
  read -r
}


# ADR-0044: purge previously shipped, no-longer-distributed skills from all
# three skill roots. Callers enforce the evidence gate (upgrade or uninstall).
cleanup_legacy_skills() {
  local removed=0 skill dir
  for skill in "${LEGACY_SKILLS[@]}"; do
    for dir in "$SKILLS_DIR" "$HOME/.codex/skills" "$HOME/.config/opencode/skills"; do
      if [ -d "$dir/$skill" ]; then
        rm -rf "${dir:?}/${skill:?}"
        removed=$((removed + 1))
      fi
    done
  done
  [ "$removed" -gt 0 ] && success "Removed $removed legacy skill dir(s) (no longer distributed)"
  return 0
}

uninstall_codex_support() {
  local codex_skills="$HOME/.codex/skills"
  local removed=0
  for skill in "${KNOWN_SKILLS[@]}"; do
    if [ -d "$codex_skills/$skill" ]; then
      rm -rf "${codex_skills:?}/$skill"
      removed=$((removed + 1))
    fi
  done
  if [ $removed -gt 0 ]; then
    success "Codex: removed $removed skills from $codex_skills/"
  fi
}

# Legacy copy-mode cleanup (pre-0.12) — OpenCode is git-install only as of 0.12
# (see .opencode/INSTALL.md); this removes artifacts a prior install.sh copied.
uninstall_opencode_support() {
  local oc_skills="$HOME/.config/opencode/skills"
  local removed=0
  for skill in "${KNOWN_SKILLS[@]}"; do
    if [ -d "$oc_skills/$skill" ]; then
      rm -rf "${oc_skills:?}/$skill"
      removed=$((removed + 1))
    fi
  done
  if [ $removed -gt 0 ]; then
    success "OpenCode: removed $removed skills from $oc_skills/"
  fi

  local oc_plugin="$HOME/.config/opencode/plugins/beads-superpowers-plugin.ts"
  if [ -f "$oc_plugin" ]; then
    rm -f "$oc_plugin"
    success "OpenCode: removed plugin"
  fi

  local oc_hook="$HOME/.config/opencode/hooks/session-start"
  if [ -f "$oc_hook" ]; then
    rm -f "$oc_hook"
    success "OpenCode: removed canonical hook"
  fi
}

install_codex_from() {
  local source_dir="$1"
  local codex_skills="$HOME/.codex/skills"
  mkdir -p "$codex_skills"
  local installed=0
  for skill in "${KNOWN_SKILLS[@]}"; do
    if [ -d "$source_dir/$skill" ]; then
      cp -rf "$source_dir/$skill" "$codex_skills/$skill"
      installed=$((installed + 1))
    fi
  done
  success "Codex: installed $installed skills to $codex_skills/"
}

# Optional agent install — opt-in via --with-yegge (default: not installed).
install_agents_from() {
  local source_root="$1" agent
  [ "$FLAG_WITH_YEGGE" = true ] || return 0
  mkdir -p "$AGENTS_DIR"
  for agent in "${KNOWN_AGENTS[@]}"; do
    if [ -f "$source_root/example-workflow/agents/$agent.md" ]; then
      cp -f "$source_root/example-workflow/agents/$agent.md" "$AGENTS_DIR/$agent.md"
    fi
  done
}

setup_hooks() {
  local source_root="${1:-}"
  if [ "$HAS_PYTHON3" = 0 ]; then
    warn "python3 not found — cannot register hooks in settings.json"
    warn "Re-run install.sh once python3 is available to configure hooks"
    return 1
  fi

  mkdir -p "$HOOKS_DIR"

  info "Creating SessionStart hook..."
  write_hook_script "$source_root"

  if [ -f "$SETTINGS_FILE" ]; then
    local backup
    backup="${SETTINGS_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    cp -f "$SETTINGS_FILE" "$backup"
    info "Settings backup: ${backup/$HOME/\~}"
  fi

  cleanup_stale_reminder "$SETTINGS_FILE"

  info "Registering hooks in settings.json..."
  register_hook

  return 0
}

try_local_install() {
  [ -z "$FLAG_SOURCE" ] && return 1
  [ -d "$FLAG_SOURCE/skills" ] || { error "--source: $FLAG_SOURCE/skills not found"; exit 1; }

  info "Tier 0: Installing from local source: $FLAG_SOURCE"
  create_staging

  mkdir -p "$STAGING_DIR/repo"
  cp -rf "$FLAG_SOURCE/skills" "$STAGING_DIR/repo/skills"
  [ -d "$FLAG_SOURCE/example-workflow" ] && cp -rf "$FLAG_SOURCE/example-workflow" "$STAGING_DIR/repo/example-workflow"
  [ -d "$FLAG_SOURCE/hooks" ] && cp -rf "$FLAG_SOURCE/hooks" "$STAGING_DIR/repo/hooks"

  if ! promote_staging "$STAGING_DIR/repo/skills"; then
    return 1
  fi

  install_agents_from "$STAGING_DIR/repo"

  setup_hooks "$STAGING_DIR/repo" || warn "Hook setup failed — re-run install.sh once python3 is available"

  INSTALL_TIER="local"
  return 0
}

try_plugin_install() {
  # Skip if --version was specified (can't pin versions via plugin system)
  [ -n "$FLAG_VERSION" ] && return 1
  # Skip if --with-yegge: plugin tier has no checkout to copy the agent from
  [ "$FLAG_WITH_YEGGE" = true ] && return 1

  local installed=false

  if [ "$HAS_CLAUDE" = 1 ]; then
    info "Tier 1: Trying Claude Code plugin install..."
    if claude plugin marketplace add DollarDill/beads-superpowers 2>/dev/null && \
       claude plugin install beads-superpowers@beads-superpowers-marketplace 2>/dev/null; then
      installed=true
      success "Claude Code: plugin installed via marketplace"
    else
      warn "Claude Code plugin install failed — trying next method"
    fi
  fi

  if [ "$HAS_CODEX" = 1 ]; then
    info "Tier 1: Trying Codex plugin install..."
    if codex plugin marketplace add DollarDill/beads-superpowers 2>/dev/null && \
       codex plugin install beads-superpowers@beads-superpowers-marketplace 2>/dev/null; then
      installed=true
      success "Codex: plugin installed via marketplace"
    else
      warn "Codex plugin install failed — trying next method"
    fi
  fi

  if [ "$installed" = true ]; then
    INSTALL_TIER="plugin"
    return 0
  fi
  return 1
}

try_npx_install() {
  [ "$HAS_NPX" = 0 ] && return 1
  # Skip if --version was specified (can't pin versions via npx)
  [ -n "$FLAG_VERSION" ] && return 1
  # Skip if --with-yegge: npx tier has no checkout to copy the agent from
  [ "$FLAG_WITH_YEGGE" = true ] && return 1

  info "Tier 2: Trying npx skills install..."

  local agents="-a claude-code"  # always target claude-code
  [ "$HAS_CODEX" = 1 ] && agents="$agents -a codex"

  # shellcheck disable=SC2086  # word splitting intentional: $agents expands to multiple -a flags
  if npx skills add DollarDill/beads-superpowers $agents -g --copy -y 2>/dev/null; then
    success "Skills installed via npx"

    # npx doesn't install hooks — do it ourselves
    setup_hooks || warn "Hook setup failed after npx install — re-run install.sh once python3 is available"

    INSTALL_TIER="npx"
    return 0
  fi

  warn "npx skills install failed — trying next method"
  return 1
}

try_tarball_install() {
  [ "$HAS_CURL" = 0 ] && return 1

  info "Tier 3: Trying tarball download..."

  create_staging

  local tarball_url="${BEADS_SUPERPOWERS_TARBALL_URL:-https://github.com/$REPO/archive/refs/tags/v${VERSION}.tar.gz}"
  local checksums_url="${BEADS_SUPERPOWERS_CHECKSUMS_URL:-https://github.com/$REPO/releases/download/v${VERSION}/checksums.txt}"

  if ! curl -fsSL "$tarball_url" -o "$STAGING_DIR/release.tar.gz"; then
    warn "Tarball download failed — trying next method"
    return 1
  fi

  # Checksum verification
  if ! verify_checksum "$STAGING_DIR/release.tar.gz" "$checksums_url"; then
    return 1
  fi

  info "Extracting..."
  mkdir -p "$STAGING_DIR/extracted"
  if ! tar xzf "$STAGING_DIR/release.tar.gz" --strip-components=1 -C "$STAGING_DIR/extracted"; then
    warn "Tarball extraction failed — trying next method"
    return 1
  fi

  if ! promote_staging "$STAGING_DIR/extracted/skills"; then
    return 1
  fi

  install_agents_from "$STAGING_DIR/extracted"

  setup_hooks "$STAGING_DIR/extracted" || warn "Hook setup failed — re-run install.sh once python3 is available"

  INSTALL_TIER="tarball"
  return 0
}

try_git_install() {
  [ "$HAS_GIT" = 0 ] && return 1

  info "Tier 3b: Trying git clone..."

  create_staging

  if ! git clone --depth 1 "https://github.com/$REPO.git" "$STAGING_DIR/repo" 2>/dev/null; then
    warn "Git clone failed"
    return 1
  fi

  if ! promote_staging "$STAGING_DIR/repo/skills"; then
    return 1
  fi

  install_agents_from "$STAGING_DIR/repo"

  setup_hooks "$STAGING_DIR/repo" || warn "Hook setup failed — re-run install.sh once python3 is available"

  INSTALL_TIER="git"
  return 0
}

all_methods_failed() {
  error "All installation methods failed."
  echo
  echo "Manual installation options:"
  echo
  echo "  Plugin (Claude Code):"
  echo "    claude plugin marketplace add DollarDill/beads-superpowers"
  echo "    claude plugin install beads-superpowers@beads-superpowers-marketplace"
  echo
  if command -v npx >/dev/null 2>&1; then
    echo "  npx:"
    echo "    npx skills add DollarDill/beads-superpowers -a claude-code -g --copy"
    echo
  fi
  echo "  Git:"
  echo "    git clone https://github.com/$REPO.git"
  echo "    cp -r beads-superpowers/skills/* ~/.claude/skills/"
  echo
  exit 1
}

# --- Phase 3: Install (tier cascade) ---
do_auto_uninstall_previous() {
  [ -z "$PREVIOUS_TIER" ] && return 0

  info "Auto-uninstalling previous install (tier: $PREVIOUS_TIER)..."
  case "$PREVIOUS_TIER" in
    plugin)
      claude plugin uninstall beads-superpowers@beads-superpowers-marketplace 2>/dev/null || true
      codex plugin uninstall beads-superpowers@beads-superpowers-marketplace 2>/dev/null || true
      ;;
    npx|tarball|git|local)
      for skill in "${KNOWN_SKILLS[@]}"; do
        rm -rf "${SKILLS_DIR:?}/$skill" 2>/dev/null
      done
      rm -f "$HOOK_SCRIPT" "$HOOKS_DIR/beads-superpowers-reminder.sh" 2>/dev/null
      rm -rf "$HOOKS_DIR/beads-superpowers" 2>/dev/null
      if [ -f "$SETTINGS_FILE" ] && [ "$HAS_PYTHON3" = 1 ]; then
        python3 -c "
import json
sf = '$SETTINGS_FILE'
with open(sf) as f:
    s = json.load(f)
h = s.get('hooks', {})
for k in ['SessionStart', 'UserPromptSubmit']:
    if k in h:
        h[k] = [e for e in h[k] if 'beads-superpowers' not in json.dumps(e)]
with open(sf, 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" 2>/dev/null || true
      fi
      ;;
  esac
  uninstall_codex_support 2>/dev/null || true
  uninstall_opencode_support 2>/dev/null || true
  success "Previous install cleaned up"
}

do_install() {
  # Auto-uninstall previous tier if switching
  do_auto_uninstall_previous

  # Tier cascade — first success wins (--source bypasses all download tiers)
  if [ -n "$FLAG_SOURCE" ]; then
    try_local_install || all_methods_failed
  else
    try_plugin_install || \
    try_npx_install || \
    try_tarball_install || \
    try_git_install || \
    all_methods_failed
  fi

  # ADR-0044: evidence-gated — only an upgrade over a prior install may purge.
  if [ "$UPGRADING" = true ]; then
    cleanup_legacy_skills
  fi

  # Write version file with tier info
  mkdir -p "$(dirname "$VERSION_FILE")"
  echo "${VERSION}:${INSTALL_TIER}" > "$VERSION_FILE"
}

# write_hook_script [source_root]
# Checkout tiers (local/tarball/git) pass a repo root: the canonical composer
# (hooks/session-start) is copied to a durable root and HOOK_SCRIPT becomes a
# thin exec shim of it — one source of truth (bead bb6x).
# The npx tier has no checkout to copy from: HOOK_SCRIPT becomes a policy-free
# minimal fallback — skill injection plus static bd pointers only. All
# composition policy (bd prime capture, memory selection) lives ONLY in
# hooks/session-start.
write_hook_script() {
  local source_root="${1:-}"

  if [ -n "$source_root" ] && [ -f "$source_root/hooks/session-start" ]; then
    local canon_root="$HOOKS_DIR/beads-superpowers"
    mkdir -p "$canon_root/hooks"
    cp -f "$source_root/hooks/session-start" "$canon_root/hooks/session-start"
    chmod +x "$canon_root/hooks/session-start"  # direct exec relies on the bash shebang
    # The canonical hook resolves skills relative to its own root
    # (<root>/skills/using-superpowers/SKILL.md) — point <root>/skills at SKILLS_DIR.
    rm -rf "$canon_root/skills"
    ln -s "$SKILLS_DIR" "$canon_root/skills"

    # Unquoted heredoc: $canon_root is substituted at install time (same
    # mechanism as register_hook's PYEOF); runtime expansions are escaped.
    cat > "$HOOK_SCRIPT" << HOOKEOF
#!/usr/bin/env bash
# beads-superpowers hook shim — canonical logic lives in hooks/session-start.
# The CLAUDE_PLUGIN_ROOT default preserves the hookSpecificOutput envelope this
# registration has always emitted (settings.json / codex_hooks consumers).
BSP_ROOT="$canon_root"
export CLAUDE_PLUGIN_ROOT="\${CLAUDE_PLUGIN_ROOT:-\$BSP_ROOT}"
exec "\$BSP_ROOT/hooks/session-start" "\$@"
HOOKEOF
  else
    cat > "$HOOK_SCRIPT" << 'HOOKEOF'
#!/usr/bin/env bash
# beads-superpowers SessionStart hook — minimal fallback (npx tier).
# npx installs skills only (no repo checkout), so the canonical
# hooks/session-start composer is not available to exec. This fallback is
# policy-free by design: skill injection plus static bd pointers — no bd prime
# capture, no memory selection. That logic lives in hooks/session-start.
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
  MEMORY_LINE=$({ bd memories 2>/dev/null || true; } | head -1)
  BEADS_CONTEXT=$(cat <<'PTR'
## Issue Tracking (bd)

This workspace uses **bd (beads)**. Core commands:
- `bd ready -n 10` — unblocked work · `bd show --short <id>` — skim an issue
- `bd create "Title" -t task -p 2` — create · `bd close <id> --reason "..."` — complete
- `bd query "status=open"` — search · `bd remember "insight"` — persist a memory
Full reference: `bd human`. If beads context was not injected this session: `bd prime`.

## Persistent Memories
PTR
)
  BEADS_CONTEXT="${BEADS_CONTEXT}
${MEMORY_LINE}
"'Search: `bd memories <keyword>` · fetch: `bd recall <key>`'
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
  fi
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

# SessionStart hook
ss = hooks.setdefault("SessionStart", [])
if not any("beads-superpowers" in json.dumps(e) for e in ss):
    ss.append({
        "matcher": "startup|clear|compact",
        "hooks": [{"type": "command", "command": f"bash {hs}"}]
    })

with open(sf, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
}

cleanup_stale_reminder() {
  # ADR-0039 migration: remove UserPromptSubmit entries whose command references
  # superpowers-reminder. Structured parser only; narrow match; backup; foreign
  # hooks preserved; skip with warning if python3 is unavailable.
  local settings="$1"
  [ -f "$settings" ] || return 0
  grep -q "superpowers-reminder" "$settings" 2>/dev/null || return 0
  if [ "$HAS_PYTHON3" = 0 ]; then
    warn "python3 not found — cannot clean the stale UserPromptSubmit hook"
    warn "Manual fix: remove the UserPromptSubmit entry referencing superpowers-reminder.sh from $settings"
    return 0
  fi
  cp -f "$settings" "${settings}.bak-$(date +%Y%m%d-%H%M%S)"
  python3 - "$settings" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
hooks = data.get("hooks", {})
ups = hooks.get("UserPromptSubmit")
if isinstance(ups, list):
    kept_matchers = []
    for entry in ups:
        inner = [h for h in entry.get("hooks", [])
                 if "superpowers-reminder" not in h.get("command", "")]
        if inner:
            entry["hooks"] = inner
            kept_matchers.append(entry)
    if kept_matchers:
        hooks["UserPromptSubmit"] = kept_matchers
    else:
        hooks.pop("UserPromptSubmit", None)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PYEOF
  success "Removed stale UserPromptSubmit (superpowers-reminder) entry from ${settings/$HOME/\~}"
}

# --- Phase 4: Verify ---
do_verify() {
  local count md
  count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  md=$(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ] && [ "$count" = "$md" ]; then
    success "Skill count: $count"
  else
    warn "Skill dir/SKILL.md mismatch: $count dirs vs $md SKILL.md files"
  fi

  # Hook checks only for non-plugin tiers (plugin manages its own hooks)
  if [ "$INSTALL_TIER" != "plugin" ]; then
    if [ -f "$HOOK_SCRIPT" ] && bash "$HOOK_SCRIPT" 2>/dev/null | python3 -m json.tool > /dev/null 2>&1; then
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
  fi

  if [ -f "$VERSION_FILE" ]; then
    success "Version file: $(cat "$VERSION_FILE")"
  fi
}

# --- Phase 5: Next Steps ---
print_next_steps() {
  local count
  count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo
  success "beads-superpowers v$VERSION installed ($count skills via $INSTALL_TIER)"
  echo
  echo "Next steps:"
  echo "  1. Restart Claude Code (or start a new session) to activate skills"
  echo "  2. Run /skills to verify — the beads-superpowers skills should be available"
  if [ "$HAS_BEADS" != true ]; then
    echo
    echo "  3. Install beads for persistent task tracking:"
    echo "       brew install beads          # macOS (Homebrew)"
    echo "       npm install -g @beads/bd   # any platform (npm)"
    echo "  4. In each project: bd init"
  fi
  if [ "$HAS_CODEX" = 1 ]; then
    echo
    printf '  %bCodex CLI:%b\n' "${BOLD}" "${NC}"
    echo "    Add to ~/.codex/config.toml:"
    echo "      [features]"
    echo "      codex_hooks = true"
  fi
  if [ "$HAS_OPENCODE" = 1 ]; then
    echo
    printf '  %bOpenCode:%b\n' "${BOLD}" "${NC}"
    echo "    Install via the git plugin spec in opencode.json — see .opencode/INSTALL.md."
  fi
  echo
  if [ "$HAS_COPILOT" = 1 ]; then info "Copilot CLI detected — native install: copilot plugin marketplace add DollarDill/beads-superpowers && copilot plugin install beads-superpowers@beads-superpowers-marketplace"; fi
  if [ "$HAS_CURSOR" = 1 ]; then info "Cursor detected — native install: /add-plugin beads-superpowers (in Cursor Agent)"; fi
  if [ "$HAS_DROID" = 1 ]; then info "Factory Droid detected — native: droid plugin marketplace add https://github.com/DollarDill/beads-superpowers && droid plugin install beads-superpowers@beads-superpowers-marketplace"; fi
  if [ "$HAS_AGY" = 1 ]; then info "Antigravity detected — native install: agy plugin install https://github.com/DollarDill/beads-superpowers"; fi
  if [ "$HAS_KIMI" = 1 ]; then info "Kimi Code detected — native install: /plugins install https://github.com/DollarDill/beads-superpowers"; fi
  if [ "$HAS_PI" = 1 ]; then info "Pi detected — native install: pi install git:github.com/DollarDill/beads-superpowers"; fi
}

# --- Uninstall ---
do_uninstall() {
  info "Uninstalling beads-superpowers..."

  local installed_tier="tarball"
  if [ -f "$VERSION_FILE" ]; then
    local installed
    installed=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    installed_tier="${installed#*:}"
    [ "$installed_tier" = "$installed" ] && installed_tier="tarball"
  fi

  case "$installed_tier" in
    plugin)
      claude plugin uninstall beads-superpowers@beads-superpowers-marketplace 2>/dev/null || true
      codex plugin uninstall beads-superpowers@beads-superpowers-marketplace 2>/dev/null || true
      ;;
    npx|tarball|git|local)
      local removed=0
      for skill in "${KNOWN_SKILLS[@]}"; do
        if [ -d "$SKILLS_DIR/$skill" ]; then
          rm -rf "${SKILLS_DIR:?}/$skill"
          removed=$((removed + 1))
        fi
      done
      info "Removed $removed skill directories"

      for agent in "${KNOWN_AGENTS[@]}"; do
        [ -f "$AGENTS_DIR/$agent.md" ] && rm -f "$AGENTS_DIR/$agent.md"
      done
      info "Removed agent definitions"

      rm -f "$HOOK_SCRIPT" "$HOOKS_DIR/beads-superpowers-reminder.sh"
      rm -rf "$HOOKS_DIR/beads-superpowers"
      info "Removed hook scripts"

      if [ -f "$SETTINGS_FILE" ] && command -v python3 >/dev/null 2>&1; then
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
      ;;
  esac

  # ADR-0039 migration: clean up any stale reminder registration/file, regardless of tier
  cleanup_stale_reminder "$SETTINGS_FILE"
  rm -f "$HOOKS_DIR/beads-superpowers-reminder.sh"

  uninstall_codex_support
  uninstall_opencode_support
  cleanup_legacy_skills

  rm -f "$VERSION_FILE"
  success "beads-superpowers uninstalled"
}

# --- Dry Run ---
print_dry_run() {
  echo
  printf "${BOLD}beads-superpowers v%s installer (dry run)${NC}\n" "$VERSION"
  echo
  echo "Would install the skill suite using the best available method:"
  if [ "$HAS_CLAUDE" = 1 ] || [ "$HAS_CODEX" = 1 ]; then
    echo "  1. Plugin system (Claude Code / Codex)"
  fi
  [ "$HAS_NPX" = 1 ] && echo "  2. npx skills add"
  echo "  3. Direct download (tarball / git clone)"
  if [ "$HAS_CODEX" = 1 ]; then
    echo "  + Codex CLI skills"
  fi
  if [ "$HAS_OPENCODE" = 1 ]; then
    echo "  (OpenCode: see .opencode/INSTALL.md — git plugin spec, not installed by this script)"
  fi
  echo
  echo "No files were modified."
}

# --- Test Mode ---
do_test() {
  local test_home="/tmp/beads-superpowers-test"
  rm -rf "$test_home"

  info "Test mode: installing to $test_home/"
  echo

  # Re-run ourselves with overridden HOME, --yes, and --version to force Tier 3 (tarball).
  # --version skips Tiers 1-2, which don't install to $SKILLS_DIR (plugin goes to cache).
  # --with-yegge (when given) is forwarded so --test verifies whichever mode was requested.
  local extra_flags=""
  if [ "$FLAG_WITH_YEGGE" = true ]; then extra_flags="--with-yegge"; fi
  # shellcheck disable=SC2086  # word splitting intentional: optional flag
  BEADS_SUPERPOWERS_SKILLS_DIR="$test_home/skills" HOME="$test_home" bash "$0" --yes --version "$FALLBACK_VERSION" $extra_flags

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

  # ADR-0039: fresh install must not write a reminder script or register UserPromptSubmit
  if [ -f "$test_home/.claude/hooks/beads-superpowers-reminder.sh" ]; then
    error "Fresh install wrote the reminder script (should not exist)"; fail=$((fail + 1))
  else
    success "Fresh install: no reminder script"; pass=$((pass + 1))
  fi

  # Check settings.json
  if python3 -c "
import json
d=json.load(open('$test_home/.claude/settings.json'))
assert d['hooks']['SessionStart']
assert 'UserPromptSubmit' not in d.get('hooks', {})
" 2>/dev/null; then
    success "settings.json: SessionStart registered, no UserPromptSubmit"; pass=$((pass + 1))
  else
    error "settings.json: SessionStart missing or UserPromptSubmit present"; fail=$((fail + 1))
  fi

  # Check agents — default: NOT installed; --with-yegge: installed (opt-in)
  local agents_ok=true
  for agent in "${KNOWN_AGENTS[@]}"; do
    if [ "$FLAG_WITH_YEGGE" = true ]; then
      if [ ! -f "$test_home/.claude/agents/$agent.md" ]; then agents_ok=false; break; fi
    else
      if [ -e "$test_home/.claude/agents/$agent.md" ]; then agents_ok=false; break; fi
    fi
  done
  if [ "$agents_ok" = true ]; then
    if [ "$FLAG_WITH_YEGGE" = true ]; then
      success "Agents installed (--with-yegge): yegge"
    else
      success "Agents not installed by default"
    fi
    pass=$((pass + 1))
  else
    if [ "$FLAG_WITH_YEGGE" = true ]; then
      error "Agents missing despite --with-yegge"
    else
      error "Agents installed without --with-yegge"
    fi
    fail=$((fail + 1))
  fi

  # cleanup_stale_reminder: stale "ours" entry removed, foreign hook preserved, backup written
  local cleanup_settings="$test_home/cleanup-settings.json"
  cat > "$cleanup_settings" << 'CLEANUPEOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "", "hooks": [
        {"type": "command", "command": "bash /home/user/.claude/hooks/beads-superpowers-reminder.sh"},
        {"type": "command", "command": "bash /home/user/.claude/hooks/somebody-elses-hook.sh"}
      ]}
    ]
  }
}
CLEANUPEOF
  cleanup_stale_reminder "$cleanup_settings"
  if grep -q "superpowers-reminder" "$cleanup_settings"; then
    error "cleanup_stale_reminder: stale entry survived cleanup"; fail=$((fail + 1))
  elif ! grep -q "somebody-elses-hook" "$cleanup_settings"; then
    error "cleanup_stale_reminder: foreign hook was deleted"; fail=$((fail + 1))
  elif ! ls "${cleanup_settings}".bak-* > /dev/null 2>&1; then
    error "cleanup_stale_reminder: no timestamped backup written"; fail=$((fail + 1))
  else
    success "cleanup_stale_reminder: stale removed, foreign preserved, backup written"; pass=$((pass + 1))
  fi

  # cleanup_stale_reminder: skip with warning when python3 is unavailable, file untouched
  local nopython_settings="$test_home/nopython-settings.json"
  cat > "$nopython_settings" << 'NOPYEOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "", "hooks": [
        {"type": "command", "command": "bash /home/user/.claude/hooks/beads-superpowers-reminder.sh"}
      ]}
    ]
  }
}
NOPYEOF
  local before after cleanup_output saved_has_python3="$HAS_PYTHON3"
  before=$(cat "$nopython_settings")
  HAS_PYTHON3=0
  cleanup_output=$(cleanup_stale_reminder "$nopython_settings" 2>&1)
  HAS_PYTHON3="$saved_has_python3"
  after=$(cat "$nopython_settings")
  if [ "$before" != "$after" ]; then
    error "cleanup_stale_reminder: modified settings without python3"; fail=$((fail + 1))
  elif ! echo "$cleanup_output" | grep -qi "manual fix"; then
    error "cleanup_stale_reminder: no manual-fix warning printed"; fail=$((fail + 1))
  else
    success "cleanup_stale_reminder: skip-with-warning without python3"; pass=$((pass + 1))
  fi

  # Test uninstall
  BEADS_SUPERPOWERS_SKILLS_DIR="$test_home/skills" HOME="$test_home" bash "$0" --uninstall 2>&1

  if [ ! -f "$test_home/.claude/hooks/beads-superpowers-session-start.sh" ] && \
     [ ! -f "$test_home/.claude/hooks/beads-superpowers-reminder.sh" ] && \
     [ ! -f "$test_home/.claude/agents/yegge.md" ]; then
    success "Uninstall: hooks and agents removed"; pass=$((pass + 1))
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
  detect_tools

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

  print_consent
  wait_for_consent
  do_install
  do_verify
  print_next_steps
}

main "$@"
