#!/usr/bin/env bash
# E2E installer test — runs INSIDE the Docker container
# Expects: /src/install.sh (read-only), /src/release.tar.gz (read-only)
# Expects: VERSION env var set by host
set -euo pipefail

VERSION="${VERSION:?VERSION env var required}"

# --- Assertion helpers ---
pass=0
fail=0

assert_file_exists() {
    local path="$1" name="$2"
    if [ -f "$path" ]; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — not found: $path"; fail=$((fail + 1))
    fi
}

assert_dir_exists() {
    local path="$1" name="$2"
    if [ -d "$path" ]; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — not found: $path"; fail=$((fail + 1))
    fi
}

assert_file_not_exists() {
    local path="$1" name="$2"
    if [ ! -f "$path" ]; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — still exists: $path"; fail=$((fail + 1))
    fi
}

assert_file_executable() {
    local path="$1" name="$2"
    if [ -x "$path" ]; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — not executable: $path"; fail=$((fail + 1))
    fi
}

assert_file_contains() {
    local path="$1" pattern="$2" name="$3"
    if grep -q "$pattern" "$path" 2>/dev/null; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — pattern not found: $pattern"; fail=$((fail + 1))
    fi
}

assert_file_not_contains() {
    local path="$1" pattern="$2" name="$3"
    if ! grep -q "$pattern" "$path" 2>/dev/null; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — pattern unexpectedly found: $pattern"; fail=$((fail + 1))
    fi
}

assert_json_valid() {
    local path="$1" name="$2"
    if python3 -m json.tool "$path" >/dev/null 2>&1; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — invalid JSON: $path"; fail=$((fail + 1))
    fi
}

assert_command_output_valid_json() {
    local cmd="$1" name="$2"
    if eval "$cmd" 2>/dev/null | python3 -m json.tool >/dev/null 2>&1; then
        echo "  [PASS] $name"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — command did not produce valid JSON"; fail=$((fail + 1))
    fi
}

assert_count_gte() {
    local actual="$1" expected="$2" name="$3"
    if [ "$actual" -ge "$expected" ]; then
        echo "  [PASS] $name (found $actual, need >= $expected)"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — found $actual, expected >= $expected"; fail=$((fail + 1))
    fi
}

assert_count_eq() {
    local actual="$1" expected="$2" name="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  [PASS] $name (found $actual)"; pass=$((pass + 1))
    else
        echo "  [FAIL] $name — found $actual, expected $expected"; fail=$((fail + 1))
    fi
}

# --- Tool hiding helpers (per-binary stub, not per-directory) ---
# In Debian, curl/git/python3/tar all live in /usr/bin.
# Removing /usr/bin from PATH would break everything.
# Instead, prepend a directory of stub scripts that exit 127.
ORIGINAL_PATH="$PATH"

hide_tool() {
  mkdir -p /tmp/path-overrides
  for tool in "$@"; do
    printf '#!/bin/sh\nexit 127\n' > "/tmp/path-overrides/$tool"
    chmod +x "/tmp/path-overrides/$tool"
  done
  export PATH="/tmp/path-overrides:$PATH"
}

restore_tools() {
  rm -rf /tmp/path-overrides
  export PATH="$ORIGINAL_PATH"
}

assert_output_contains() {
  local output="$1" pattern="$2" name="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  [PASS] $name"; pass=$((pass + 1))
  else
    echo "  [FAIL] $name — pattern not found: $pattern"; fail=$((fail + 1))
  fi
}

assert_no_skills_installed() {
  local name="$1"
  local count=0
  if [ -d "$HOME/.claude/skills" ]; then
    count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$count" -eq 0 ]; then
    echo "  [PASS] $name (0 skills)"; pass=$((pass + 1))
  else
    echo "  [FAIL] $name — found $count skill dirs"; fail=$((fail + 1))
  fi
}

# --- Helper: start/stop local HTTP server ---
start_http_server() {
    cp -f /src/release.tar.gz /tmp/release.tar.gz
    if [ -f /src/checksums.txt ]; then
      cp -f /src/checksums.txt /tmp/checksums.txt
    fi
    cd /tmp && python3 -m http.server 8888 >/dev/null 2>&1 &
    HTTP_PID=$!
    sleep 1
}

