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

**Check 1.2 — Version consistency across 7 files:**
```bash
./scripts/bump-version.sh --check
# ALL 7 must show the same version string.
```

If versions drift, run: `./scripts/bump-version.sh <version>`

**Check 1.3 — Hook is executable and produces valid JSON:**
```bash
# Executable?
test -x hooks/session-start && echo "PASS" || echo "FAIL: chmod +x hooks/session-start"

# Valid JSON output?
bash hooks/session-start 2>&1 | python3 -m json.tool > /dev/null && echo "PASS" || echo "FAIL: hook output is not valid JSON"
```

**Check 1.4 — Hook injects both skills AND bd prime:**
```bash
output=$(bash hooks/session-start 2>&1)
echo "$output" | grep -q "using-superpowers" && echo "PASS: skills injected" || echo "FAIL: skills not injected"
echo "$output" | grep -q "beads-context\|bd prime\|Beads Workflow" && echo "PASS: bd prime injected" || echo "FAIL: bd prime not injected"
```

**Check 1.5 — .claude/settings.json points to plugin hook (not bare bd prime):**
```bash
cat .claude/settings.json | grep -q "hooks/session-start" && echo "PASS" || echo "FAIL: settings.json still uses bare bd prime, not plugin hook"
```

**Check 1.6 — Duplicate hook detection:**
```bash
cat .claude/settings.json | grep -q '"bd prime"' && echo "WARNING: bd setup claude hooks still installed — run bd setup claude --remove" || echo "PASS: no duplicate hooks"
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

**Check 2.1 — Brainstorm server tests (32 tests):**
```bash
cd tests/brainstorm-server
npm install --silent 2>/dev/null
node server.test.js 2>&1 | tail -1
# MUST show: --- Results: 32 passed, 0 failed ---
```

**Check 2.2 — WebSocket protocol tests (31 tests):**
```bash
cd tests/brainstorm-server
node ws-protocol.test.js 2>&1 | tail -1
# MUST show: --- Results: 31 passed, 0 failed ---
```

**Check 2.3 — Auth/security tests (20 tests):**
```bash
cd tests/brainstorm-server
node auth.test.js 2>&1 | tail -1
# MUST show: --- Results: 20 passed, 0 failed ---
```

**Check 2.4 — Claude Code fast skill tests (9 subtests):**
```bash
cd <repo-root>
bash tests/claude-code/run-skill-tests.sh --timeout 600 2>&1 | tail -5
# MUST show: STATUS: PASSED
```

This runs real Claude API calls (~$0.10, ~165s). Tests verify:
- Skill is recognised and loaded
- Workflow ordering (spec compliance before code quality)
- Self-review requirement documented
- Plan reading efficiency documented
- Spec reviewer scepticism documented
- Review loops documented
- Full task text provided directly (not file reference)
- Worktree requirement mentioned
- Main branch warning present

**Check 2.5 — Integration test (OPTIONAL, ~$4-5, 10-30 min):**
```bash
bash tests/claude-code/run-skill-tests.sh --integration --timeout 2400 2>&1
# Full end-to-end: creates project, executes plan via subagents, verifies output
```

Only run this before a release or after major workflow changes. It validates:
- Real subagent dispatching
- Beads (bd create/close) used for task tracking
- Implementation files created and tests pass
- Git commits made
- Correct skill namespace (`beads-superpowers:subagent-driven-development`)

**If any test fails: STOP. Fix the test failure before proceeding with the audit.**

---

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
# Orchestrator-only design: the reviewer subagent does not touch beads.
# (implementer-prompt.md is the documented EXCEPTION — it IS beads-aware by
#  design: it claims and closes its own task bead. Do not add it here.)
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
