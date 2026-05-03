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

# --- Helper: start/stop local HTTP server ---
start_http_server() {
    cp -f /src/release.tar.gz /tmp/release.tar.gz
    cd /tmp && python3 -m http.server 8888 >/dev/null 2>&1 &
    HTTP_PID=$!
    sleep 1
}

stop_http_server() {
    kill "$HTTP_PID" 2>/dev/null || true
    wait "$HTTP_PID" 2>/dev/null || true
}

INSTALL_CMD="BEADS_SUPERPOWERS_TARBALL_URL=http://localhost:8888/release.tar.gz bash /src/install.sh"

# ============================================================
echo "=== Group 1: Fresh Install ==="
# ============================================================

start_http_server
$INSTALL_CMD --yes --version "$VERSION"
stop_http_server

# Skills: count + spot-check
skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
assert_count_gte "$skill_count" 22 "skill count >= 22"
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
echo "=== Group 2: Idempotent Re-Install ==="
# ============================================================

start_http_server
# Re-running with same version should exit 0 and say "already installed"
output=$($INSTALL_CMD --yes --version "$VERSION" 2>&1) || true
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