stop_http_server() {
    kill "$HTTP_PID" 2>/dev/null || true
    wait "$HTTP_PID" 2>/dev/null || true
}

TARBALL_URL="http://localhost:8888/release.tar.gz"

# ============================================================
echo "=== Group 1: Fresh Install ==="
# ============================================================

start_http_server
BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" bash /src/install.sh --yes --version "$VERSION"
stop_http_server

# Skills: count + spot-check
skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 23 "skill count >= 23"
assert_dir_exists "$HOME/.claude/skills/brainstorming" "skill: brainstorming"
assert_dir_exists "$HOME/.claude/skills/test-driven-development" "skill: TDD"
assert_dir_exists "$HOME/.claude/skills/using-superpowers" "skill: using-superpowers"
assert_file_exists "$HOME/.claude/skills/brainstorming/SKILL.md" "skill has SKILL.md"

# Agent
assert_file_exists "$HOME/.claude/agents/yegge.md" "agent: yegge"

# Hooks
assert_file_executable "$HOME/.claude/hooks/beads-superpowers-session-start.sh" "hook: session-start executable"
assert_file_executable "$HOME/.claude/hooks/beads-superpowers-reminder.sh" "hook: reminder executable"

# Version file
assert_file_exists "$HOME/.claude/skills/.beads-superpowers-version" "version file exists"
assert_file_contains "$HOME/.claude/skills/.beads-superpowers-version" "$VERSION" "version matches"

# settings.json
assert_json_valid "$HOME/.claude/settings.json" "settings.json valid JSON"
assert_file_contains "$HOME/.claude/settings.json" "beads-superpowers" "settings has beads-superpowers"
assert_file_contains "$HOME/.claude/settings.json" "SessionStart" "settings has SessionStart"
assert_file_contains "$HOME/.claude/settings.json" "UserPromptSubmit" "settings has UserPromptSubmit"

# Hook output
assert_command_output_valid_json "bash $HOME/.claude/hooks/beads-superpowers-session-start.sh" "session-start hook output valid JSON"
assert_command_output_valid_json "bash $HOME/.claude/hooks/beads-superpowers-reminder.sh" "reminder hook output valid JSON"

# ============================================================
echo "=== Group 1b: Multi-CLI Install Verification ==="
# ============================================================

