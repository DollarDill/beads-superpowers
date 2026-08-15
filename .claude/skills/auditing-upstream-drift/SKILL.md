---
name: auditing-upstream-drift
description: Use when checking if beads-superpowers is outdated, before a plugin release, or when auditing for missing capabilities — covers upstream drift, test execution, documentation, plugin health, and content integrity
---

# Auditing Upstream Drift

> **Maintainer-only skill for the [beads-superpowers](https://github.com/DollarDill/beads-superpowers) repository — not distributed.**
> Before doing anything else: if the current repo is not beads-superpowers (no `.claude-plugin/plugin.json` whose `name` is `beads-superpowers`), say so and STOP — this skill audits that repo against its upstreams and is useless anywhere else.

This is the quality gate for the beads-superpowers plugin. It verifies everything — upstream staleness, test pass rates, documentation accuracy, plugin manifest validity, hook functionality, content integrity, and beads integration completeness.

**Iron Law:** NO PLUGIN RELEASE WITHOUT A FULL AUDIT FIRST. Audit findings with security or material-risk impact are never downgraded to make a release, and phases are never skipped for a date (Production-Grade Doctrine).

## When to Use

- Before any plugin version bump or release
- Monthly (or after upstream releases of superpowers or beads)
- When a user reports a skill behaves differently than expected
- When beads adds new CLI features that skills should leverage
- After any bulk refactoring of skills or tests
- After merging upstream changes

## Upstream Sources

| Source | Repository | Our Baseline | What We Track |
|--------|-----------|-------------|---------------|
| **Superpowers** | [obra/superpowers](https://github.com/obra/superpowers) | v6.3.0 | Skills content, new skills, hook structure, plugin manifest |
| **Beads** | [gastownhall/beads](https://github.com/gastownhall/beads) | v1.2.2 | CLI commands, new features, bd prime format, deprecations |

## Known Deliberate Divergences

These shared skills intentionally differ from upstream superpowers. When Phase 5 (Check 5.3) flags them as CHANGED, that is expected — do **not** revert them toward upstream. Adopt only upstream changes that don't reverse these decisions.

| Area / Skill | We do | Upstream does | Why |
|---|---|---|---|
| **All shared skills** | `bd` task tracking — beads is the ledger | `TodoWrite` / markdown TODOs | The fork's reason for existence: cross-session persistence |
| **using-git-worktrees, finishing-a-development-branch** | `bd worktree` Iron Law; reject native-tool-first selection | native worktree tool first → `.worktrees/` → raw `git worktree` | native-first bypasses beads-DB sharing across worktrees (ADR-0014; audit finding #6) |
| **finishing-a-development-branch** | Land the Plane (`bd close` → `bd dolt push` → `git push`) | no session-close ritual | core to the beads workflow |
| **subagent-driven-development** | beads is the durable ledger; Parallel Batch Mode kept; `bd merge-slot` optional | markdown progress ledger | beads survives compaction; single orchestrator already serializes merges (ADR-0013, ADR-0012) |
| **using-superpowers** | Claude Code tool names + per-CLI `references/` maps (trimmed to harness-specific content, superset of upstream's 3-file set) | fully vendor-neutral tool vocabulary | we ship multi-CLI adapters, not one neutral vocabulary (ADR-0006) |
| **Beads integration** | CLI-only: call `bd` directly in skills + one SessionStart hook composing beads context (curated memories + a `bd prime` pointer); no beads Claude plugin or beads-mcp server | Claude plugin + MCP server | Lowest overhead; full `bd` command coverage; matches beads' own "CLI + hooks when shell is available" guidance (ADR-0017) |
| **brainstorming, writing-plans** | stress-test (a fork-only skill) is offered at the approval gate via a 3-option "Approved + stress-test" gate folded into the upstream Approved/Needs-changes review gate | 2-option review gate; no stress-test (stress-test does not exist upstream) | stress-test is one of our 7 fork-unique skills; offering it at every spec/plan gate is intended fork behavior (ADR-0020) |
| **using-superpowers + judgment/gate skills (doctrine class)** | fork-only Production-Grade Doctrine: canonical `## Production-Grade Doctrine` block in `using-superpowers` PLUS self-contained woven doctrine-floor lines (incl. the security floor) in judgment/gate skills | no such doctrine (obra/superpowers has none) | intended fork behavior (ADR-0023/0036/0040); on re-sync PRESERVE every woven doctrine-floor line; mark SKIP, not Conflict |
| **using-superpowers + question-gate skills (ask-user class)** | fork-only ask-user convention: `## Asking the User` block in `using-superpowers`, self-contained consent lines at the 3 destructive gates (finishing-a-development-branch, document-release, using-git-worktrees), adapt parentheticals on the 6 JSON gate lead-ins, quirk rows in `references/{opencode,codex,pi}-tools.md` | upstream uses bare generic phrasing with no convention block (zero in-skill tool refs) | intended fork behavior (ADR-0041); on re-sync PRESERVE all four elements; mark SKIP, not Conflict |
| **All shared skills (namespace)** | cross-skill references use `beads-superpowers:<skill>` | bare `superpowers:<skill>` | upstream's bare namespace points at the upstream plugin; in our fork it must carry our plugin name or it resolves to the wrong plugin (intended; mark SKIP, not Conflict) |
| **brainstorming** | brainstorm session dir + auth-token files live under `.internal/brainstorm/` (self-ignored) | upstream uses `.superpowers/brainstorm/` | one canonical `.internal/` scratch root (spec 2026-06-30); `server.cjs` logic otherwise upstream-verbatim apart from the two rows below — do not revert the path on re-sync |
| **brainstorming `server.cjs`** (branding) | `SUPERPOWERS_BRAND_IMAGE_URL = ''`, brand text `beads-superpowers v<ver>`, link to `DollarDill/beads-superpowers`, no telemetry logo | Prime Radiant logo, `Superpowers v<ver>`, link to `obra/superpowers` | fork attribution; upstream escaping preserved verbatim (defense-in-depth). Mark SKIP, not Conflict |
| **brainstorming `server.cjs`** (readiness ordering) | writes `state/server-info` **before** printing the `server-started` announcement, best-effort in `try/catch` | prints the announcement first, then writes the file (still the order at v6.3.0:686-688) | `server-started` is the readiness signal every consumer waits on, so announcing first makes each consumer race the write. Measured 2026-08-15: server-info absent at the announcement instant in **20/20** spawns, which flaked `tests/brainstorm-server/server.test.js` at ~37% and — because `npm test` chains the three suites with `&&` — silently skipped the ws-protocol and auth suites on every red run. Pinned by the test `server-info exists at the instant server-started is announced`. Upstream bug, fixed here first; do NOT revert on re-sync. Mark SKIP, not Conflict (`beads-superpowers-oxemv.3`) |
| **Codex SessionStart hook** | keep it — still fires `using-superpowers` bootstrap + composed beads context | v6.1.0 removed theirs ("Codex reliably triggers skills on its own, and the bootstrap hook made the UX worse rather than better") | ours also carries composed beads context injection (curated memories + a `bd prime` pointer), not just the skill bootstrap upstream deemed redundant (ADR-0039, 2026-07-02) |
| **SessionStart matcher** | `startup|resume|clear|compact` | `startup|clear|compact` | added in bd-3ogl.2 to cover session resumption |
| **writing-skills** | not shipped — removed 2026-07-10 (e4w8) | ships the writing-skills meta-skill | upstream maintenance weight; Check 5.2 will list it as upstream-new — mark SKIP |
| **.pi/extensions/superpowers.ts** | appends composed beads context (`bd prime` exec) + `beads-superpowers:` bootstrap marker | bootstrap-only extension | beads context is the fork's reason to exist |
| **test-driven-development** `spec-backed` floor | Fork-only design-artifact precondition before code | no design-artifact precondition | Do NOT file as "revert toward upstream" — it is the default-install design gate, pinned in `KERNEL_MAP` |
| **.codex-plugin/marketplace.json** | ships it (version-synced mirror of .claude-plugin's) | no such file | kept deliberately for Codex marketplace flows |
| **OpenCode plugin** | upstream's `.opencode/plugins/` file as base + minimal beads graft (composer bootstrap, compaction re-injection, pointer fallback) | `superpowers.js` static-bootstrap transform | beads context is the fork's core; layout/mechanism otherwise upstream-verbatim |
| **subagent-driven-development** (fix rounds) | fresh implementer dispatch every fix round | resume the implementer rounds 1–3, fresh one tier up at 4–5; v6.3.0 hardened this into "never dispatch a fresh implementer on the theory that a spawned agent cannot be messaged again; on V2 it always can" | **Independence first:** a fresh implementer is an external signal — the author of a defect is the worst reader of it, and resume invites defending the earlier attempt rather than re-deriving from the findings. Harness neutrality is the second reason, and it is narrower than it used to be: upstream's V2 resumption claim is ACCEPTED AS TRUE (verified against v6.3.0's `references/codex-tools.md`), so "most harnesses may lack it" no longer carries this row — a lifecycle that behaves differently across supported harnesses is still not one lifecycle, but the capability gap is smaller than when ADR-0064 was written. Do not read upstream's hardened wording as refuting us: it refutes a rationale we no longer lead with. Mark SKIP, not Conflict (ADR-0064, `beads-superpowers-oxemv.15`) |
| **subagent-driven-development** (workspace) | SDD workspace, task briefs, and review packages live under `.internal/sdd/<plan-basename>/` (self-ignored) | `.superpowers/sdd/<plan-basename>/` | one canonical `.internal/` scratch root (spec 2026-06-30); upstream's per-plan workspace shape adopted, path not — do not revert the path on re-sync |
| **subagent-driven-development** (adjudication boundary) | controller MAY rule **only** where the spec unambiguously settles it, and every ruling cites its spec location in the ledger (`Ruling: … — settled by … — …`); everything else escalates. Must-stop overrides may-rule wherever both apply, and a **security finding is never rulable and never parkable**. Upstream's exhaustive "Rulings I made" final surfacing IS adopted | v6.3.0 "Rulings, not stalls": the controller rules on conflicts, plan defects, plan-mandated findings **and load-bearing breaker findings**, stopping only for four classes (irreversible/destructive, security-sensitive, side effects outside the worktree, a plan so broken every path is a guess) | ADR-0023 is tiered: the security floor is hard, but shortcuts/descope are a strong default the agent never takes unilaterally. Ruling *from the spec* is reading the binding authority, not descoping, so it stays inside the doctrine; deciding a requirement isn't worth meeting does not. Upstream's model hands the controller the soft-tier waiver ADR-0023 reserves for the human, and its may-rule list structurally reaches security findings. Adopt the ledger + surfacing, reject the autonomy shift. Mark SKIP, not Conflict (`beads-superpowers-oxemv.5`) |
| **subagent-driven-development** (severity) | severity preserved at the breaker; security findings block the epic and are never parkable | findings flattened into one disposition list | the reviewer's own security floor says a rationale never downgrades a regression |
| **subagent-driven-development** (re-review) | PASS requires the reviewer's verdict AND a green full suite | reviewer's verdict alone | a fix-diff reviewer structurally cannot see out-of-diff regressions |
| **subagent-driven-development** (fix context) | fix round carries only the latest report section | full prior report | full history is quadratic across rounds and re-anchors fresh eyes on failed approaches |
| **test-driven-development** `writing-good-tests.md` | fork retains three classes of source-text assertion: **absence-of-defect pins** (fail only if a named defect returns), **security-floor pins** (credential prefixes the handoff skill must redact), and **CHANGE-DETECTOR presence pins** (~27 explicitly-labelled pins across `tests/skills/test-getting-up-to-speed-contract.sh`, `test-kb-triggers.sh`, and `test-session-handoff-contract.sh`, retained under the deletion bar — a pin may go only once converted to behavioral or covered by a bead in the external `cc-eval` tracker). Adoption also drops upstream's `(superpowers:writing-skills)` parenthetical — a dead cross-plugin reference, since `writing-skills` isn't shipped here and a bare `superpowers:` namespace resolves to the upstream plugin — the file's one deliberate deviation from byte-identical | upstream's Warning Signs forbid all source-text assertions | our shipped artifacts *are* prose that instructs agents, and no eval-harness consumes them yet; deleting the redaction pins would be an automatic Reject under the audit rubric's security floor, and deleting the change-detector pins on faith would convert a false alarm into false silence on real breakage. Adopt the six rules and the traps; keep these three classes. Mark SKIP, not Conflict |
| **All shared skills** (guardrail heading) | guardrail sections are named `## Red Flags` | v6.2.0 renamed several to `## Common Rationalizations` (`using-git-worktrees`, `requesting-code-review`) | `## Red Flags` is a literal alternate in `scripts/check-guardrail-floor.sh`'s `PAT`; renaming a heading silently drops that skill's guardrail count and can trip — or worse, quietly relax — the floor. Adopt upstream's *rows*, keep our *heading*. Mark SKIP, not Conflict |
| **brainstorming, writing-plans** (companion files) | not shipped — no `spec-document-reviewer-prompt.md` / `plan-document-reviewer-prompt.md` | still ships both files (v6.3.0, `skills/brainstorming/` and `skills/writing-plans/`) | orphans upstream — nothing dispatches them; upstream's own `writing-plans/SKILL.md` Self-Review section says self-review is "not a subagent dispatch"; upstream RELEASE-NOTES v5.0.6 (2026-03-24) records their deprecation in favor of inline self-review (~25 min subagent-review overhead vs. ~30s self-review, no measurable quality difference). Check 5.4 will list them as new companion files every audit — mark SKIP (known-dead), not missing capability |
| **using-superpowers** `references/codex-tools.md` (fix rounds) | adopts upstream v6.3.0's multi-agent guidance — V1/V2 lifecycle, `spawn_agent {fork_turns:"none"}`, set `model` AND `reasoning_effort` together, bounded `wait_agent` stretches, "trust your actual tool list over any table" — but REPLACES its fix-round instruction with the fork's fresh-dispatch rule, stated inline in the file | "resume the implementer with `followup_task`… Never dispatch a fresh implementer on the theory that a spawned agent cannot be messaged again; on V2 it always can" | ADR-0064. Upstream's claim about V2 capability is accepted as true — resumption does work — so the divergence rests on the independence argument, not harness capability: fresh eyes strengthen external-signal verification and avoid the author defending their own defect. The carve-out is stated INLINE in codex-tools.md rather than as a pointer, because a Codex controller reads that file and not this table. Mark SKIP, not Conflict (`beads-superpowers-oxemv.12`) |
| **finishing-a-development-branch** (refused worktree removal) | adopts upstream v6.3.0's refusal protocol — never `--force` on your own initiative, show `git -C "$WORKTREE_PATH" status --porcelain -uall`, offer commit / move / delete — but expressed against **`bd worktree remove`**, and distinguishing the two refusal causes (unpushed commits are recoverable from the branch; modified/untracked files are not recoverable from anywhere) | same protocol, expressed against raw `git worktree remove` | the fork's `bd worktree` Iron Law (ADR-0014) forbids raw git worktree commands, so the rule is adopted and the command vocabulary translated. The `git -C … status` call carries over verbatim because it is a read, not a worktree operation. Mark SKIP, not Conflict (`beads-superpowers-oxemv.9`) |
| **brainstorming** (three-path router) + **test-driven-development** (bounded satisfier) | adopts upstream v6.3.0's spike / bounded / architectural router, the one-way ratchet and the 7-row Red Flags table, with three fork adaptations: (1) the **bounded path files ONE task bead** carrying the approved design — `writing-plans` is still skipped and no plan document is produced, but "`bd` for ALL task tracking" holds; (2) the 3-option **"Approved + stress-test" gate stays on the ARCHITECTURAL path only** (spike/bounded get a plain approve gate); (3) `test-driven-development`'s spec-backed floor names the bounded bead as an explicit satisfier | same router, but bounded work is tracked by nothing and upstream has neither beads, a stress-test skill, nor a spec-backed floor | upstream cannot have these collisions: it has no task ledger, so "no plan document" costs it nothing, whereas here it would put work outside `bd`; and its bounded path would walk straight into our spec-backed floor, which enumerates its satisfiers and did not list a bead — leaving every bounded task to stall or rationalize past a bright line. The `## Red Flags` heading is retained (not upstream's alternate) so `check-guardrail-floor.sh` keeps counting it. Mark SKIP, not Conflict (`beads-superpowers-oxemv.7`) |

When a CHANGED skill from Phase 5 matches a row here, mark it **SKIP (deliberate divergence)** in the report — not drift.

## The Audit Process

You MUST create an audit bead and complete ALL 8 phases in order:

```bash
bd create "Audit: full plugin health check" -t chore -p 1
bd update <audit-id> --claim
```

---

**Check suite — Phases 1–3 (Plugin Infrastructure Health, Test Execution, Content Integrity):** the runnable check commands (manifests, versions, tests, content-integrity greps) live in [references/check-suite.md](references/check-suite.md) — open when executing the audit's check phases.

Done when: every check in Phases 1–3 reports PASS, or each FAIL is fixed before continuing.

---

### Phase 4: Progressive Skill Chain Integrity

The skills form a pipeline. Every link must be intact.

```bash
echo "=== Progressive Skill Chain ==="

# brainstorming → writing-plans (terminal state)
grep -q "writing-plans" skills/brainstorming/SKILL.md && echo "PASS: brainstorming → writing-plans" || echo "FAIL"

# writing-plans → subagent-driven-development OR executing-plans
grep -q "subagent-driven-development" skills/writing-plans/SKILL.md && echo "PASS: writing-plans → subagent-driven-dev" || echo "FAIL"
grep -q "executing-plans" skills/writing-plans/SKILL.md && echo "PASS: writing-plans → executing-plans" || echo "FAIL"

# subagent-driven-development → finishing-a-development-branch
grep -q "finishing-a-development-branch" skills/subagent-driven-development/SKILL.md && echo "PASS: subagent-driven-dev → finishing" || echo "FAIL"

# executing-plans → finishing-a-development-branch
grep -q "finishing-a-development-branch" skills/executing-plans/SKILL.md && echo "PASS: executing-plans → finishing" || echo "FAIL"

# finishing-a-development-branch has Land the Plane
grep -q "Land the Plane" skills/finishing-a-development-branch/SKILL.md && echo "PASS: finishing has Land the Plane" || echo "FAIL"

# using-superpowers has ## Beads section
grep -q "^## Beads" skills/using-superpowers/SKILL.md && echo "PASS: bootstrap has beads awareness" || echo "FAIL"

# verification-before-completion has Beads Completion section
grep -q "Beads Completion" skills/verification-before-completion/SKILL.md && echo "PASS: verification has beads completion" || echo "FAIL"
```

Done when: every chain-link check reports PASS, or each FAIL is fixed.

---

### Phase 5: Upstream Superpowers Drift

Clone upstream and compare.

```bash
# FULL clone — NOT --depth 1. Phase 5 diffs upstream tag ranges, which needs tags and history.
git clone https://github.com/obra/superpowers.git /tmp/superpowers-upstream
```

**Check 5.1 — Version gap (tags, not just package.json):**
```bash
git -C /tmp/superpowers-upstream tag --sort=-creatordate | head -10
upstream_ver=$(grep '"version"' /tmp/superpowers-upstream/package.json | grep -o '[0-9.]*')
echo "Upstream: v$upstream_ver | Our baseline: v6.3.0"
```

Note **every** tag between our baseline and the newest one — the delta may span several releases,
and Check 5.3's diff range must cover all of them.

**Check 5.2 — New skills in upstream:**
```bash
diff <(ls /tmp/superpowers-upstream/skills/) <(ls skills/) | grep "^<"
# Lines starting with < are skills upstream has that we don't
```

For each new skill: assess if relevant (skip platform-specific ones).

**Check 5.3 — Content changes in shared skills. Diff `upstream-old..upstream-new`, NEVER fork vs upstream-new.**

> **This is the audit's most dangerous check, and it used to be wrong.** Diffing our tree against
> upstream's new tag conflates two entirely different things: (a) genuine upstream changes we
> should consider adopting, and (b) pre-existing fork drift upstream never touched. Findings then
> ship with a **false provenance** — "upstream v6.2.0 did X" — and a subagent handed such a finding
> cannot see the audit or the upstream delta, so it implements whatever the brief says and produces
> a plausible diff that "fixes" a non-problem. Six findings in the v6.2.0 sweep were misattributed
> exactly this way (`vctf4.6`, `.11`, `.17`, `.19`, `.20`, `.24`); three of them do not appear in
> the real `v6.1.1..v6.2.0` diff at all. Root cause: `beads-superpowers-ivcop`.

```bash
OLD=v6.3.0   # our current baseline (the Upstream Sources table above)
NEW=<newest> # newest upstream tag from Check 5.1

# 1. What upstream ACTUALLY changed in the range — this is the only source of drift findings:
git -C /tmp/superpowers-upstream diff "$OLD".."$NEW" --stat
git -C /tmp/superpowers-upstream log --oneline "$OLD".."$NEW"

# 2. Read each changed path's real hunks before judging it:
git -C /tmp/superpowers-upstream diff "$OLD".."$NEW" -- skills/<name>/SKILL.md
```

Then, and only then, check each **genuinely changed** path against our tree to see whether we
already carry the change, diverge from it deliberately, or should adopt it.

A file that differs from our fork but has **no hunk in the `OLD..NEW` diff** is *not* drift — it is
either a registered divergence or pre-existing fork drift, and it is **not** an upstream finding.
Do not file it as one. If you believe it should change anyway, that is your own recommendation:
say so in your own name, never in upstream's.

For changed skills, categorise each:
- **Safe merge**: Change doesn't touch our beads-integrated sections
- **Conflict**: Change touches our modified sections → manual review
- **New content**: New sections added → assess and add with beads awareness

**Before categorising, check [Known Deliberate Divergences](#known-deliberate-divergences)** — skills listed there are *expected* to be CHANGED; mark them SKIP (deliberate divergence), not Conflict.

**Check 5.4 — New companion files:**
```bash
for dir in /tmp/superpowers-upstream/skills/*/; do
    name=$(basename "$dir")
    if [ -d "skills/$name" ]; then
        new_files=$(diff <(ls "$dir" 2>/dev/null | sort) <(ls "skills/$name" 2>/dev/null | sort) | grep "^<" | sed 's/^< //')
        [ -n "$new_files" ] && echo "NEW FILES in $name: $new_files"
    fi
done
```

**Check 5.5 — Hook and manifest changes:**
```bash
diff /tmp/superpowers-upstream/hooks/hooks.json hooks/hooks.json | head -20
diff /tmp/superpowers-upstream/.claude-plugin/plugin.json .claude-plugin/plugin.json | head -20
```

Our hook is intentionally different (composes beads context — curated memories + a `bd prime` pointer). Check for structural changes, new hook types, or new manifest fields.

```bash
rm -rf /tmp/superpowers-upstream
```

Done when: Checks 5.1–5.5 are run and every CHANGED skill is categorised (Safe merge / Conflict / New content / SKIP deliberate divergence).

---

### Phase 6: Upstream Beads Drift

Check if beads has new capabilities our skills should use.

**Check 6.1 — Beads version (resolve UPSTREAM first, THEN the local binary):**

The local binary reports what is **installed here**, never what **shipped**. Probing it first
makes this phase report zero drift by construction whenever the install is stale — the same
defect class as `beads-superpowers-ivcop` in Phase 5. Measured 2026-08-15: local `bd` was
v1.1.2 while upstream had shipped v1.2.0, v1.2.1 and v1.2.2, so a local-first Phase 6 would
have reported "no drift" and missed a schema-bricking hazard entirely.

```bash
# 1. What actually shipped, newest first:
gh api repos/gastownhall/beads/releases --jq '.[0:6][] | "\(.tag_name)  \(.published_at)  \(.name)"'
# 2. What is installed here:
bd version
```

State explicitly when the local binary is older than the latest release, and **read the release
notes across `baseline..latest`** before concluding anything. A version bump is not evidence of
a capability change: v1.2.2 re-released the v1.1.2 code verbatim after v1.2.0/v1.2.1 were
published by accident, so its higher number carries **no** new features. Conversely, do not
assume a fix has landed just because the number moved (`beads-superpowers-oxemv.2`).

**Check 6.2 — New or changed bd commands:**
```bash
bd --help 2>&1 | head -60
# Look for new commands not in our skills' Quick Reference tables
```

**Check 6.3 — bd prime format:**
```bash
bd prime 2>&1 | head -20
# Compare structure against what hooks/session-start expects
```

**Check 6.4 — New beads features to watch:**
- New dependency types → update `bd dep add` references
- New issue types → update `bd create -t` references
- New status codes → update lifecycle references
- New CLI flags → update quick reference tables
- Changes to gate/molecule/formula system → assess skill impact
- **Version-stamped schema kernels:** on any bd version bump, `grep -rn "verified at bd v" skills/` and re-verify each stamped schema paragraph against the new binary (`--help` + `--dry-run` probe); update the stamp or file a fix bead.

Done when: bd version, new/changed commands, and `bd prime` format are compared against baseline, and Check 6.4's watch areas are assessed for skill impact.

---

### Phase 7: Documentation Accuracy

Verify all documentation reflects the current state.

**Check 7.1 — README skills count matches actual:**
```bash
actual=$(ls -d skills/*/ | wc -l)
readme_count=$(grep -o "[0-9]* skills" README.md | head -1 | grep -o "[0-9]*")
echo "Actual: $actual | README: $readme_count"
[ "$actual" = "$readme_count" ] && echo "PASS" || echo "FAIL: README skills count is stale"
```

**Check 7.2 — README skills table has all skills:**
```bash
for dir in skills/*/; do
    name=$(basename "$dir")
    grep -q "$name" README.md && echo "PASS: $name in README" || echo "FAIL: $name missing from README"
done
```

**Check 7.3 — CHANGELOG has current version:**
```bash
version=$(grep '"version"' package.json | grep -o '[0-9.]*')
grep -q "\[$version\]" CHANGELOG.md && echo "PASS: v$version in CHANGELOG" || echo "FAIL: v$version missing from CHANGELOG"
```

**Check 7.4 — CLAUDE.md skills table matches actual:**
```bash
for dir in skills/*/; do
    name=$(basename "$dir")
    grep -q "$name" CLAUDE.md && echo "PASS: $name in CLAUDE.md" || echo "FAIL: $name missing from CLAUDE.md"
done
```

**Check 7.5 — SETUP-GUIDE install commands use correct names:**
```bash
grep -q "DollarDill/beads-superpowers" .internal/SETUP-GUIDE.md && echo "PASS: correct marketplace repo" || echo "FAIL"
grep -q "beads-superpowers@beads-superpowers-marketplace" .internal/SETUP-GUIDE.md && echo "PASS: correct install command" || echo "FAIL"
```

**Check 7.6 — Copied upstream docs don't have stale references:**
```bash
# These docs were adapted from superpowers — verify no stale refs
for f in .internal/testing.md .internal/windows/polyglot-hooks.md; do
    stale=$(grep -c "superpowers" "$f" | head -1)
    allowed=$(grep -c "beads-superpowers\|obra/superpowers\|upstream" "$f" | head -1)
    raw=$((stale - allowed))
    [ "$raw" -le 0 ] && echo "PASS: $f clean" || echo "WARNING: $f may have $raw stale superpowers refs"
done
```

**Check 7.7 — Upstream Beads docs links in docs/ resolve (visible SKIP offline; ADR-0041-era descope net):**
```bash
if ! command -v curl >/dev/null 2>&1 || ! curl -sf -o /dev/null --max-time 10 "https://gastownhall.github.io/beads/"; then
  echo "SKIP (no curl or no network): upstream docs link-check not run"
else
  grep -rhoE 'https://gastownhall\.github\.io/beads[^") ]*' docs/*.md | sort -u | while read -r url; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$url")
    if [ "${code#2}" = "$code" ]; then  # not 2xx — retry once
      code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$url")
    fi
    case "$code" in 2*) echo "PASS: $url" ;; *) echo "FAIL ($code): $url" ;; esac
  done
fi
```

Done when: Checks 7.1–7.7 all report PASS, or each FAIL is fixed.

---

### Phase 8: Generate Audit Report

Create beads for each finding and write the report.

```bash
# Create child beads for each finding
bd create "Drift: [description]" -t chore -p 3 --parent <audit-id>
bd create "CRITICAL: [description]" -t bug -p 0 --parent <audit-id>
```

Write the report to `.internal/audits/YYYY-MM-DD-upstream-drift.md`:

```markdown
# Plugin Audit — YYYY-MM-DD

## Infrastructure
- Plugin manifest: PASS/FAIL
- Version consistency: PASS/FAIL (version)
- Hook functional: PASS/FAIL
- Settings.json: PASS/FAIL
- Skills count: N
- LICENSE: PASS/FAIL

## Tests
- Brainstorm server: N/32 passed
- WS protocol: N/31 passed
- Auth/security: N/20 passed
- Fast skill tests: PASS/FAIL (N subtests)
- Integration test: RAN/SKIPPED

## Content Integrity
- TodoWrite residue: PASS/FAIL
- Stale paths: PASS/FAIL
- Stale namespaces: PASS/FAIL
- Beads density: N references (min 30)
- Subagent isolation: PASS/FAIL
- Skill chain: PASS/FAIL

## Upstream Drift
- Superpowers: vX.Y.Z (baseline v6.3.0) — N changes
- Beads: vX.Y.Z (baseline v1.2.2) — N new features
- New skills: N (action: copy/skip for each)
- Changed skills: N (action: merge/conflict/skip for each)

## Documentation
- README: PASS/FAIL
- CHANGELOG: PASS/FAIL
- CLAUDE.md: PASS/FAIL
- SETUP-GUIDE: PASS/FAIL
- Copied docs: PASS/FAIL

## Findings: N total (C critical, I important, M minor)

## Actions Required
- [List with bead IDs]
```

Close the audit bead:
```bash
bd close <audit-id> --reason "Audit complete: N findings (C critical, I important, M minor)"
```

Done when: findings beads are created, the report is written to `.internal/audits/YYYY-MM-DD-upstream-drift.md`, and the audit bead is closed with evidence.

---

## Quick Audit (Phases 1-4 Only)

For fast checks without upstream comparison:

```bash
# Run this single block for a quick health check
echo "=== Quick Audit ===" && \
claude plugin validate .claude-plugin/plugin.json 2>&1 | tail -1 && \
test -x hooks/session-start && echo "Hook: executable" && \
bash hooks/session-start 2>&1 | python3 -m json.tool > /dev/null && echo "Hook: valid JSON" && \
echo "Skills: $(ls -d skills/*/ | wc -l)" && \
echo "TodoWrite residue: $(grep -rn 'TodoWrite' skills/ | grep -v 'Do NOT use' | grep -v 'replaces' | grep -v 'auditing-upstream-drift' | wc -l)" && \
echo "Stale paths: $(grep -rn 'docs/superpowers' skills/ tests/ | grep -v 'auditing-upstream-drift' | wc -l)" && \
echo "Stale namespace: $(grep -rn '"superpowers:' skills/ tests/ | grep -v 'beads-superpowers:' | wc -l)" && \
echo "Beads density: $(grep -rn 'bd create\|bd close\|bd ready\|bd update\|bd dep\|bd dolt' skills/ | wc -l)" && \
echo "Version: $(grep '"version"' package.json | grep -o '[0-9.]*')" && \
cd tests/brainstorm-server && node server.test.js 2>&1 | tail -1 && node ws-protocol.test.js 2>&1 | tail -1 && node auth.test.js 2>&1 | tail -1 && cd ../.. && \
echo "=== Quick Audit Complete ==="
```

## Audit Frequency

| Trigger | Action |
|---------|--------|
| Before any plugin release | Full audit (all 8 phases) — MANDATORY |
| Monthly | Phases 1-4 (infrastructure + tests + content + chain) |
| After upstream superpowers release | Add Phase 5 |
| After upstream beads release | Add Phase 6 |
| After bulk skill edits | Phases 2-4 (tests + content + chain) |
| After test refactoring | Phase 2 only (run all tests) |
| User reports mismatch | Phase 3 check 3.x for the specific issue + Phase 5 check 5.3 for the skill |
| Quick sanity check | Quick Audit block above |

## Cleanup

```bash
rm -rf /tmp/superpowers-upstream
```

**Capture what you learned.** At close, record durable, evidence-backed insights (still true next month, tied to a file, test, or command). Never record guesses, one-offs, or secrets (tokens, keys, PII — every memory is injected into all future sessions). Update in place (`bd remember --key <key>`) rather than adding a near-duplicate.

```bash
bd remember "<kind>: <durable, evidence-backed insight>"   # kind: lesson / pattern / design / root-cause / research
```

## Integration

**Invoked by:** No other skill invokes this directly. Standalone audit skill — run before releases or on-demand.

**Invokes:** None. References other skills as audit targets but does not invoke them.
