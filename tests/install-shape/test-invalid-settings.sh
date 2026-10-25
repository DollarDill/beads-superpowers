#!/usr/bin/env bash
# test-invalid-settings.sh — install.sh against a Claude settings file that is
# not valid JSON: the file stays byte-for-byte untouched, a warning names it and
# says the hook was NOT registered (in the run and again in the summary), the
# rest of the install lands, and the exit status is 0.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
fail=0
n=0

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# case <name> <printf-format content, "" for an empty file> [stale-reminder]
run_case() {
  n=$((n + 1))
  local name="$1" content="$2" stale="${3:-}" h="$SANDBOX/h$n" before after rc log="$SANDBOX/h$n.log"
  mkdir -p "$h/.claude"
  # shellcheck disable=SC2059
  printf "$content" >"$h/.claude/settings.json"
  # A stale reminder reference sends cleanup_stale_reminder down its parse path.
  if [ -n "$stale" ]; then printf 'superpowers-reminder' >>"$h/.claude/settings.json"; fi
  before=$(sha "$h/.claude/settings.json")
  HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
    bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$log" 2>&1
  rc=$?
  after=$(sha "$h/.claude/settings.json")
  if [ "$rc" != 0 ]; then echo "FAIL [$name]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
  if [ "$before" != "$after" ]; then echo "FAIL [$name]: settings file was modified"; fail=1; fi
  if ! grep -q "$h/.claude/settings.json.*NOT registered" "$log"; then echo "FAIL [$name]: no warning naming the file and 'NOT registered'"; fail=1; fi
  # once in the run, once in the closing summary: the last occurrence sits
  # directly above the final "installed" line
  local last_warn installed_ln
  last_warn=$(grep -n "NOT registered" "$log" | tail -n 1 | cut -d: -f1)
  installed_ln=$(grep -n " installed (" "$log" | tail -n 1 | cut -d: -f1)
  if [ "$(grep -c "NOT registered" "$log")" -lt 2 ] || [ -z "$last_warn" ] || [ -z "$installed_ln" ] \
     || [ "$last_warn" -ge "$installed_ln" ] || [ $((installed_ln - last_warn)) -gt 2 ]; then
    echo "FAIL [$name]: warning not repeated in the final summary (warn line ${last_warn:-none}, installed line ${installed_ln:-none})"; fail=1
  fi
  if grep -q "Traceback" "$log"; then echo "FAIL [$name]: traceback in output"; fail=1; fi
  if [ ! -f "$h/skills/.beads-superpowers-version" ] || [ ! -f "$h/.claude/hooks/beads-superpowers-session-start.sh" ]; then
    echo "FAIL [$name]: rest of the install missing"; fail=1
  fi
}

run_case "truncated JSON" '{"hooks": '
run_case "not json" 'not json'
run_case "empty file" ''
run_case "whitespace only" ' \n\n'
run_case "invalid JSON with stale reminder" '{"hooks": ' stale

# An unreadable settings path (a directory) is handled like invalid JSON.
n=$((n + 1))
h="$SANDBOX/h$n"; log="$h.log"
mkdir -p "$h/.claude/settings.json"
HOME="$h" BEADS_SUPERPOWERS_SKILLS_DIR="$h/skills" \
  bash "$REPO_ROOT/install.sh" --yes --source "$REPO_ROOT" >"$log" 2>&1
rc=$?
if [ "$rc" != 0 ]; then echo "FAIL [unreadable]: exit $rc"; sed -n '1,25p' "$log"; fail=1; fi
if [ ! -d "$h/.claude/settings.json" ]; then echo "FAIL [unreadable]: settings path was modified"; fail=1; fi
if ! grep -q "$h/.claude/settings.json.*NOT registered" "$log"; then echo "FAIL [unreadable]: no warning naming the file and 'NOT registered'"; fail=1; fi
if [ "$(grep -c "NOT registered" "$log")" -lt 2 ]; then echo "FAIL [unreadable]: warning not repeated in the final summary"; fail=1; fi
if grep -q "Traceback" "$log"; then echo "FAIL [unreadable]: traceback in output"; fail=1; fi
if [ ! -f "$h/skills/.beads-superpowers-version" ]; then echo "FAIL [unreadable]: rest of the install missing"; fail=1; fi

if [ "$fail" -eq 0 ]; then echo "PASS: invalid-JSON settings left untouched, install continues"; fi
exit "$fail"