# Check if Codex was detected during install
if command -v codex >/dev/null 2>&1; then
  echo "  [INFO] Codex CLI detected in container"

  # Codex skills installed
  codex_skill_count=$(find "$HOME/.codex/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  assert_count_gte "$codex_skill_count" 23 "Codex skill count >= 23"
  assert_dir_exists "$HOME/.codex/skills/using-superpowers" "Codex skill: using-superpowers"
  assert_file_exists "$HOME/.codex/skills/brainstorming/SKILL.md" "Codex skill has SKILL.md"
else
  echo "  [SKIP] Codex CLI not in container — skipping Codex assertions"
fi

# Check if OpenCode was detected during install
if command -v opencode >/dev/null 2>&1; then
  echo "  [INFO] OpenCode detected in container"

  # OpenCode skills installed
  oc_skill_count=$(find "$HOME/.config/opencode/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  assert_count_gte "$oc_skill_count" 23 "OpenCode skill count >= 23"
  assert_dir_exists "$HOME/.config/opencode/skills/using-superpowers" "OpenCode skill: using-superpowers"

  # OpenCode plugin installed
  assert_file_exists "$HOME/.config/opencode/plugins/beads-superpowers-plugin.ts" "OpenCode plugin installed"
else
  echo "  [SKIP] OpenCode not in container — skipping OpenCode assertions"
fi

# ============================================================
echo "=== Group 1c: Hook Format Validation ==="
# ============================================================

# Test session-start with CLAUDE_PLUGIN_ROOT (existing behavior)
assert_command_output_valid_json "CLAUDE_PLUGIN_ROOT=/src bash $HOME/.claude/hooks/beads-superpowers-session-start.sh" "session-start CC format valid JSON"

# Test session-start with CODEX_PLUGIN_ROOT
assert_command_output_valid_json "CODEX_PLUGIN_ROOT=/src bash $HOME/.claude/hooks/beads-superpowers-session-start.sh" "session-start Codex format valid JSON"

# Test session-start generic (no env var)
assert_command_output_valid_json "bash $HOME/.claude/hooks/beads-superpowers-session-start.sh" "session-start generic format valid JSON"

# Test reminder with CLAUDE_PLUGIN_ROOT
assert_command_output_valid_json "CLAUDE_PLUGIN_ROOT=/src bash $HOME/.claude/hooks/beads-superpowers-reminder.sh" "reminder CC format valid JSON"

# Test reminder with CODEX_PLUGIN_ROOT
assert_command_output_valid_json "CODEX_PLUGIN_ROOT=/src bash $HOME/.claude/hooks/beads-superpowers-reminder.sh" "reminder Codex format valid JSON"

# Test reminder generic
assert_command_output_valid_json "bash $HOME/.claude/hooks/beads-superpowers-reminder.sh" "reminder generic format valid JSON"

# ============================================================
echo "=== Group 2: Idempotent Re-Install ==="
# ============================================================

start_http_server
# Re-running with same version should exit 0 and say "already installed"
output=$(BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" bash /src/install.sh --yes --version "$VERSION" 2>&1) || true
stop_http_server

if echo "$output" | grep -q "already installed"; then
    echo "  [PASS] re-install detects existing version"; pass=$((pass + 1))
else
    echo "  [FAIL] re-install did not detect existing version"; fail=$((fail + 1))
fi

# ============================================================
echo "=== Group 3: Uninstall ==="
# ============================================================

bash /src/install.sh --uninstall

assert_file_not_exists "$HOME/.claude/hooks/beads-superpowers-session-start.sh" "hook removed"
assert_file_not_exists "$HOME/.claude/hooks/beads-superpowers-reminder.sh" "reminder removed"
assert_file_not_exists "$HOME/.claude/agents/yegge.md" "agent removed"
assert_file_not_exists "$HOME/.claude/skills/.beads-superpowers-version" "version file removed"

# settings.json should still be valid but cleaned
assert_json_valid "$HOME/.claude/settings.json" "settings.json still valid after uninstall"
assert_file_not_contains "$HOME/.claude/settings.json" "beads-superpowers" "settings cleaned of beads-superpowers"

# All skill directories should be gone
remaining=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_eq "$remaining" 0 "all skill dirs removed"

# Multi-CLI uninstall verification
if command -v codex >/dev/null 2>&1; then
  codex_remaining=$(find "$HOME/.codex/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  assert_count_eq "$codex_remaining" 0 "Codex skills removed"
fi

if command -v opencode >/dev/null 2>&1; then
  oc_remaining=$(find "$HOME/.config/opencode/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  assert_count_eq "$oc_remaining" 0 "OpenCode skills removed"
  assert_file_not_exists "$HOME/.config/opencode/plugins/beads-superpowers-plugin.ts" "OpenCode plugin removed"
fi

# ============================================================
echo "=== Group 4: Checksum Validation ==="
# ============================================================

# Clean state for checksum tests
rm -rf "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"

# 4a: Valid checksum passes
start_http_server
BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
BEADS_SUPERPOWERS_CHECKSUMS_URL="http://localhost:8888/checksums.txt" \
  bash /src/install.sh --yes --version "$VERSION" 2>&1
stop_http_server

skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 22 "checksum: valid tarball installs"

# Clean up for next checksum test
bash /src/install.sh --uninstall 2>/dev/null || true
rm -rf "$HOME/.claude/skills"

# 4b: Corrupted tarball fails with checksum error
# Start server first (copies clean tarball), then corrupt it in-place
start_http_server
printf '\xff' | dd of=/tmp/release.tar.gz bs=1 seek=100 count=1 conv=notrunc 2>/dev/null
output=$(BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
BEADS_SUPERPOWERS_CHECKSUMS_URL="http://localhost:8888/checksums.txt" \
  bash /src/install.sh --yes --version "$VERSION" 2>&1) || true
stop_http_server

assert_output_contains "$output" "Checksum mismatch" "checksum: corrupted tarball rejected"

# 4c: --skip-checksum bypasses verification (use valid tarball to verify end-to-end)
rm -rf "$HOME/.claude/skills"
cp -f /src/release.tar.gz /tmp/release.tar.gz
if [ -f /src/checksums.txt ]; then cp -f /src/checksums.txt /tmp/checksums.txt; fi

start_http_server
output=$(BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
BEADS_SUPERPOWERS_CHECKSUMS_URL="http://localhost:8888/checksums.txt" \
  bash /src/install.sh --yes --version "$VERSION" --skip-checksum 2>&1) || true
stop_http_server

assert_output_contains "$output" "skipped" "checksum: --skip-checksum message shown"
skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 22 "checksum: --skip-checksum install succeeds"

bash /src/install.sh --uninstall 2>/dev/null || true

# 4d: Missing checksums.txt warns but proceeds
rm -rf "$HOME/.claude/skills"
cp -f /src/release.tar.gz /tmp/release.tar.gz
rm -f /tmp/checksums.txt

start_http_server
BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
BEADS_SUPERPOWERS_CHECKSUMS_URL="http://localhost:8888/missing-checksums.txt" \
  bash /src/install.sh --yes --version "$VERSION" 2>&1
stop_http_server

skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 22 "checksum: missing checksums.txt still installs"

bash /src/install.sh --uninstall 2>/dev/null || true

# ============================================================
echo "=== Group 5: Fallback Chain ==="
# ============================================================

rm -rf "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"

# 5a: Tarball tier (curl available, no plugin CLIs treated as non-functional)
start_http_server
BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
  bash /src/install.sh --yes --version "$VERSION" 2>&1
stop_http_server

skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 22 "fallback: tarball tier installs skills"

# Check version:tier format
assert_file_exists "$HOME/.claude/skills/.beads-superpowers-version" "fallback: version file exists"
assert_file_contains "$HOME/.claude/skills/.beads-superpowers-version" ":" "fallback: version file has tier separator"

bash /src/install.sh --uninstall 2>/dev/null || true
rm -rf "$HOME/.claude"

# 5b: Git clone tier (hide curl from PATH)
hide_tool curl wget
output=$(bash /src/install.sh --yes --version "$VERSION" 2>&1) || true
restore_tools

skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 22 "fallback: git clone tier installs skills"
assert_file_contains "$HOME/.claude/skills/.beads-superpowers-version" "git" "fallback: version file shows git tier"

bash /src/install.sh --uninstall 2>/dev/null || true
rm -rf "$HOME/.claude"

# 5c: All methods fail gracefully
hide_tool claude codex npx curl wget git
output=$(bash /src/install.sh --yes --version "$VERSION" 2>&1) || true
restore_tools

assert_output_contains "$output" "All installation methods failed" "fallback: graceful failure message"
assert_no_skills_installed "fallback: no partial state after failure"

# ============================================================
echo "=== Group 6: Atomic Rollback ==="
# ============================================================

rm -rf "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"

# Make skills dir read-only to force promote_staging failure
mkdir -p "$HOME/.claude/skills"
chmod 444 "$HOME/.claude/skills"

start_http_server
output=$(BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
  bash /src/install.sh --yes --version "$VERSION" 2>&1) || true
stop_http_server

# Restore permissions
chmod 755 "$HOME/.claude/skills"

# Should have no partial state
remaining=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_eq "$remaining" 0 "rollback: no partial skills after permission failure"

# ============================================================
echo "=== Group 7: bd Integration ==="
# ============================================================

rm -rf "$HOME/.claude"

# Install first
start_http_server
BEADS_SUPERPOWERS_TARBALL_URL="$TARBALL_URL" \
  bash /src/install.sh --yes --version "$VERSION" 2>&1
stop_http_server

# Test that session-start hook handles bd in PATH
if command -v bd >/dev/null 2>&1; then
  assert_command_output_valid_json "bash $HOME/.claude/hooks/beads-superpowers-session-start.sh" "bd: session-start with bd produces valid JSON"
else
  echo "  [SKIP] bd not in container — skipping bd integration"
fi

# Cleanup
bash /src/install.sh --uninstall 2>/dev/null || true

# ============================================================
echo
echo "=== Results ==="
if [ "$fail" -eq 0 ]; then
    echo "✓ All $pass checks passed"
    exit 0
else
    echo "✗ $fail checks failed, $pass passed"
    exit 1
fi
