# Check Suite: Phases 1–3 (Infrastructure, Tests, Content Integrity)

Open when executing the audit's check phases. Runnable checks, moved verbatim from `SKILL.md` (3jot).

### Phase 1: Plugin Infrastructure Health

Verify the plugin itself is structurally sound before checking content.

**Check 1.1 — Plugin manifest validation:**
```bash
claude plugin validate .claude-plugin/plugin.json
# MUST show: ✔ Validation passed
```

If validation fails, the plugin CANNOT be installed. Fix before proceeding.

**Check 1.2 — Version consistency across the 9 declared surfaces:**
```bash
./scripts/bump-version.sh --check
# ALL 9 surfaces declared in .version-bump.json must show the same version string.
```

If versions drift, run: `./scripts/bump-version.sh <version>`

**Checks 1.3 + 1.4 — Hook is executable, emits valid JSON, and injects skills + beads context:**

Invoke the hook **exactly once** and assert everything against that single capture.
`hooks/session-start:151-189` carries an event-scoped dedup marker (jb3u) with a **60-second
TTL**; with no stdin JSON the session id falls back to `nosid-$PPID`, so every invocation from
one shell shares one marker and the **second** call within 60s is suppressed to `{}`. Splitting
these into two invocations makes 1.4 fail deterministically against a perfectly healthy hook.
A pause does not help — the TTL is 60s, not a scheduling race (`beads-superpowers-oxemv.4`).

```bash
test -x hooks/session-start && echo "PASS: executable" || echo "FAIL: chmod +x hooks/session-start"

output=$(bash hooks/session-start 2>&1)   # ONCE — see the dedup note above
printf '%s' "$output" | python3 -m json.tool > /dev/null && echo "PASS: valid JSON" || echo "FAIL: hook output is not valid JSON"
printf '%s' "$output" | grep -q "using-superpowers" && echo "PASS: skills injected" || echo "FAIL: skills not injected"
printf '%s' "$output" | grep -q "beads-context\|bd prime\|Beads Workflow" && echo "PASS: beads context injected" || echo "FAIL: beads context not injected"
```

A 2-byte (`{}`) capture is the dedup signature, not a defect. Before filing any hook finding,
clear the marker and re-run: `rm -f "${XDG_RUNTIME_DIR:-/tmp}/beads-superpowers-$(id -u)"/m-nosid-*`

**Check 1.5 — .claude/settings.json points to plugin hook (not bare bd prime):**
```bash
if [ ! -f .claude/settings.json ]; then
  echo "SKIP 1.5: .claude/settings.json absent (gitignored by design, .gitignore:25)"
else
  cat .claude/settings.json | grep -q "hooks/session-start" && echo "PASS" || echo "FAIL: settings.json still uses bare bd prime, not plugin hook"
fi
```

**Check 1.6 — Duplicate hook detection:**
```bash
if [ ! -f .claude/settings.json ]; then
  echo "SKIP 1.6: .claude/settings.json absent (gitignored by design, .gitignore:25)"
else
  cat .claude/settings.json | grep -q '"bd prime"' && echo "WARNING: bd setup claude hooks still installed — run bd setup claude --remove" || echo "PASS: no duplicate hooks"
fi
```

**Check 1.7 — Skills count:**
```bash
dirs=$(ls -d skills/*/ | wc -l)
md=$(find skills -maxdepth 2 -name SKILL.md | wc -l)
echo "Skills: $dirs dirs, $md SKILL.md"
[ "$dirs" = "$md" ] && echo "PASS" || echo "FAIL: $dirs skill dirs but $md SKILL.md files"
# Source of truth (guard): ./scripts/check-skill-count.sh
```

**Check 1.8 — LICENSE attribution:**
```bash
grep -q "Dillon Frawley" LICENSE && echo "PASS" || echo "FAIL: LICENSE does not have correct attribution"
grep -q "Jesse Vincent" LICENSE && echo "FAIL: LICENSE still has upstream author" || echo "PASS"
```

---

### Phase 2: Test Execution

Run ALL runnable tests. Tests are the ground truth — if they fail, nothing else matters.

**Checks 2.1–2.3 — Brainstorm server suites: assert the EXIT CODE, never a piped string.**

`node <suite> | tail -1` cannot detect failure: the pipe discards the exit status, and a suite
that dies mid-run leaves a `PASS:` line last, so `tail -1` reads green off a red run. Measured
2026-08-15 on `server.test.js` — 3 failures in 8 runs, every one of them invisible to the old
form (`beads-superpowers-oxemv.3`). Assert the status, and print the summary only as context.

