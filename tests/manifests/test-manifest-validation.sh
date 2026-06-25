#!/usr/bin/env bash
# Deterministic manifest validation: every shipped manifest is valid JSON,
# has required keys, and version-keyed manifests match package.json.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit
VER=$(jq -r .version package.json)
fail=0
valid_json() {
  if python3 -m json.tool < "$1" >/dev/null 2>&1; then
    echo "JSON OK: $1"
  else
    echo "BAD JSON: $1"; fail=1
  fi
}
ver_match() {
  local v; v=$(jq -r "$2" "$1")
  if [ "$v" = "$VER" ]; then
    echo "VER OK: $1"
  else
    echo "VER MISMATCH: $1 ($v != $VER)"; fail=1
  fi
}
for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .cursor-plugin/plugin.json \
         hooks/hooks-cursor.json gemini-extension.json .kimi-plugin/plugin.json; do
  if [ -f "$f" ]; then
    valid_json "$f"
  else
    echo "MISSING: $f"; fail=1
  fi
done
ver_match .cursor-plugin/plugin.json '.version'
ver_match gemini-extension.json '.version'
ver_match .kimi-plugin/plugin.json '.version'
jq -e '.skills=="./skills/"' .cursor-plugin/plugin.json >/dev/null && echo "cursor skills OK" || fail=1
jq -e '.sessionStart.skill=="using-superpowers"' .kimi-plugin/plugin.json >/dev/null && echo "kimi sessionStart OK" || fail=1
jq -e '.contextFileName=="GEMINI.md"' gemini-extension.json >/dev/null && echo "gemini ctx OK" || fail=1

# Referenced-path resolution (catches runtime breakage that JSON validation misses)
need() {
  if [ -e "$1" ]; then
    echo "PATH OK: $1"
  else
    echo "MISSING REF: $1"; fail=1
  fi
}
# gemini-extension.json contextFileName must exist
need "$(jq -r .contextFileName gemini-extension.json)"
# every @-include in GEMINI.md must resolve (strip leading '@', resolve repo-relative)
while read -r inc; do need "${inc#@}"; done < <(grep -oE '^@\./[^[:space:]]+' GEMINI.md | sed 's#@\./#./#')
# .kimi-plugin sessionStart.skill must map to a real skill dir
need "skills/$(jq -r .sessionStart.skill .kimi-plugin/plugin.json)/SKILL.md"
# hooks-cursor.json command target (run-hook.cmd) must exist
need "hooks/run-hook.cmd"
exit $fail
