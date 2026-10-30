#!/usr/bin/env bash
# Regression: a failing brainstorm-server test must not leave its server running.
# Runs a temp copy of server.test.js with one injected failing test, then asserts
# nothing still listens on its TEST_PORT (checked by pid).
set -uo pipefail
if ! command -v lsof >/dev/null 2>&1; then
  echo "SKIP: lsof not installed — teardown regression not run"; exit 0
fi
cd "$(dirname "$0")" || exit 1
port="$(sed -n 's/^const TEST_PORT = \([0-9]*\);.*/\1/p' server.test.js)"
[ -n "$port" ] || { echo "FAIL: cannot read TEST_PORT"; exit 1; }
tmp="teardown-forced-fail.tmp.test.js"
trap 'rm -f "$tmp"' EXIT
sed 's|// ========== Summary ==========|await test("forced failure", () => { throw new Error("forced"); });|' server.test.js > "$tmp"
grep -q 'forced failure' "$tmp" || { echo "FAIL: injection marker missing in server.test.js"; exit 1; }
node "$tmp" >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL: injected failing test did not fail the run"; exit 1; }
sleep 1
pids="$(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null || true)"
if [ -n "$pids" ]; then
  echo "FAIL: server leaked after a failing test (pid $pids)"; printf '%s\n' "$pids" | xargs kill 2>/dev/null
  exit 1
fi
echo "PASS: failing test left no server process on port $port"