```bash
cd tests/brainstorm-server
npm install --silent 2>/dev/null
for suite in server.test.js ws-protocol.test.js auth.test.js; do
    out=$(node "$suite" 2>&1); rc=$?
    printf '%s: %s (exit %s)\n' "$suite" "$(printf '%s' "$out" | grep -E 'Results:' | tail -1)" "$rc"
    [ "$rc" -eq 0 ] && echo "  PASS" || { echo "  FAIL"; printf '%s\n' "$out" | tail -20; }
done
```

Expected: `server.test.js` 33 passed, `ws-protocol.test.js` 31, `auth.test.js` 20 — all exit 0.
Note `npm test` chains the three with `&&`, so a red first suite silently skips the other two;
run them individually (as above) whenever you need per-suite evidence.

**Check 2.4 — LLM behavioral suites:** removed in the 2026-07 fat audit — skill-behavior measurement lives in the external eval-harness project; run its suite there if behavioral verification is needed.

### Phase 3: Content Integrity

Verify the beads integration is complete and no stale references remain.

**Check 3.1 — Zero active TodoWrite references:**
```bash
bash scripts/check-todowrite.sh && echo "PASS: zero active TodoWrite" || echo "FAIL: see output above"
```

The only allowed TodoWrite references are prohibitions ("Do NOT use TodoWrite", "TodoWrite is forbidden") and this audit skill's own grep patterns.

**Check 3.2 — Zero stale docs/superpowers/ paths:**
```bash
results=$(grep -rn "docs/superpowers" skills/ tests/ | grep -v "auditing-upstream-drift")
[ -z "$results" ] && echo "PASS" || echo "FAIL: stale paths found: $results"
```

All paths should use `.internal/`.

**Check 3.3 — Zero stale skill namespace references:**
```bash
results=$(grep -rn '"superpowers:' skills/ tests/ | grep -v "beads-superpowers:")
[ -z "$results" ] && echo "PASS" || echo "FAIL: stale namespaces: $results"
```

**Check 3.4 — Zero stale plugin-dir paths:**
```bash
results=$(grep -rn "/path/to/superpowers" tests/)
[ -z "$results" ] && echo "PASS" || echo "FAIL: stale plugin paths: $results"
```

**Check 3.5 — Zero TodoWrite in tests:**
```bash
results=$(grep -rn "TodoWrite" tests/ | grep -v "tests/skills/test-todowrite-gate.sh")
[ -z "$results" ] && echo "PASS" || echo "FAIL: TodoWrite in tests: $results"
```

**Check 3.6 — Beads command density (must be 30+):**
```bash
count=$(grep -rn "bd create\|bd close\|bd ready\|bd update\|bd dep\|bd dolt" skills/ | wc -l)
echo "Beads command references in skills: $count (minimum: 30)"
[ "$count" -ge 30 ] && echo "PASS" || echo "FAIL: insufficient beads integration"
```

**Check 3.7 — Reviewer prompt must NOT reference beads:**
```bash
# Orchestrator-only design: subagents (implementer and reviewer alike) do not
# touch beads. Only the controller owns the bead lifecycle.
for f in skills/subagent-driven-development/task-reviewer-prompt.md; do
    count=$(grep -cE "bd create|bd close|bd update|bd ready" "$f" 2>/dev/null) || count=0
    [ "$count" -eq 0 ] && echo "PASS: $(basename $f) clean" || echo "FAIL: $(basename $f) has $count bd references"
done
```

**Check 3.8 — Convention-block sync (verbatim canonical blocks):**
```bash
bash scripts/check-convention-sync.sh
```

The cross-cutting convention blocks (Capture gate, memory convention) are duplicated across skills by design and MUST be byte-identical at every site. Any divergent or missing copy fails this check. (The doctrine floor is NOT byte-duplicated: it is a canonical block in `using-superpowers` plus per-skill woven floor lines — see the Known Deliberate Divergences table.)

### Registered upstream divergence — stripped detritus (ADR-0048 exception, slice-3)

The fork does NOT ship upstream superpowers' non-functional bundled artifacts (eval fixtures, creation logs). Removed in slice-3: `skills/systematic-debugging/{CREATION-LOG.md, test-academic.md, test-pressure-1.md, test-pressure-2.md, test-pressure-3.md}`. A re-sync from upstream must NOT re-introduce them. The genuine upstream reference files (condition-based-waiting*, defense-in-depth.md, root-cause-tracing.md, find-polluter.sh) are retained verbatim.
