#!/usr/bin/env bash
# test-path-case-e2e.sh — end to end, on a case-insensitive filesystem (the
# macOS APFS default): a project's planted bash, bd and sed never run through
# the real launcher, session-start or either plugin when the cwd ($PWD), a
# PATH entry or the root variable spells the project with its letters' case
# swapped. One directory then has many spellings, and only a file-identity
# comparison sees through them. Rows test-path-containment.sh shares across
# every copy of the rule; this file runs the shipped entry points whole.
#
# Shape 1: $PWD case-swapped, the PATH entry true-case, no root variable.
# Shape 2: the PATH entry case-swapped, with and without CLAUDE_PROJECT_DIR.
# A case-sensitive filesystem cannot express either shape: SKIP, visibly.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
py_bin="$(command -v python3 || true)"
node_bin="$(command -v node || true)"

E="$TMP/e2e"
TRUE="$E/proj"
SWAP="$TMP/E2E/PROJ"
MK="$E/mk"
mkdir -p "$TRUE/.git" "$TRUE/node_modules/.bin" "$E/home" "$MK"
if [ -d "$SWAP" ] && [ "$SWAP" -ef "$TRUE" ]; then :; else
  echo "SKIP: test-path-case-e2e (the filesystem at $TMP is case-sensitive: $SWAP names nothing)"
  exit 0
fi
for t in bash sed; do
  printf '#!/bin/sh\n: > "%s/%s"\nexec "%s" "$@"\n' "$MK" "$t" "$(command -v "$t")" >"$TRUE/node_modules/.bin/$t"
done
printf '#!/bin/sh\n: > "%s/bd"\necho "Memories (1):"\n' "$MK" >"$TRUE/node_modules/.bin/bd"
chmod +x "$TRUE/node_modules/.bin/"*

# A plugin root holding the real hooks, both plugins and the bootstrap skill.
PR="$TMP/pr"
mkdir -p "$PR/hooks" "$PR/skills" "$PR/.hermes-plugin" "$PR/.opencode/plugins"
cp -f "$ROOT/hooks/session-start" "$ROOT/hooks/run-hook.cmd" "$PR/hooks/"
ln -s "$ROOT/skills/using-superpowers" "$PR/skills/using-superpowers"
cp -f "$ROOT/.hermes-plugin/__init__.py" "$PR/.hermes-plugin/__init__.py"
cp -f "$ROOT/.opencode/plugins/beads-superpowers.js" "$PR/.opencode/plugins/beads-superpowers.js"
# shellcheck disable=SC2016 # python source, not shell
HERMES_PY='import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("hermes_under_test", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(m._compose_bootstrap() or m._fallback_bootstrap())'
OC_JS='import { pathToFileURL } from "node:url";
const { BeadsSuperpowersPlugin } = await import(pathToFileURL(process.argv[1]).href);
const hooks = await BeadsSuperpowersPlugin({ client: {}, directory: process.cwd() });
const out = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] };
await hooks["experimental.chat.messages.transform"]({}, out);
console.log(out.messages[0].parts[0].text);'

n=0
# run <name> <PWD> <first PATH entry> <extra env or ""> <command...>: the
# project's tools must leave no marker, and the bootstrap must be injected.
run() {
  local name="$1" pw="$2" e="$3" x="$4" got out
  shift 4
  local -a extra=()
  if [ -n "$x" ]; then extra=("$x"); fi
  n=$((n + 1))
  mkdir -p "$E/xdg$n"
  rm -f "$MK"/*
  out=$(cd "$TRUE" && env -i HOME="$E/home" XDG_RUNTIME_DIR="$E/xdg$n" PWD="$pw" PATH="$e:/usr/bin:/bin" \
    ${extra[@]+"${extra[@]}"} "$@" </dev/null 2>/dev/null)
  got=$(cd "$MK" && printf '%s ' *)
  if [ "$got" = "* " ] && [[ "$out" == *"Production-Grade Doctrine"* ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    echo "  planted that ran: [${got%\* }] out=$(printf '%s' "$out" | head -c 120)"
    fail=1
  fi
}

# Shape 1, then Shape 2 without and with a root variable.
for shape in "shape 1, PWD case-swapped|$SWAP|$TRUE/node_modules/.bin|" \
             "shape 2, PATH entry case-swapped|$TRUE|$SWAP/node_modules/.bin|" \
             "shape 2, CLAUDE_PROJECT_DIR set|$TRUE|$SWAP/node_modules/.bin|CLAUDE_PROJECT_DIR=$TRUE" \
             "shape 2, CLAUDE_PROJECT_DIR case-swapped too|$TRUE|$SWAP/node_modules/.bin|CLAUDE_PROJECT_DIR=$SWAP"; do
  IFS='|' read -r label pw e x <<<"$shape"
  for sh_bin in /bin/sh /bin/dash /bin/bash; do
    if [ ! -x "$sh_bin" ]; then continue; fi
    # shellcheck disable=SC2016 # $0 is expanded by the inner shell
    run "launcher, $sh_bin -c (harness shape) [$label]" "$pw" "$e" "$x" CLAUDE_PLUGIN_ROOT="$PR" "$sh_bin" -c '"$0" session-start' "$PR/hooks/run-hook.cmd"
  done
  run "session-start direct, /bin/bash [$label]" "$pw" "$e" "$x" CLAUDE_PLUGIN_ROOT="$PR" /bin/bash "$PR/hooks/session-start"
  if [ -n "$py_bin" ]; then
    run "Hermes plugin [$label]" "$pw" "$e" "$x" "$py_bin" -I -c "$HERMES_PY" "$PR/.hermes-plugin/__init__.py"
  fi
  if [ -n "$node_bin" ]; then
    run "OpenCode plugin [$label]" "$pw" "$e" "$x" "$node_bin" --input-type=module -e "$OC_JS" "$PR/.opencode/plugins/beads-superpowers.js"
  fi
done
if [ -z "$py_bin" ]; then echo "SKIP: Hermes rows (python3 not found)"; fi
if [ -z "$node_bin" ]; then echo "SKIP: OpenCode rows (node not found)"; fi
exit "$fail"
