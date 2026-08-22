#!/usr/bin/env bash
# Deterministic manifest validation: every shipped manifest is valid JSON,
# has required keys, and version-keyed manifests match package.json. Also
# validates the two marketplace ROLES (.agents source manifest vs the
# versioned .codex/.claude distributables) and the Pi .ts extension
# (ADR-0018 best-effort bar: shipped native config must be CI-validated).
#
# MANIFEST_ROOT overrides the repo root so tests/manifests/selftest.sh can
# run this validator against a mutated fixture copy (guard-the-guards).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST_ROOT="${MANIFEST_ROOT:-$ROOT}"
cd "$MANIFEST_ROOT" || exit
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
jq_ok() {  # file, filter, label
  if jq -e "$2" "$1" >/dev/null 2>&1; then
    echo "ROLE OK: $3"
  else
    echo "ROLE FAIL: $3 ($1  $2)"; fail=1
  fi
}
# JSON validity: plugin manifests + all three marketplace manifests
for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .cursor-plugin/plugin.json \
         hooks/hooks-cursor.json .kimi-plugin/plugin.json .devin-plugin/plugin.json gemini-extension.json \
         .claude-plugin/marketplace.json .codex-plugin/marketplace.json .agents/plugins/marketplace.json; do
  if [ -f "$f" ]; then
    valid_json "$f"
  else
    echo "MISSING: $f"; fail=1
  fi
done
ver_match .cursor-plugin/plugin.json '.version'
ver_match .kimi-plugin/plugin.json '.version'
ver_match .devin-plugin/plugin.json '.version'
ver_match gemini-extension.json '.version'
jq -e '.skills=="./skills/"' .cursor-plugin/plugin.json >/dev/null && echo "cursor skills OK" || fail=1
jq -e '.sessionStart.skill=="using-superpowers"' .kimi-plugin/plugin.json >/dev/null && echo "kimi sessionStart OK" || fail=1

# Marketplace ROLE distinction — the two files are NOT interchangeable:
#   .agents/plugins/marketplace.json = version-LESS Codex marketplace SOURCE
#     manifest (url-typed source + policy; without it Codex marketplace sources
#     find zero installable plugins).
#   .codex-plugin/marketplace.json  = versioned distributable mirroring
#     .claude-plugin (owner + author + "./" source). Catches accidental
#     convergence (e.g. a version added to the source, or the files swapped).
jq_ok .agents/plugins/marketplace.json '.plugins[0] | has("version") | not' "agents marketplace is version-less"
jq_ok .agents/plugins/marketplace.json '.interface.displayName=="beads-superpowers"' "agents marketplace has interface.displayName"
jq_ok .agents/plugins/marketplace.json '.plugins[0].source.source=="url"' "agents marketplace source is url-typed"
jq_ok .agents/plugins/marketplace.json '.plugins[0].name=="beads-superpowers"' "agents marketplace plugin name"
jq_ok .codex-plugin/marketplace.json '.plugins[0] | has("version")' "codex marketplace is versioned"
jq_ok .codex-plugin/marketplace.json '.plugins[0].source=="./"' "codex marketplace source is ./"
jq_ok .codex-plugin/marketplace.json '.owner.name != null' "codex marketplace has owner"
jq_ok .codex-plugin/marketplace.json '.plugins[0].name=="beads-superpowers"' "codex marketplace plugin name"
ver_match .codex-plugin/marketplace.json '.plugins[0].version'
ver_match .claude-plugin/marketplace.json '.plugins[0].version'

# Referenced-path resolution (catches runtime breakage that JSON validation misses)
need() {
  if [ -e "$1" ]; then
    echo "PATH OK: $1"
  else
    echo "MISSING REF: $1"; fail=1
  fi
}
# .kimi-plugin sessionStart.skill must map to a real skill dir
need "skills/$(jq -r .sessionStart.skill .kimi-plugin/plugin.json)/SKILL.md"
# hooks-cursor.json command target (run-hook.cmd) must exist
need "hooks/run-hook.cmd"
# gemini-extension.json contextFileName must resolve
need "$(jq -r .contextFileName gemini-extension.json)"

