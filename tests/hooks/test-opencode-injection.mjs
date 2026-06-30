#!/usr/bin/env node
// test-opencode-injection.mjs — OpenCode plugin mutation test
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

const __dirname = dirname(fileURLToPath(import.meta.url))
const pluginPath = join(__dirname, "../../opencode/beads-superpowers-plugin.ts")

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

// Instantiate the plugin (factory call — OpenCode calls this once per process)
const hooks = await BeadsSuperpowers({})

// ── Test 1: first chat.message mutates output.parts (bootstrap injected) ──────
const sid = "s1"
const out1 = { message: {}, parts: [] }
await hooks["chat.message"]({ sessionID: sid }, out1)
assert.ok(out1.parts.length > 0, "first message must inject bootstrap into output.parts")
console.log("PASS: first message injects into output.parts")

// ── Test 2: second same-session message does NOT re-inject the bootstrap ───────
const out2 = { message: {}, parts: [] }
await hooks["chat.message"]({ sessionID: sid }, out2)
assert.ok(
  !out2.parts.some(p => String(p.text || "").includes("EXTREMELY_IMPORTANT")),
  "second same-session message must NOT re-inject the bootstrap (once-per-session guard)"
)
console.log("PASS: second message skips bootstrap (once-per-session guard)")

// ── Test 3: compaction mutates output.context (push, not return) ───────────────
const outc = { context: [] }
await hooks["experimental.session.compacting"]({ sessionID: sid }, outc)
assert.ok(outc.context.length > 0, "compaction must push to output.context")
console.log("PASS: compaction pushes to output.context")

// ── Test 4: injected reminder contains no full-line # comments ─────────────────
// (Verifies that reminder-content.txt maintainer comments are stripped before injection)
for (const p of out2.parts) {
  const lines = String(p.text || "").split("\n")
  const commentLines = lines.filter(line => /^\s*#/.test(line))
  assert.ok(
    commentLines.length === 0,
    `injected reminder must contain no full-line # comments; found: ${commentLines.join(" | ")}`
  )
}
console.log("PASS: injected reminder contains no full-line # comments")

console.log("ALL TESTS PASSED")
