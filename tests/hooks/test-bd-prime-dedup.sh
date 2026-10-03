#!/usr/bin/env bash
# test-bd-prime-dedup.sh — when bd's own prime hook is also registered
# (`bd setup claude`, or bd init's Cursor hooks), session-start KEEPS its
# curated <beads-context> and emits a one-line notice naming the remedy:
# Claude Code -> top-level JSON systemMessage (exit-0 stderr is never shown);
# Cursor -> stderr. Detection is harness-scoped and matches bd's real shapes
# (bd v1.3.1: "bd prime --hook-json" via json.MarshalIndent; Cursor
# {"command": "bd cursor-hook sessionStart"} under "version": 1).
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/fixtures" "$TMP/run"
fail=0

cat > "$TMP/bin/bd" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  memories)          cat "$BSP_FIXTURES/memories.json" ;;
  recall)            printf 'RECALLED BODY %s\n' "$2" ;;
  --version|version) printf 'bd version 1.3.1 (test)\n' ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/bd"
cat > "$TMP/fixtures/memories.json" <<'FIX'
{
  "key-a": "@type=semantic:lesson @created=2026-07-01 @salience=5 preview body"
}
FIX

# bd v1.3.1's real Claude shape (json.MarshalIndent, cmd/bd/setup/claude.go).
claude_settings() {  # $1 = command string
  cat <<JSON
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "command": "$1",
            "type": "command"
          }
        ],
        "matcher": ""
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "$1",
            "type": "command"
          }
        ],
        "matcher": ""
      }
    ]
  }
}
JSON
}
# bd v1.3.1's real Cursor shape (cmd/bd/setup/cursor.go).
cursor_hooks() {
  cat <<'JSON'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "command": "bd cursor-hook sessionStart"
      }
    ]
  }
}
JSON
}

# Fresh fixture tree per case: $TMP/c/<id>/{home,proj}. Each run is fully
# isolated (env -i: the real Claude Code env vars of whoever runs this test
# never leak in), with its own HOME, a shared private XDG_RUNTIME_DIR, and a
# distinct session_id (dedup-marker-safe).
setup() { mkdir -p "$TMP/c/$1/home" "$TMP/c/$1/proj"; }
P() { printf '%s' "$TMP/c/$1/proj"; }
H() { printf '%s' "$TMP/c/$1/home"; }

# run <id> <cwd> [VAR=val ...] [-- hook-args...] -> $TMP/c/<id>/{out,err,rc}
run() {
  local id="$1" dir="$2"; shift 2
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  local d="$TMP/c/$id"
  ( cd "$dir" && printf '{"session_id":"bpd-%s","source":"startup"}' "$id" \
      | env -i HOME="$(H "$id")" PATH="$TMP/bin:$PATH" BSP_FIXTURES="$TMP/fixtures" \
          XDG_RUNTIME_DIR="$TMP/run" "${envs[@]+"${envs[@]}"}" bash "$HOOK" "$@" \
          >"$d/out" 2>"$d/err" ); echo $? >"$d/rc"
}
err() { cat "$TMP/c/$1/err"; }
ctx() { grep -o '<beads-context>.*</beads-context>' "$TMP/c/$1/out"; }
sysmsg() { python3 -c 'import json,sys; print(json.load(sys.stdin).get("systemMessage",""))' <"$TMP/c/$1/out" 2>/dev/null; }
addctx() { python3 -c 'import json,sys; print(json.load(sys.stdin).get("hookSpecificOutput",{}).get("additionalContext",""))' <"$TMP/c/$1/out" 2>/dev/null; }

pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }
no_notice() {  # $1 = id, $2 = label
  if grep -q 'is also registered' "$TMP/c/$1/out" "$TMP/c/$1/err"; then
    bad "$2 — unexpected notice"; echo "  stderr: $(err "$1")"
  elif ! grep -q '<beads-context>' "$TMP/c/$1/out"; then
    bad "$2 — <beads-context> missing"
  else pass "$2"; fi
}
claude_notice() {  # $1 = id, $2 = label
  local sm; sm=$(sysmsg "$1")
  if [[ "$sm" == *"is also registered"* && "$sm" == *"bd setup claude --remove"* ]]; then pass "$2"
  else bad "$2 — systemMessage lacks notice (got: '$sm')"; fi
}

# --- baseline (anti-vacuous): no settings anywhere ---
setup base; run base "$(P base)" CLAUDE_PLUGIN_ROOT=x
BASE=$(ctx base)
if [ -z "$BASE" ]; then
  echo "FAIL: baseline <beads-context> empty — the test would be vacuous"; exit 1
fi
pass "baseline <beads-context> present"

# a: project settings, bd's real MarshalIndent shape
setup a; mkdir -p "$(P a)/.claude"
claude_settings "bd prime --hook-json" >"$(P a)/.claude/settings.json"
run a "$(P a)" CLAUDE_PLUGIN_ROOT=x
claude_notice a "a — project settings 'bd prime --hook-json' -> systemMessage notice"
if addctx a | grep -q 'is also registered'; then bad "a — notice leaked into additionalContext"
else pass "a — notice kept out of additionalContext"; fi
if [ "$(ctx a)" = "$BASE" ]; then pass "a — <beads-context> identical to baseline"
else bad "a — <beads-context> differs from baseline"; fi

