#!/usr/bin/env bash
# tests/skills/test-diagnose-script.sh — run: bash tests/skills/test-diagnose-script.sh
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/skills/project-init/scripts/diagnose.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" && cd "$TMP"
git init -q . 2>/dev/null || true

# read-only guard: script source must contain no mutating commands
[ -f "$SCRIPT" ] || { echo "FAIL: script missing"; exit 1; }
grep -nE -- '--fix|bd init|--force|dolt push|bd create|bd update|bd close' "$SCRIPT" \
  && { echo "FAIL: mutating command in diagnose.sh"; exit 1; }

# with fake bd: all sections present
cat > "$TMP/bin/bd" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  version) printf 'bd version 1.1.0\n' ;;
  list)    printf 'ok list row\n' ;;
  vc)      printf 'commit abc123\n' ;;
  dolt)    printf 'origin git+ssh://example\n' ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/bd"

# fake git: logs every invocation to git.log, returns a dolt ref for any ls-remote
# target (both origin and the configured beads remote) so the ADR-0057 regression
# path and the configured-remote probe are both exercised in one run.
cat > "$TMP/bin/git" <<'FAKE'
#!/usr/bin/env bash
echo "git $*" >> git.log
case "$1" in
  ls-remote) printf 'abc123\trefs/heads/dolt/checkpoint\n' ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$TMP/bin/git"

mkdir -p .beads && printf 'dolt_mode: embedded\nsync.remote: "git+ssh://example-beads"\n' > .beads/config.yaml && printf '{}\n' > .beads/metadata.json
out=$(PATH="$TMP/bin:$PATH" bash "$SCRIPT")
for s in versions beads-dir config db dolt-remote; do
  echo "$out" | grep -q "== $s ==" || { echo "FAIL: section $s missing"; exit 1; }
done

# diagnose must probe the configured sync.remote (not just hardcoded git origin)
grep -q 'ls-remote git+ssh://example-beads' git.log || { echo "FAIL: diagnose did not probe configured sync.remote"; exit 1; }

# regression check: dolt refs on the CODE origin -> visible WARNING referencing ADR-0057
echo "$out" | grep -q "WARNING" || { echo "FAIL: no WARNING for dolt refs on git origin"; exit 1; }
echo "$out" | grep -q "ADR-0057" || { echo "FAIL: WARNING missing ADR-0057 reference"; exit 1; }

# bd absent: visible UNAVAILABLE, still exits 0
# reset config.yaml so this scenario (no PATH stub) doesn't drive a real git
# network call against the fake sync.remote host from the block above.
printf 'dolt_mode: embedded\n' > .beads/config.yaml
out2=$(PATH="/usr/bin:/bin" bash "$SCRIPT")
echo "$out2" | grep -q "UNAVAILABLE" || { echo "FAIL: no UNAVAILABLE hint without bd"; exit 1; }
echo "PASS: diagnose.sh"
