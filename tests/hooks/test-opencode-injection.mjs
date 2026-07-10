#!/usr/bin/env node
// test-opencode-injection.mjs — hermetic plugin test (ADR-0039 + bead beads-superpowers-avji.3).
//
// The plugin (.opencode/plugins/beads-superpowers.js) resolves everything
// repo-relative to its own file location (packageRoot = two dirs up from
// __dirname) — no HOME, no env overrides, no fallback roots (upstream
// parity). To test it hermetically, each scenario below builds a standalone
// fixture directory with its own copy of the plugin file plus a
// hooks/session-start stub and a skills/using-superpowers/SKILL.md stub, then
// dynamically imports the fixture's copy. A fresh file path per scenario
// forces a fresh ES module instance (and a fresh module-level bootstrap
// cache) — importing the SAME path twice would reuse the cached module.
//
// Run with: node tests/hooks/test-opencode-injection.mjs (plain JS — no
// TypeScript loader / tsx required now that the plugin ships as .js).

import assert from "node:assert"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from "node:fs"
import { tmpdir } from "node:os"

const __dirname = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(__dirname, "../..")
const realPluginPath = join(repoRoot, ".opencode/plugins/beads-superpowers.js")
const pluginSrc = readFileSync(realPluginPath, "utf-8")

// Test 0a: exec-target — composeBootstrap execs the canonical composer, not a
// reimplementation. Exactly one execSync call targets hooks/session-start
// --emit-plain (one source of truth; a bd-prime-style dump must not be
// reimplemented here). Matches across the multi-line template literal.
const execTargetRe = /execSync\(\s*`[^`]*hooks\/session-start[^`]*--emit-plain[^`]*`/g
const execTargetMatches = pluginSrc.match(execTargetRe) || []
assert.strictEqual(execTargetMatches.length, 1, "exactly one execSync call targets hooks/session-start --emit-plain")
assert.ok(!pluginSrc.includes("bdPrime"), "bdPrime() must not exist — composeBootstrap replaces it")
console.log("PASS: exec-target — single execSync call to the canonical hook with --emit-plain")

// Test 0b: anti-fork guard — the plugin must contain ZERO selection policy. Composer/selection
// logic (salience parsing, recall loops, ceiling logic) lives ONLY in hooks/session-start.
assert.ok(
  !/salience|@type=|BSP_MEM_CEILING/i.test(pluginSrc),
  "plugin source must not reimplement selection policy (salience / @type= / BSP_MEM_CEILING)"
)
assert.ok(!pluginSrc.includes("bd memories --json"), "plugin source must not reimplement memory selection (bd memories --json)")
console.log("PASS: anti-fork guard — no selection policy in plugin source")

// buildFixture(withHook) — a standalone fixture dir with its own copy of the plugin
// file (fresh module identity), a skills/using-superpowers/SKILL.md stub, and
// optionally a hooks/session-start stub that echoes a canned composer payload.
const stubPayload = [
  "<EXTREMELY_IMPORTANT>",
  "stub bootstrap body",
  "</EXTREMELY_IMPORTANT>",
  "",
  "<beads-context>",
  "stub beads body",
  "</beads-context>",
].join("\n")

function buildFixture(withHook) {
  const root = mkdtempSync(join(tmpdir(), "bsp-oc-test-"))
  const pluginDir = join(root, ".opencode/plugins")
  mkdirSync(pluginDir, { recursive: true })
  const pluginPath = join(pluginDir, "beads-superpowers.js")
  writeFileSync(pluginPath, pluginSrc)

  const skillDir = join(root, "skills/using-superpowers")
  mkdirSync(skillDir, { recursive: true })
  writeFileSync(join(skillDir, "SKILL.md"), "# fixture skill\nEXTREMELY_IMPORTANT fixture body\n")

  if (withHook) {
    const hooksDir = join(root, "hooks")
    mkdirSync(hooksDir, { recursive: true })
    // /bin/sh + a heredoc only: no external binaries needed.
    writeFileSync(
      join(hooksDir, "session-start"),
      "#!/bin/sh\ncat <<'STUBEOF'\n" + stubPayload + "\nSTUBEOF\n",
      { mode: 0o755 }
    )
  }

  return { root, pluginPath }
}

// --- Scenario A: hook present — primary composer path ---
const fixtureA = buildFixture(true)
const { BeadsSuperpowersPlugin: PluginA } = await import(fixtureA.pluginPath)
assert.strictEqual(typeof PluginA, "function", "BeadsSuperpowersPlugin is exported as a function")
const hooksA = await PluginA({ client: {}, directory: fixtureA.root })

// Test 1: config hook appends the fixture's skills dir, and is idempotent.
const config = {}
await hooksA.config(config)
assert.deepStrictEqual(config.skills.paths, [join(fixtureA.root, "skills")], "config hook appends fixture skills dir")
await hooksA.config(config)
assert.strictEqual(config.skills.paths.length, 1, "config hook is idempotent on a second call")
console.log("PASS: config hook — skills path appended once")

// Test 2: transform injects the composer payload into the first user message once;
// a second call does not double-inject (marker guard). Injected text matches the
// composer output as-is — no prepended bootstrap, no re-wrap.
const output = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] }
await hooksA["experimental.chat.messages.transform"]({}, output)
const firstUserParts = output.messages[0].parts
assert.strictEqual(firstUserParts.length, 2, "transform injects exactly one part")
assert.strictEqual(firstUserParts[0].text, stubPayload, "injected text is the composer output as-is")

await hooksA["experimental.chat.messages.transform"]({}, output)
assert.strictEqual(output.messages[0].parts.length, 2, "second transform call does not double-inject")
console.log("PASS: transform — inject once, marker guard prevents double-injection")

// Test 3 (part 1): compaction hook pushes composer output into output.context.
const compactionOutput = { context: [] }
await hooksA["experimental.session.compacting"]({}, compactionOutput)
assert.strictEqual(compactionOutput.context.length, 1, "compaction pushes exactly one context entry")
assert.strictEqual(compactionOutput.context[0], stubPayload, "compaction pushes composer output as-is")
console.log("PASS: compaction — composer output pushed to context (primary path)")

rmSync(fixtureA.root, { recursive: true, force: true })

// --- Scenario B: hook absent (fresh fixture, fresh import) — policy-free pointer fallback ---
const fixtureB = buildFixture(false)
const { BeadsSuperpowersPlugin: PluginB } = await import(fixtureB.pluginPath)
const hooksB = await PluginB({ client: {}, directory: fixtureB.root })

const fallbackOutput = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] }
await hooksB["experimental.chat.messages.transform"]({}, fallbackOutput)
const fallbackText = fallbackOutput.messages[0].parts[0].text
assert.ok(fallbackText.includes("session composer unavailable"), "fallback pointer present when the composer is unreachable")
assert.ok(fallbackText.includes("skill tool"), "fallback still points at the skill tool")
assert.ok(
  !/salience|@type=|BSP_MEM_CEILING/i.test(fallbackText),
  "fallback pointer must not carry memory-selection policy strings"
)
console.log("PASS: fallback — policy-free pointer injected when composer is unavailable")

rmSync(fixtureB.root, { recursive: true, force: true })

console.log("PASS: opencode plugin — config idempotent, inject-once, compaction OK, policy-free fallback OK")