# json-intact: case a's stdout still parses as JSON
if python3 -c 'import json,sys; json.load(sys.stdin)' <"$TMP/c/a/out" 2>/dev/null; then
  pass "json-intact — case a stdout parses as JSON"
else bad "json-intact — stdout is not valid JSON"; fi

# a2: global settings.local.json, --stealth variant
setup a2; mkdir -p "$(H a2)/.claude"
claude_settings "bd prime --stealth --hook-json" >"$(H a2)/.claude/settings.local.json"
run a2 "$(P a2)" CLAUDE_PLUGIN_ROOT=x
claude_notice a2 "a2 — global settings.local.json 'bd prime --stealth --hook-json' -> notice"

# a3: CWD is a subdirectory; CLAUDE_PROJECT_DIR points at the project root (S1)
setup a3; mkdir -p "$(P a3)/.claude" "$(P a3)/sub/dir"
claude_settings "bd prime --hook-json" >"$(P a3)/.claude/settings.json"
run a3 "$(P a3)/sub/dir" CLAUDE_PROJECT_DIR="$(P a3)"
claude_notice a3 "a3 — subdirectory CWD + CLAUDE_PROJECT_DIR -> notice"

# b: Cursor hooks.json, real shape -> stderr notice, context kept
setup b; mkdir -p "$(P b)/.cursor"
cursor_hooks >"$(P b)/.cursor/hooks.json"
run b "$(P b)" CURSOR_PLUGIN_ROOT=x
if err b | grep -q 'bd cursor-hook' && err b | grep -q 'is also registered'; then
  pass "b — Cursor 'bd cursor-hook' -> stderr notice"
else bad "b — stderr lacks Cursor notice (got: '$(err b)')"; fi
cur_ctx=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("additional_context",""))' <"$TMP/c/b/out" 2>/dev/null)
if [[ "$cur_ctx" == *"<beads-context>"* ]]; then pass "b — Cursor additional_context keeps <beads-context>"
else bad "b — Cursor additional_context lacks <beads-context>"; fi

# c: Claude harness, only a Cursor hooks file -> no notice
setup c; mkdir -p "$(P c)/.cursor"
cursor_hooks >"$(P c)/.cursor/hooks.json"
run c "$(P c)" CLAUDE_PLUGIN_ROOT=x
no_notice c "c — Cursor hooks file under Claude Code -> no notice"

# c2: Cursor harness, only Claude settings -> no notice
setup c2; mkdir -p "$(P c2)/.claude"
claude_settings "bd prime --hook-json" >"$(P c2)/.claude/settings.json"
run c2 "$(P c2)" CURSOR_PLUGIN_ROOT=x
no_notice c2 "c2 — Claude settings under Cursor -> no notice"

# codex: Codex env (also carries CLAUDE_PLUGIN_ROOT) with Claude settings -> no notice
setup codex; mkdir -p "$(P codex)/.claude"
claude_settings "bd prime --hook-json" >"$(P codex)/.claude/settings.json"
run codex "$(P codex)" CODEX_PLUGIN_ROOT=x CLAUDE_PLUGIN_ROOT=x
no_notice codex "codex — Claude settings under Codex -> no notice"

# plain: --emit-plain with Claude settings -> no notice
setup plain; mkdir -p "$(P plain)/.claude"
claude_settings "bd prime --hook-json" >"$(P plain)/.claude/settings.json"
run plain "$(P plain)" CLAUDE_PLUGIN_ROOT=x -- --emit-plain
no_notice plain "plain — --emit-plain with Claude settings -> no notice"

# d: no settings -> no notice
setup d; run d "$(P d)" CLAUDE_PLUGIN_ROOT=x
no_notice d "d — no settings -> no notice"

# near-miss: commands that merely resemble bd's hook
setup nm; mkdir -p "$(P nm)/.claude" "$(H nm)/.claude"
claude_settings "bd primer" >"$(P nm)/.claude/settings.json"
claude_settings "echo bd prime" >"$(P nm)/.claude/settings.local.json"
claude_settings "bd prime-check" >"$(H nm)/.claude/settings.json"
run nm "$(P nm)" CLAUDE_PLUGIN_ROOT=x
no_notice nm "near-miss — 'bd primer' / 'echo bd prime' / 'bd prime-check' -> no notice"

# once: hook in both project and global settings -> notice exactly once
setup once; mkdir -p "$(P once)/.claude" "$(H once)/.claude"
claude_settings "bd prime --hook-json" >"$(P once)/.claude/settings.json"
claude_settings "bd prime --hook-json" >"$(H once)/.claude/settings.json"
run once "$(P once)" CLAUDE_PLUGIN_ROOT=x
n=$(sysmsg once | grep -o 'is also registered' | wc -l | tr -d ' ')
if [ "$n" = "1" ]; then pass "once — notice appears exactly once"
else bad "once — notice count in systemMessage is $n, want 1"; fi

# malformed: unparseable settings -> exit 0, no notice
setup mal; mkdir -p "$(P mal)/.claude"
printf '{not json' >"$(P mal)/.claude/settings.json"
run mal "$(P mal)" CLAUDE_PLUGIN_ROOT=x
if [ "$(cat "$TMP/c/mal/rc")" = "0" ]; then pass "malformed — exit 0"
else bad "malformed — exit $(cat "$TMP/c/mal/rc")"; fi
no_notice mal "malformed — no notice"

exit $fail
