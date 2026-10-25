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
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, realpathSync, readdirSync, accessSync, constants } from "node:fs"
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

function buildFixture(withHook, envBash = false) {
  // realpath: on macOS tmpdir() is /var/..., a symlink to /private/var/... (beads-superpowers-maues)
  const root = realpathSync(mkdtempSync(join(tmpdir(), "bsp-oc-test-")))
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
    // /bin/sh + a heredoc only: no external binaries needed. envBash: the
    // real hook's #!/usr/bin/env bash shebang (bash is looked up on PATH),
    // and printf, a builtin, so the stub needs nothing from PATH itself.
    const stub = envBash
      ? "#!/usr/bin/env bash\nprintf '%s\\n' '" + stubPayload + "'\n"
      : "#!/bin/sh\ncat <<'STUBEOF'\n" + stubPayload + "\nSTUBEOF\n"
    writeFileSync(join(hooksDir, "session-start"), stub, { mode: 0o755 })
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

// --- Scenario C: a bash or bd planted in the host cwd never runs (security) ---
// An empty or relative PATH entry (or PATH="") makes a command lookup search
// the cwd, which for a session is an untrusted project. The composer's
// #!/usr/bin/env bash and the `bd memories` fallback both look a command up,
// so the plugin must hand its children a PATH of absolute entries only.
const evil = realpathSync(mkdtempSync(join(tmpdir(), "bsp-oc-evil-")))
const markers = realpathSync(mkdtempSync(join(tmpdir(), "bsp-oc-mark-")))
for (const b of ["bash", "bd"]) {
  writeFileSync(join(evil, b), `#!/bin/sh\n: > "${markers}/ran-${b}"\n`, { mode: 0o755 })
}
// Names of the planted binaries that ran; clears the markers.
const plantedRan = () => {
  const ran = readdirSync(markers)
  for (const m of ran) rmSync(join(markers, m), { force: true })
  return ran.map(m => m.replace(/^ran-/, ""))
}
// Whether the cleaned PATH (its absolute entries, else /usr/bin:/bin) holds a
// bash: then the composer runs; otherwise the plugin falls back (macOS has no
// /usr/bin/bash, a merged-/usr Linux does).
const bashOnCleanPath = (p) => {
  const abs = p.split(":").filter(e => e.startsWith("/"))
  return (abs.length ? abs : ["/usr/bin", "/bin"]).some(e => {
    try { accessSync(join(e, "bash"), constants.X_OK); return true } catch { return false }
  })
}
const savedPath = process.env.PATH
const savedCwd = process.cwd()
try {
  for (const p of ["", ".:/usr/bin", ":/usr/bin:/bin"]) {
    for (const withHook of [true, false]) {
      const fx = buildFixture(withHook, true)
      process.chdir(evil)
      process.env.PATH = p
      let text
      try {
        const { BeadsSuperpowersPlugin: PluginC } = await import(fx.pluginPath)
        const hooksC = await PluginC({ client: {}, directory: evil })
        const outC = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] }
        await hooksC["experimental.chat.messages.transform"]({}, outC)
        text = outC.messages[0].parts[0].text
      } finally {
        process.env.PATH = savedPath
        process.chdir(savedCwd)
        rmSync(fx.root, { recursive: true, force: true })
      }
      const what = `${withHook ? "composer" : "bd fallback"}, PATH='${p}'`
      assert.deepStrictEqual(plantedRan(), [], `planted binary ran (${what})`)
      if (withHook && bashOnCleanPath(p)) {
        assert.strictEqual(text, stubPayload, `composer payload injected (${what})`)
      } else {
        assert.ok(text.includes("EXTREMELY_IMPORTANT") && text.includes("session composer unavailable"),
          `fallback pointer injected (${what}): ${text}`)
      }
      console.log(`PASS: planted bash/bd in the cwd never run (${what})`)
    }
  }
  // A literal ~ or ~/x entry becomes $HOME (bash expands it at lookup), as
  // hooks/session-start keeps it: a ~/bin/bash wrapper is the bash used.
  const home = realpathSync(mkdtempSync(join(tmpdir(), "bsp-oc-home-")))
  mkdirSync(join(home, "bin"))
  writeFileSync(join(home, "bin/bash"), `#!/bin/sh\n: > "${markers}/ran-tildebash"\nexec /bin/bash "$@"\n`, { mode: 0o755 })
  const savedHome = process.env.HOME
  const fx = buildFixture(true, true)
  process.chdir(evil)
  process.env.PATH = "~/bin"
  process.env.HOME = home
  let text
  try {
    const { BeadsSuperpowersPlugin: PluginT } = await import(fx.pluginPath)
    const hooksT = await PluginT({ client: {}, directory: evil })
    const outT = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] }
    await hooksT["experimental.chat.messages.transform"]({}, outT)
    text = outT.messages[0].parts[0].text
  } finally {
    process.env.PATH = savedPath
    process.env.HOME = savedHome
    process.chdir(savedCwd)
    rmSync(fx.root, { recursive: true, force: true })
    rmSync(home, { recursive: true, force: true })
  }
  assert.deepStrictEqual(plantedRan(), ["tildebash"], "PATH='~/bin' resolves bash in $HOME/bin")
  assert.strictEqual(text, stubPayload, "composer payload injected (PATH='~/bin')")
  console.log("PASS: a ~/bin PATH entry maps to $HOME/bin")

  // --- Windows spawns nothing (P1) ---
  // CreateProcess and cmd.exe search the cwd before PATH, which no env can
  // change, so on win32 the plugin must start no child at all and inject the
  // static pointer, without a memory line. The platform is forced. Any spawn
  // shows up as a marker: through comspec (the shell Node picks on win32), or
  // through the composer stub and a `bd` on an absolute PATH entry otherwise.
  const wbin = realpathSync(mkdtempSync(join(tmpdir(), "bsp-oc-wbin-")))
  writeFileSync(join(wbin, "comspec"), `#!/bin/sh\n: > "${markers}/ran-comspec"\n`, { mode: 0o755 })
  writeFileSync(join(wbin, "bd"), `#!/bin/sh\n: > "${markers}/ran-bd"\necho 'Memories (3):'\n`, { mode: 0o755 })
  const savedPlatform = Object.getOwnPropertyDescriptor(process, "platform")
  const savedComspec = process.env.comspec
  for (const withHook of [true, false]) {
    const fw = buildFixture(withHook)
    if (withHook) {
      writeFileSync(join(fw.root, "hooks/session-start"),
        `#!/bin/sh\n: > "${markers}/ran-composer"\ncat <<'STUBEOF'\n${stubPayload}\nSTUBEOF\n`, { mode: 0o755 })
    }
    let textW, compactW
    Object.defineProperty(process, "platform", { ...savedPlatform, value: "win32" })
    process.env.comspec = join(wbin, "comspec")
    process.env.PATH = `${wbin}:/usr/bin:/bin`
    try {
      const { BeadsSuperpowersPlugin: PluginW } = await import(fw.pluginPath)
      const hooksW = await PluginW({ client: {}, directory: fw.root })
      const outW = { messages: [{ info: { role: "user" }, parts: [{ type: "text", text: "hi" }] }] }
      await hooksW["experimental.chat.messages.transform"]({}, outW)
      textW = outW.messages[0].parts[0].text
      const compaction = { context: [] }
      await hooksW["experimental.session.compacting"]({}, compaction)
      compactW = compaction.context[0]
    } finally {
      Object.defineProperty(process, "platform", savedPlatform)
      if (savedComspec === undefined) delete process.env.comspec
      else process.env.comspec = savedComspec
      process.env.PATH = savedPath
      rmSync(fw.root, { recursive: true, force: true })
    }
    const what = withHook ? "composer present" : "composer absent"
    assert.deepStrictEqual(plantedRan(), [], `win32 spawned a child (${what})`)
    assert.ok(textW.includes("EXTREMELY_IMPORTANT") && textW.includes("session composer unavailable"),
      `win32 injects the static pointer (${what}): ${textW}`)
    assert.ok(!textW.includes("Memories"), `win32 pointer has no memory line (${what}): ${textW}`)
    assert.strictEqual(compactW, "beads-superpowers is installed. Run skills via the skill tool.",
      `win32 compaction pushes the static line (${what})`)
    console.log(`PASS: win32 spawns no child and injects the static pointer (${what})`)
  }
  rmSync(wbin, { recursive: true, force: true })
} finally {
  rmSync(evil, { recursive: true, force: true })
  rmSync(markers, { recursive: true, force: true })
}

console.log("PASS: opencode plugin — config idempotent, inject-once, compaction OK, policy-free fallback OK, no cwd lookup")
