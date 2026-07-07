#!/usr/bin/env node
// test-opencode-injection.mjs — hermetic plugin test (ADR-0039 + bead 3ogl.13).
// HOME is a temp fixture; resolution never touches the real machine.
// Per-turn injection must be GONE.
//
// Run with:
//   npx tsx tests/hooks/test-opencode-injection.mjs
//   node --experimental-strip-types tests/hooks/test-opencode-injection.mjs  (Node >=22.6)
//
// Requires tsx or Node >=22.6 with --experimental-strip-types for .ts imports.
// Loud-skips (exit 0 + warning) if neither is available — never silently passes.

import assert from "node:assert"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from "node:fs"
import { tmpdir } from "node:os"

const __dirname = dirname(fileURLToPath(import.meta.url))
const pluginPath = join(__dirname, "../../opencode/beads-superpowers-plugin.ts")
const pluginSrc = readFileSync(pluginPath, "utf-8")

// Test 0a: exec-target — composerContext execs the canonical composer, not a reimplementation.
// Exactly one execSync call targets hooks/session-start with --emit-plain (one source of truth;
// bd prime's 168KB dump and bdPrime() must be gone).
const execTargetRe = /execSync\(`[^`]*hooks\/session-start[^`]*--emit-plain[^`]*`/g
const execTargetMatches = pluginSrc.match(execTargetRe) || []
assert.strictEqual(execTargetMatches.length, 1, "exactly one execSync call targets hooks/session-start --emit-plain")
assert.ok(!pluginSrc.includes("bdPrime"), "bdPrime() must be deleted — composerContext replaces it")
console.log("PASS: exec-target — single execSync call to canonical hook with --emit-plain")

// Test 0b: anti-fork guard — the plugin must contain ZERO selection policy. Composer/selection
// logic (salience parsing, recall loops, ceiling logic) lives ONLY in hooks/session-start.
assert.ok(
  !/salience|@type=|BSP_MEM_CEILING/i.test(pluginSrc),
  "plugin source must not reimplement selection policy (salience / @type= / BSP_MEM_CEILING)"
)
assert.ok(!pluginSrc.includes("bd memories --json"), "plugin source must not reimplement memory selection (bd memories --json)")
console.log("PASS: anti-fork guard — no selection policy in plugin source")

const fixtureHome = mkdtempSync(join(tmpdir(), "bsp-oc-test-"))
const skillDir = join(fixtureHome, ".claude/skills/using-superpowers")
mkdirSync(skillDir, { recursive: true })
writeFileSync(join(skillDir, "SKILL.md"), "# fixture skill\nEXTREMELY_IMPORTANT fixture body\n")
// Co-located reminder-content.txt so the pre-removal plugin has something to inject on
// message 2 — without this the old else-if branch is unreachable (empty reminder) and
// Test 2 would false-positive-pass before the fix, proving nothing (root-caused via
// systematic-debugging before writing this fixture line).
writeFileSync(join(skillDir, "reminder-content.txt"), "SUPERPOWERS REMINDER: fixture reminder body\n")
process.env.HOME = fixtureHome
process.env.PATH = "/nonexistent" // bd absent + no hooks/session-start in fixture → composerContext() falls back

let BeadsSuperpowers
try {
  const mod = await import(pluginPath)
  BeadsSuperpowers = mod.BeadsSuperpowers
} catch (e) {
  const msg = String(e)
  if (
    e.code === "ERR_UNKNOWN_FILE_EXTENSION" ||
    msg.includes("Unknown file extension") ||
    msg.includes("unknown file extension")
  ) {
    console.warn("SKIP: TypeScript runner unavailable.")
    console.warn("  Install tsx:   npm install -g tsx")
    console.warn("  Or use Node >= 22.6 with:  node --experimental-strip-types <file>")
    process.exit(0)
  }
  throw e
}

if (typeof BeadsSuperpowers !== "function") {
  console.error("FAIL: BeadsSuperpowers is not exported as a function from the plugin")
  process.exit(1)
}

const hooks = await BeadsSuperpowers()

// Test 1: first message injects the bootstrap
const p1 = { message: {}, parts: [] }
await hooks["chat.message"]({ sessionID: "s1" }, p1)
assert.strictEqual(p1.parts.length, 1, "first message injects exactly one part")
assert.ok(p1.parts[0].text.includes("EXTREMELY_IMPORTANT"), "bootstrap contains skill body")

// Test 1b: degradation ladder — fixture HOME has no hooks/session-start, so composerContext()
// must throw on the primary exec and fall back to the minimal, policy-free pointer (never the
// 168KB bd prime dump).
assert.ok(p1.parts[0].text.includes("session hook unavailable"), "fallback pointer present when canonical hook is unreachable")
assert.ok(p1.parts[0].text.includes("Skill tool"), "fallback still points at the Skill tool")

// Test 2: second message injects NOTHING (per-turn reminder removed, ADR-0039)
const p2 = { message: {}, parts: [] }
await hooks["chat.message"]({ sessionID: "s1" }, p2)
assert.strictEqual(p2.parts.length, 0, "subsequent messages inject nothing")

// Test 3: compaction pushes context
const c = { context: [] }
await hooks["experimental.session.compacting"]({ sessionID: "s1" }, c)
assert.strictEqual(c.context.length, 1, "compaction pushes one context entry")
assert.ok(c.context[0].includes("beads-superpowers is installed"), "compaction pointer present")

// Test 4: skill-not-found HOME → hint injected on first message.
// No re-import needed: BeadsSuperpowers reads process.env.HOME at CONSTRUCTION
// (each `await BeadsSuperpowers()` call), so re-invoke the same import.
const emptyHome = mkdtempSync(join(tmpdir(), "bsp-oc-empty-"))
process.env.HOME = emptyHome
const hooks2 = await BeadsSuperpowers()
const p3 = { message: {}, parts: [] }
await hooks2["chat.message"]({ sessionID: "s2" }, p3)
assert.ok(p3.parts[0].text.includes("not found"), "notFoundHint injected when skill missing")

// Test 5: primary path — HOME with an executable canonical-hook stub → the plugin injects
// the stub's --emit-plain output AS-IS. The composer output already contains the bootstrap
// AND the <beads-context> envelope, so the plugin must not prepend its own bootstrap or
// re-wrap (double-bootstrap / nested-tags bug, beads-superpowers-7bod).
const hookHome = mkdtempSync(join(tmpdir(), "bsp-oc-hook-"))
const ocRoot = join(hookHome, ".config/opencode")
mkdirSync(join(ocRoot, "skills/using-superpowers"), { recursive: true })
writeFileSync(join(ocRoot, "skills/using-superpowers/SKILL.md"), "# fixture skill\nEXTREMELY_IMPORTANT fixture body\n")
mkdirSync(join(ocRoot, "hooks"), { recursive: true })
const stubPayload = [
  "<EXTREMELY_IMPORTANT>",
  "stub bootstrap body",
  "</EXTREMELY_IMPORTANT>",
  "",
  "<beads-context>",
  "stub beads body",
  "</beads-context>",
].join("\n")
// /bin/sh + echo builtins only: the test PATH is /nonexistent, so the stub must not
// need any external binaries.
writeFileSync(
  join(ocRoot, "hooks/session-start"),
  "#!/bin/sh\n" + stubPayload.split("\n").map((l) => `echo '${l}'`).join("\n") + "\n",
  { mode: 0o755 }
)
process.env.HOME = hookHome
const hooks3 = await BeadsSuperpowers()
const p4 = { message: {}, parts: [] }
await hooks3["chat.message"]({ sessionID: "s3" }, p4)
assert.strictEqual(p4.parts.length, 1, "primary path injects exactly one part")
assert.strictEqual(
  p4.parts[0].text,
  stubPayload,
  "primary path injects composer output as-is (no prepended bootstrap, no re-wrap)"
)
assert.strictEqual(
  (p4.parts[0].text.match(/<EXTREMELY_IMPORTANT>/g) || []).length,
  1,
  "exactly one bootstrap marker (no double-bootstrap)"
)
assert.strictEqual(
  (p4.parts[0].text.match(/<beads-context>/g) || []).length,
  1,
  "exactly one beads-context open tag (no nesting)"
)

// Test 5b: compaction on the primary path also pushes composer output as-is.
const c2 = { context: [] }
await hooks3["experimental.session.compacting"]({ sessionID: "s3" }, c2)
assert.strictEqual(c2.context.length, 1, "compaction pushes one context entry (primary)")
assert.strictEqual(c2.context[0], stubPayload, "compaction primary path pushes composer output as-is")

rmSync(fixtureHome, { recursive: true, force: true })
rmSync(emptyHome, { recursive: true, force: true })
rmSync(hookHome, { recursive: true, force: true })
console.log("PASS: opencode plugin — bootstrap once, no per-turn, compaction OK, not-found hint OK, primary as-is OK")