# Pi extension (.ts) — ADR-0018 best-effort bar. Pi is the only best-effort
# harness whose shipped artifact is a .ts file, not a JSON manifest, so it gets
# structural validation instead: it exports an extension, references its
# bootstrap skill, and that skill resolves on disk.
# NOTE: intentionally no syntax parse. `node --check` does NOT validate
# type-stripped .ts — it returns 0 even on stray-paren / missing-initializer
# garbage (verified 2026-07-19), so it would be a blind green check; the repo
# ships no TS toolchain (ADR-0018 §Pi) to do a real parse.
PI=".pi/extensions/superpowers.ts"
if [ -f "$PI" ]; then
  echo "PATH OK: $PI"
  if grep -q 'export default' "$PI"; then
    echo "pi export default OK"
  else
    echo "pi MISSING export default: $PI"; fail=1
  fi
  if grep -q 'using-superpowers' "$PI"; then
    echo "pi bootstrap-skill ref OK"
  else
    echo "pi MISSING bootstrap skill ref: $PI"; fail=1
  fi
  # the extension resolves the bootstrap skill at runtime — it must exist
  need "skills/using-superpowers/SKILL.md"
else
  echo "MISSING: $PI"; fail=1
fi

# Hermes plugin (.yaml) — ADR-0018 best-effort bar. Hermes is the only harness
# whose shipped manifest is YAML, not JSON, so it gets structural validation
# instead of valid_json/ver_match (both jq/python-json; python3 has no stdlib
# YAML and PyYAML is not guaranteed).
# NOTE: pre-commit's `check-yaml` hook already PARSES this file on every commit,
# so real YAML validation is covered elsewhere. The checks below deliberately
# cover only what parsing cannot: key presence, the version match, and the
# prose[] ordering edge.
# Path is RELATIVE (like $PI above) because this script cd's to $MANIFEST_ROOT.
HERMES_YAML=".hermes-plugin/plugin.yaml"
if [ -f "$HERMES_YAML" ]; then
  echo "PATH OK: $HERMES_YAML"
  for key in name version description provides_hooks; do
    if grep -q "^${key}:" "$HERMES_YAML"; then
      echo "hermes ${key}: OK"
    else
      echo "hermes MISSING KEY ${key}: $HERMES_YAML"; fail=1
    fi
  done
  if grep -q 'pre_llm_call' "$HERMES_YAML"; then
    echo "hermes pre_llm_call OK"
  else
    echo "hermes MISSING pre_llm_call: $HERMES_YAML"; fail=1
  fi

  # --- prose[] mechanism guard ---
  # bump-version.sh reads this file with `grep -F -m1 "version: "` and writes it
  # back with a first-occurrence awk substitution. A mis-match does NOT error —
  # it writes the version into the WRONG line and leaves the real one stale.
  # ONE check covers it: the first `version: ` line must BE the top-level key.
  # A "no 'version: ' above the match" check was written and DELETED as
  # tautological — the first match is by definition the first line containing
  # the substring, so nothing above it can contain it and the check could never
  # fail (caught by running the mutation, 2026-08-16). Do not reinstate it.
  hv_line=$(grep -n -F -m1 'version: ' "$HERMES_YAML" | cut -d: -f1)
  if [ -z "$hv_line" ]; then
    echo "hermes NO 'version: ' LINE: $HERMES_YAML"; fail=1
  else
    if [ "$(sed -n "${hv_line}p" "$HERMES_YAML" | cut -d: -f1)" = "version" ]; then
      echo "hermes prose-edge OK: first 'version: ' line is the top-level key"
    else
      echo "hermes PROSE-EDGE: first 'version: ' match is not the top-level key"; fail=1
    fi
    hv=$(grep -F -m1 'version: ' "$HERMES_YAML" | sed 's/.*version: *//')
    if [ "$hv" = "$VER" ]; then
      echo "VER OK: $HERMES_YAML"
    else
      echo "VER MISMATCH: $HERMES_YAML ($hv != $VER)"; fail=1
    fi
  fi
else
  echo "MISSING: $HERMES_YAML"; fail=1
fi

exit $fail
